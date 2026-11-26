import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../../../core/utils/formats.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/settings_repository.dart';

part 'money_state.dart';

/// Who owes what for a month, and what has been collected.
///
/// Everything here is owner-only at the rules level. The delivery role has no
/// read access to payments or the rate, so none of these figures are
/// reachable from his install even with a modified build.
class MoneyCubit extends Cubit<MoneyState> {
  MoneyCubit({
    required SettingsRepository settings,
    required CustomerRepository customers,
    required this._payments,
    required this._deliveries,
    required this._ownerEmail,
    DateTime? now,
  }) : super(MoneyState(month: now ?? DateTime.now())) {
    _subs = [
      settings.watchRate().listen(
        (rate) => emit(state.copyWith(rate: rate)),
        onError: addError,
      ),
      customers.watchAll().listen(
        (list) => emit(state.copyWith(customers: list)),
        onError: addError,
      ),
      _payments.watchAll().listen(
        (list) => emit(state.copyWith(payments: list)),
        onError: addError,
      ),
    ];
    _watchMonth();
  }

  final PaymentRepository _payments;
  final DeliveryRepository _deliveries;
  final String _ownerEmail;
  late final List<StreamSubscription<Object?>> _subs;
  StreamSubscription<List<Delivery>>? _monthSub;

  /// One month back (-1) or forward (+1).
  void shiftMonth(int direction) {
    final m = state.month;
    // Last month's deliveries are dropped, not kept on screen while the new
    // month loads: for a moment they would be billed under the wrong label.
    emit(
      state.copyWith(
        month: DateTime(m.year, m.month + direction),
        deliveries: const [],
      ),
    );
    _watchMonth();
  }

  /// Confirms cash the delivery person logged. Only then does it count.
  void approve(String paymentId) =>
      fireAndForget(_payments.approve(paymentId, _ownerEmail));

  void reject(String paymentId) => fireAndForget(_payments.reject(paymentId));

  /// A payment the owner took himself. It lands approved: the owner is the
  /// authority the approval queue exists to defer to.
  void recordPayment({
    required String customerId,
    required String amount,
    required PaymentMethod method,
    DateTime? now,
  }) {
    final value = Validators.parsePositive(amount);
    if (value == null) return;
    fireAndForget(
      _payments.create(
        Payment(
          id: '',
          customerId: customerId,
          amount: value,
          method: method,
          dayKey: DateKeys.day(now ?? DateTime.now()),
          recordedBy: _ownerEmail,
          approved: true,
          approvedBy: _ownerEmail,
        ),
      ),
    );
  }

  void _watchMonth() {
    unawaited(_monthSub?.cancel());
    final month = state.month;
    _monthSub = _deliveries
        .watchRange(
          '${DateKeys.month(month)}-01',
          DateKeys.day(DateKeys.endOfMonth(month)),
        )
        .listen(
          (list) => emit(state.copyWith(deliveries: list)),
          onError: addError,
        );
  }

  @override
  Future<void> close() async {
    await _monthSub?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
