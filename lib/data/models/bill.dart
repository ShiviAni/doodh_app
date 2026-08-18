import 'package:equatable/equatable.dart';

enum BillStatus { unpaid, partial, paid }

/// One customer's month: litres delivered, what that costs, what they have
/// paid, and what carried over from previous months.
///
/// Computed from deliveries + approved payments rather than stored as the
/// source of truth, so a corrected past entry always flows through.
class Bill extends Equatable {
  const Bill({
    required this.customerId,
    required this.monthKey,
    required this.litres,
    required this.ratePerLitre,
    required this.paidAmount,
    this.previousDue = 0,
  });

  final String customerId;
  final String monthKey;
  final double litres;
  final double ratePerLitre;
  final double paidAmount;

  /// Unpaid balance carried in from earlier months.
  final double previousDue;

  double get amount => litres * ratePerLitre;
  double get totalPayable => amount + previousDue;
  double get balance => totalPayable - paidAmount;

  BillStatus get status {
    // Tolerance guards against float drift on sums like 30 * 2.5 * 62.
    if (balance <= 0.01) return BillStatus.paid;
    if (paidAmount > 0.01) return BillStatus.partial;
    return BillStatus.unpaid;
  }

  @override
  List<Object?> get props => [
    customerId,
    monthKey,
    litres,
    ratePerLitre,
    paidAmount,
    previousDue,
  ];
}

/// Aggregate figures for a date range, used by every owner report view.
class PeriodSummary extends Equatable {
  const PeriodSummary({
    required this.litres,
    required this.amount,
    required this.deliveredCount,
    required this.skippedCount,
    this.pendingCount = 0,
  });

  static const empty = PeriodSummary(
    litres: 0,
    amount: 0,
    deliveredCount: 0,
    skippedCount: 0,
  );

  final double litres;
  final double amount;
  final int deliveredCount;
  final int skippedCount;

  /// Active houses with no entry at all for the period — the signal behind the
  /// missing-house alert.
  final int pendingCount;

  PeriodSummary copyWith({int? pendingCount}) => PeriodSummary(
    litres: litres,
    amount: amount,
    deliveredCount: deliveredCount,
    skippedCount: skippedCount,
    pendingCount: pendingCount ?? this.pendingCount,
  );

  @override
  List<Object?> get props => [
    litres,
    amount,
    deliveredCount,
    skippedCount,
    pendingCount,
  ];
}
