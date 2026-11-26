import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../../../core/utils/formats.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/delivery_repository.dart';

part 'round_state.dart';

/// Drives one morning's round.
///
/// Listens to the active customers and today's deliveries, and records
/// entries. The list and the voice entry both record by customer id: he taps
/// or names whichever house he just served, in whatever order he walks.
class RoundCubit extends Cubit<RoundState> {
  RoundCubit({
    required CustomerRepository customers,
    required DeliveryRepository deliveries,
    required this._recordedBy,
    DateTime? now,
  }) : _deliveries = deliveries,
       super(RoundState(dayKey: DateKeys.day(now ?? DateTime.now()))) {
    _customerSub = customers.watchActive().listen(
      (list) =>
          emit(state.copyWith(status: RoundStatus.ready, customers: list)),
      onError: _onError,
    );
    _deliverySub = deliveries
        .watchDay(state.dayKey)
        .listen(
          (map) => emit(state.copyWith(recorded: map)),
          onError: _onError,
        );
  }

  final DeliveryRepository _deliveries;
  final String _recordedBy;
  late final StreamSubscription<List<Customer>> _customerSub;
  late final StreamSubscription<Map<String, Delivery>> _deliverySub;

  void search(String query) => emit(state.copyWith(query: query));

  /// Record one house's entry.
  ///
  /// The Firestore write is deliberately **not awaited**: it lands in the
  /// local cache immediately, but its future only completes once the server
  /// acknowledges, which never happens offline. Awaiting would freeze the
  /// round the moment signal drops.
  void record({
    required String customerId,
    required double qtyLitres,
    required DeliveryStatus status,
  }) {
    // A voice match against a stale list must not create an orphan entry.
    if (!state.customers.any((c) => c.id == customerId)) return;

    final dayKey = state.dayKey;
    fireAndForget(
      _deliveries.record(
        dayKey: dayKey,
        customerId: customerId,
        qtyLitres: qtyLitres,
        status: status,
        recordedBy: _recordedBy,
      ),
    );

    // Reflect it locally right away. The snapshot listener confirms the same
    // value a moment later; showing it now keeps the row responsive.
    emit(
      state.copyWith(
        recorded: {
          ...state.recorded,
          customerId: Delivery(
            id: DateKeys.deliveryId(dayKey, customerId),
            dayKey: dayKey,
            customerId: customerId,
            qtyLitres: status == DeliveryStatus.skipped ? 0 : qtyLitres,
            status: status,
            recordedBy: _recordedBy,
            recordedAt: DateTime.now(),
          ),
        },
      ),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(state.copyWith(status: RoundStatus.failure));
  }

  @override
  Future<void> close() async {
    await _customerSub.cancel();
    await _deliverySub.cancel();
    return super.close();
  }
}
