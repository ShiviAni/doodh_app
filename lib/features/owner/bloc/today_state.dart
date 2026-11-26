part of 'today_cubit.dart';

final class TodayState extends Equatable {
  TodayState({
    required this.day,
    this.rate = SettingsRepository.defaultRate,
    this.customers = const [],
    this.recorded = const {},
  }) : dayKey = DateKeys.day(day);

  final DateTime day;
  final String dayKey;
  final double rate;
  final List<Customer> customers;
  final Map<String, Delivery> recorded;

  /// Computed here once per state, not once per build.
  late final PeriodSummary summary = const ReportCalculator().summarise(
    deliveries: recorded.values.toList(),
    ratePerLitre: rate,
    activeCustomerCount: customers.length,
  );

  TodayState copyWith({
    double? rate,
    List<Customer>? customers,
    Map<String, Delivery>? recorded,
  }) => TodayState(
    day: day,
    rate: rate ?? this.rate,
    customers: customers ?? this.customers,
    recorded: recorded ?? this.recorded,
  );

  @override
  List<Object?> get props => [dayKey, rate, customers, recorded];
}
