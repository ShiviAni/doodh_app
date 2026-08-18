import 'package:doodh_app/data/models/bill.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/data/repositories/report_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void main() {
  const calc = ReportCalculator();

  group('summarise', () {
    test('totals litres and prices them at the given rate', () {
      final summary = calc.summarise(
        deliveries: [
          delivery(customerId: 'c1', qty: 2.0),
          delivery(customerId: 'c2', qty: 1.5),
          delivery(customerId: 'c3', qty: 2.5),
        ],
        ratePerLitre: 60,
      );

      expect(summary.litres, 6.0);
      expect(summary.amount, 360.0);
      expect(summary.deliveredCount, 3);
    });

    test('a skipped house contributes zero litres, not its usual quantity', () {
      // The delivery person records "not taken today" rather than leaving the
      // house blank, so the entry exists but must not be billed.
      final summary = calc.summarise(
        deliveries: [
          delivery(customerId: 'c1', qty: 2.0),
          delivery(customerId: 'c2', qty: 3.0, status: DeliveryStatus.skipped),
        ],
        ratePerLitre: 60,
      );

      expect(summary.litres, 2.0);
      expect(summary.amount, 120.0);
      expect(summary.deliveredCount, 1);
      expect(summary.skippedCount, 1);
    });

    test('counts houses with no entry at all as pending', () {
      // This is the missing-house alert: 50 active houses, 48 recorded.
      final summary = calc.summarise(
        deliveries: List.generate(
          48,
          (i) => delivery(customerId: 'c$i', qty: 1.0),
        ),
        ratePerLitre: 60,
        activeCustomerCount: 50,
      );

      expect(summary.pendingCount, 2);
    });

    test('pending never goes negative when extra entries exist', () {
      final summary = calc.summarise(
        deliveries: List.generate(
          5,
          (i) => delivery(customerId: 'c$i', qty: 1.0),
        ),
        ratePerLitre: 60,
        activeCustomerCount: 3,
      );

      expect(summary.pendingCount, 0);
    });

    test('scales pending across a multi-day period', () {
      // A week of 50 houses expects 350 entries.
      final summary = calc.summarise(
        deliveries: List.generate(
          340,
          (i) => delivery(customerId: 'c$i', qty: 1.0),
        ),
        ratePerLitre: 60,
        activeCustomerCount: 50,
        expectedDays: 7,
      );

      expect(summary.pendingCount, 10);
    });
  });

  group('billFor', () {
    test('a full month at a fixed rate', () {
      // 30 days x 2 L x Rs 60 = Rs 3,600.
      final deliveries = List.generate(
        30,
        (i) => delivery(
          customerId: 'c1',
          dayKey: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
          qty: 2.0,
        ),
      );

      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: deliveries,
        allPayments: const [],
        ratePerLitre: 60,
      );

      expect(bill.litres, 60.0);
      expect(bill.amount, 3600.0);
      expect(bill.balance, 3600.0);
      expect(bill.status, BillStatus.unpaid);
    });

    test('only counts the requested customer', () {
      final bill = calc.billFor(
        customer: customer(id: 'c1'),
        monthKey: '2026-08',
        monthDeliveries: [
          delivery(customerId: 'c1', qty: 2.0),
          delivery(customerId: 'c2', qty: 3.0),
        ],
        allPayments: const [],
        ratePerLitre: 60,
      );

      expect(bill.litres, 2.0);
    });

    test('unapproved payments do not reduce the balance', () {
      // Cash the delivery person logged at the door is a claim, not a fact,
      // until the owner confirms it — otherwise an unverified entry could
      // silently clear a real due.
      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: [delivery(qty: 2.0, dayKey: '2026-08-01')],
        allPayments: [
          payment(amount: 120, dayKey: '2026-08-05', approved: false),
        ],
        ratePerLitre: 60,
      );

      expect(bill.paidAmount, 0);
      expect(bill.balance, 120.0);
      expect(bill.status, BillStatus.unpaid);
    });

    test('approved payments do reduce the balance', () {
      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: [delivery(qty: 2.0, dayKey: '2026-08-01')],
        allPayments: [
          payment(amount: 120, dayKey: '2026-08-05', approved: true),
        ],
        ratePerLitre: 60,
      );

      expect(bill.paidAmount, 120.0);
      expect(bill.balance, 0);
      expect(bill.status, BillStatus.paid);
    });

    test('ignores payments made in a different month', () {
      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: [delivery(qty: 2.0, dayKey: '2026-08-01')],
        allPayments: [payment(amount: 120, dayKey: '2026-07-05')],
        ratePerLitre: 60,
      );

      expect(bill.paidAmount, 0);
    });

    test('carries a previous due into the total payable', () {
      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: [delivery(qty: 2.0, dayKey: '2026-08-01')],
        allPayments: const [],
        ratePerLitre: 60,
        previousDue: 500,
      );

      expect(bill.amount, 120.0);
      expect(bill.totalPayable, 620.0);
      expect(bill.balance, 620.0);
    });

    test('partial payment is reported as partial, not paid', () {
      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: [delivery(qty: 2.0, dayKey: '2026-08-01')],
        allPayments: [payment(amount: 50, dayKey: '2026-08-05')],
        ratePerLitre: 60,
      );

      expect(bill.status, BillStatus.partial);
      expect(bill.balance, 70.0);
    });

    test('float drift on a realistic month still reads as fully paid', () {
      // 31 x 2.5 L x Rs 62 lands on 4805.000000000001 in binary floating point;
      // without a tolerance the bill would show a fraction of a paisa due
      // forever and never mark itself paid.
      final deliveries = List.generate(
        31,
        (i) => delivery(
          dayKey: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
          qty: 2.5,
        ),
      );
      final bill = calc.billFor(
        customer: customer(),
        monthKey: '2026-08',
        monthDeliveries: deliveries,
        allPayments: [payment(amount: 4805, dayKey: '2026-08-31')],
        ratePerLitre: 62,
      );

      expect(bill.status, BillStatus.paid);
    });
  });

  group('breakdowns', () {
    test('litresByCustomer sums per house and skips skipped days', () {
      final result = calc.litresByCustomer([
        delivery(customerId: 'c1', qty: 2.0, dayKey: '2026-08-01'),
        delivery(customerId: 'c1', qty: 1.5, dayKey: '2026-08-02'),
        delivery(
          customerId: 'c1',
          qty: 2.0,
          dayKey: '2026-08-03',
          status: DeliveryStatus.skipped,
        ),
        delivery(customerId: 'c2', qty: 3.0, dayKey: '2026-08-01'),
      ]);

      expect(result['c1'], 3.5);
      expect(result['c2'], 3.0);
    });

    test('litresByDay sums across houses', () {
      final result = calc.litresByDay([
        delivery(customerId: 'c1', qty: 2.0, dayKey: '2026-08-01'),
        delivery(customerId: 'c2', qty: 1.5, dayKey: '2026-08-01'),
        delivery(customerId: 'c1', qty: 2.0, dayKey: '2026-08-02'),
      ]);

      expect(result['2026-08-01'], 3.5);
      expect(result['2026-08-02'], 2.0);
    });

    test('balances net lifetime billing against approved payments only', () {
      final result = calc.balances(
        customers: [
          customer(id: 'c1'),
          customer(id: 'c2'),
        ],
        allDeliveries: [
          delivery(customerId: 'c1', qty: 2.0),
          delivery(customerId: 'c2', qty: 1.0),
        ],
        allPayments: [
          payment(customerId: 'c1', amount: 100, approved: true),
          payment(customerId: 'c2', amount: 100, approved: false),
        ],
        ratePerLitre: 60,
      );

      expect(result['c1'], 20.0); // 120 billed - 100 paid
      expect(result['c2'], 60.0); // 60 billed, unapproved payment ignored
    });
  });
}
