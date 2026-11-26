import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../../../core/utils/formats.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/settings_repository.dart';

part 'today_state.dart';

/// Live view of the round in progress, plus the owner's corrections to it.
///
/// Every source is a Firestore snapshot listener, so the totals move the
/// moment the delivery person taps a house, or the moment his phone regains
/// signal if he was working offline.
class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required SettingsRepository settings,
    required CustomerRepository customers,
    required this._deliveries,
    required this._editorEmail,
    DateTime? now,
  }) : super(TodayState(day: now ?? DateTime.now())) {
    _subs = [
      settings.watchRate().listen(
        (rate) => emit(state.copyWith(rate: rate)),
        onError: addError,
      ),
      customers.watchActive().listen(
        (list) => emit(state.copyWith(customers: list)),
        onError: addError,
      ),
      _deliveries
          .watchDay(state.dayKey)
          .listen(
            (map) => emit(state.copyWith(recorded: map)),
            onError: addError,
          ),
    ];
  }

  final DeliveryRepository _deliveries;
  final String _editorEmail;
  late final List<StreamSubscription<Object?>> _subs;

  /// The owner's override for one house today.
  ///
  /// Filling a blank house is an original entry. Changing an existing one is
  /// a correction, stored with who made it and why, so a month's bill can be
  /// reconstructed later and any change explained.
  void saveEntry({
    required Customer customer,
    required Delivery? existing,
    required double qtyLitres,
    required DeliveryStatus status,
    String reason = '',
  }) {
    final isCorrection = existing != null;
    final trimmed = reason.trim();
    fireAndForget(
      _deliveries.record(
        dayKey: state.dayKey,
        customerId: customer.id,
        qtyLitres: qtyLitres,
        status: status,
        recordedBy: existing?.recordedBy ?? _editorEmail,
        editedBy: isCorrection ? _editorEmail : null,
        editReason: isCorrection ? (trimmed.isEmpty ? '—' : trimmed) : null,
      ),
    );
  }

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
