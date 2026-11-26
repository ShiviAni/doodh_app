part of 'money_cubit.dart';

final class MoneyState extends Equatable {
  MoneyState({
    required this.month,
    this.rate = SettingsRepository.defaultRate,
    this.customers = const [],
    this.payments = const [],
    this.deliveries = const [],
  });

  /// Any day in the month being shown.
  final DateTime month;
  final double rate;
  final List<Customer> customers;
  final List<Payment> payments;

  /// The shown month's deliveries only.
  final List<Delivery> deliveries;

  static const _calc = ReportCalculator();

  String get monthKey => DateKeys.month(month);

  // Each figure is worked out once per state, not on every build.

  late final Map<String, Bill> bills = {
    for (final c in customers)
      c.id: _calc.billFor(
        customer: c,
        monthKey: monthKey,
        monthDeliveries: deliveries,
        allPayments: payments,
        ratePerLitre: rate,
      ),
  };

  late final double billed = bills.values.fold(0, (sum, b) => sum + b.amount);
  late final double collected = bills.values.fold(
    0,
    (sum, b) => sum + b.paidAmount,
  );
  double get balance => billed - collected;

  /// Doorstep cash waiting on the owner. Nothing here affects a balance
  /// until it is approved.
  late final List<Payment> pending = payments
      .where((p) => !p.approved)
      .toList();

  late final List<Customer> activeCustomers = customers
      .where((c) => c.active)
      .toList();

  /// Litres per day for one customer this month, for the WhatsApp bill.
  Map<String, double> perDayFor(String customerId) => _calc.litresByDay(
    deliveries.where((d) => d.customerId == customerId).toList(),
  );

  String customerName(String customerId, {required bool hindi}) =>
      customers
          .where((c) => c.id == customerId)
          .map((c) => c.displayName(hindi: hindi))
          .firstOrNull ??
      customerId;

  MoneyState copyWith({
    DateTime? month,
    double? rate,
    List<Customer>? customers,
    List<Payment>? payments,
    List<Delivery>? deliveries,
  }) => MoneyState(
    month: month ?? this.month,
    rate: rate ?? this.rate,
    customers: customers ?? this.customers,
    payments: payments ?? this.payments,
    deliveries: deliveries ?? this.deliveries,
  );

  @override
  List<Object?> get props => [month, rate, customers, payments, deliveries];
}
