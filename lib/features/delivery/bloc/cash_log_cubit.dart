import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';

part 'cash_log_state.dart';

/// Cash handed to the delivery person at the door.
///
/// Write-only by design: no total, balance or history is ever read back, and
/// the security rules deny him read access to payments. What he records lands
/// unapproved and only counts once the owner confirms it.
class CashLogCubit extends Cubit<CashLogState> {
  CashLogCubit({
    required this._payments,
    required this._customerId,
    required this._dayKey,
    required this._recordedBy,
  }) : super(const CashLogState());

  final PaymentRepository _payments;
  final String _customerId;
  final String _dayKey;
  final String _recordedBy;

  void addNote(double note) => emit(CashLogState(amount: state.amount + note));

  void clear() => emit(const CashLogState());

  void submit() {
    if (!state.canSubmit) return;
    fireAndForget(
      _payments.create(
        Payment(
          id: '',
          customerId: _customerId,
          amount: state.amount,
          method: PaymentMethod.cash,
          dayKey: _dayKey,
          recordedBy: _recordedBy,
        ),
      ),
    );
    emit(CashLogState(amount: state.amount, submitted: true));
  }
}
