part of 'reports_cubit.dart';

enum ReportPeriod { day, week, month, year }

final class ReportsState extends Equatable {
  ReportsState({
    required this.anchor,
    this.period = ReportPeriod.month,
    this.rate = SettingsRepository.defaultRate,
    this.customers = const [],
    this.deliveries,
  });

  /// Any day inside the period being shown.
  final DateTime anchor;
  final ReportPeriod period;
  final double rate;
  final List<Customer> customers;

  /// Null until the first range has loaded.
  final List<Delivery>? deliveries;

  static const _calc = ReportCalculator();

  bool get loading => deliveries == null;

  /// Inclusive bounds of the period.
  (DateTime, DateTime) get range => switch (period) {
    ReportPeriod.day => (
      DateKeys.startOfDay(anchor),
      DateKeys.startOfDay(anchor),
    ),
    ReportPeriod.week => (
      DateKeys.startOfWeek(anchor),
      DateKeys.startOfWeek(anchor).add(const Duration(days: 6)),
    ),
    ReportPeriod.month => (
      DateKeys.startOfMonth(anchor),
      DateKeys.endOfMonth(anchor),
    ),
    ReportPeriod.year => (
      DateKeys.startOfYear(anchor),
      DateTime(anchor.year, 12, 31),
    ),
  };

  int get dayCount {
    final (from, to) = range;
    return to.difference(from).inDays + 1;
  }

  // Each figure is worked out once per state, not on every build.
  late final PeriodSummary summary = _calc.summarise(
    deliveries: deliveries ?? const [],
    ratePerLitre: rate,
    activeCustomerCount: customers.where((c) => c.active).length,
    expectedDays: dayCount,
  );
  late final Map<String, double> litresByCustomer = _calc.litresByCustomer(
    deliveries ?? const [],
  );
  late final Map<String, double> litresByDay = _calc.litresByDay(
    deliveries ?? const [],
  );

  /// One row per customer for the selected period, ready to share.
  String toCsv() {
    final rows = <List<Object>>[
      ['Customer', 'House no', 'Litres', 'Rate', 'Amount'],
      for (final c in customers)
        [
          c.name,
          c.houseNo,
          litresByCustomer[c.id] ?? 0,
          rate,
          (litresByCustomer[c.id] ?? 0) * rate,
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  ReportsState copyWith({
    DateTime? anchor,
    ReportPeriod? period,
    double? rate,
    List<Customer>? customers,
    List<Delivery>? deliveries,
  }) => ReportsState(
    anchor: anchor ?? this.anchor,
    period: period ?? this.period,
    rate: rate ?? this.rate,
    customers: customers ?? this.customers,
    deliveries: deliveries ?? this.deliveries,
  );

  @override
  List<Object?> get props => [anchor, period, rate, customers, deliveries];
}
