part of 'cash_log_cubit.dart';

final class CashLogState extends Equatable {
  const CashLogState({this.amount = 0, this.submitted = false});

  final double amount;
  final bool submitted;

  bool get canSubmit => amount > 0 && !submitted;

  @override
  List<Object?> get props => [amount, submitted];
}
