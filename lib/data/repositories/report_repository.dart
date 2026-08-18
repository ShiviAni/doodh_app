import '../../core/utils/formats.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/delivery.dart';
import '../models/payment.dart';

/// Pure aggregation over already-fetched documents.
///
/// Kept free of Firestore types on purpose: every figure the owner sees is
/// computed here, so it can be unit-tested against plain lists without an
/// emulator or a fake database.
class ReportCalculator {
  const ReportCalculator();

  PeriodSummary summarise({
    required List<Delivery> deliveries,
    required double ratePerLitre,
    int activeCustomerCount = 0,
    int expectedDays = 1,
  }) {
    var litres = 0.0;
    var delivered = 0;
    var skipped = 0;

    for (final d in deliveries) {
      litres += d.effectiveLitres;
      if (d.isDelivered) {
        delivered++;
      } else {
        skipped++;
      }
    }

    // Houses with no entry at all — neither delivered nor explicitly skipped.
    // This is what the missing-house alert counts.
    final expected = activeCustomerCount * expectedDays;
    final pending = expected - deliveries.length;

    return PeriodSummary(
      litres: litres,
      amount: litres * ratePerLitre,
      deliveredCount: delivered,
      skippedCount: skipped,
      pendingCount: pending > 0 ? pending : 0,
    );
  }

  /// Litres per house over a period, for the per-customer breakdown.
  Map<String, double> litresByCustomer(List<Delivery> deliveries) {
    final out = <String, double>{};
    for (final d in deliveries) {
      out[d.customerId] = (out[d.customerId] ?? 0) + d.effectiveLitres;
    }
    return out;
  }

  /// Litres per calendar day, for the trend chart.
  Map<String, double> litresByDay(List<Delivery> deliveries) {
    final out = <String, double>{};
    for (final d in deliveries) {
      out[d.dayKey] = (out[d.dayKey] ?? 0) + d.effectiveLitres;
    }
    return out;
  }

  /// Build one customer's bill for a month.
  ///
  /// Only **approved** payments count. A payment the delivery person logged at
  /// the door sits outside the balance until the owner confirms it, so an
  /// unverified claim can never zero out a real due.
  Bill billFor({
    required Customer customer,
    required String monthKey,
    required List<Delivery> monthDeliveries,
    required List<Payment> allPayments,
    required double ratePerLitre,
    double previousDue = 0,
  }) {
    final litres = monthDeliveries
        .where((d) => d.customerId == customer.id)
        .fold<double>(0, (sum, d) => sum + d.effectiveLitres);

    final paid = allPayments
        .where(
          (p) =>
              p.customerId == customer.id &&
              p.approved &&
              p.dayKey.startsWith(monthKey),
        )
        .fold<double>(0, (sum, p) => sum + p.amount);

    return Bill(
      customerId: customer.id,
      monthKey: monthKey,
      litres: litres,
      ratePerLitre: ratePerLitre,
      paidAmount: paid,
      previousDue: previousDue,
    );
  }

  /// Running balance per customer across all history: everything ever billed,
  /// minus everything approved as paid.
  Map<String, double> balances({
    required List<Customer> customers,
    required List<Delivery> allDeliveries,
    required List<Payment> allPayments,
    required double ratePerLitre,
  }) {
    final litres = litresByCustomer(allDeliveries);
    final paid = <String, double>{};
    for (final p in allPayments.where((p) => p.approved)) {
      paid[p.customerId] = (paid[p.customerId] ?? 0) + p.amount;
    }
    return {
      for (final c in customers)
        c.id: (litres[c.id] ?? 0) * ratePerLitre - (paid[c.id] ?? 0),
    };
  }

  /// A WhatsApp-ready bill in the customer's language.
  String billMessage({
    required Customer customer,
    required Bill bill,
    required Map<String, double> perDay,
    required bool hindi,
  }) {
    final b = StringBuffer();
    final monthName = Fmt.monthLabel(DateKeys.parseDay('${bill.monthKey}-01'));

    if (hindi) {
      b.writeln('नमस्ते ${customer.displayName(hindi: true)} जी,');
      b.writeln('$monthName का दूध का हिसाब:');
      b.writeln('');
      b.writeln('कुल दूध: ${Fmt.litres(bill.litres)} लीटर');
      b.writeln('भाव: ${Fmt.money(bill.ratePerLitre)} प्रति लीटर');
      b.writeln('इस महीने की रकम: ${Fmt.money(bill.amount)}');
      if (bill.previousDue > 0) {
        b.writeln('पिछला बकाया: ${Fmt.money(bill.previousDue)}');
      }
      if (bill.paidAmount > 0) {
        b.writeln('जमा: ${Fmt.money(bill.paidAmount)}');
      }
      b.writeln('');
      b.writeln('कुल देना है: ${Fmt.money(bill.balance)}');
      b.writeln('');
      b.writeln('धन्यवाद 🙏');
    } else {
      b.writeln('Hello ${customer.displayName(hindi: false)},');
      b.writeln('Milk account for $monthName:');
      b.writeln('');
      b.writeln('Total milk: ${Fmt.litres(bill.litres)} litres');
      b.writeln('Rate: ${Fmt.money(bill.ratePerLitre)} per litre');
      b.writeln('This month: ${Fmt.money(bill.amount)}');
      if (bill.previousDue > 0) {
        b.writeln('Previous due: ${Fmt.money(bill.previousDue)}');
      }
      if (bill.paidAmount > 0) {
        b.writeln('Paid: ${Fmt.money(bill.paidAmount)}');
      }
      b.writeln('');
      b.writeln('Amount due: ${Fmt.money(bill.balance)}');
      b.writeln('');
      b.writeln('Thank you 🙏');
    }
    return b.toString();
  }
}
