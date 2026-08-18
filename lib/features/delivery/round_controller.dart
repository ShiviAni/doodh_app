import 'package:flutter/foundation.dart';

import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/delivery_repository.dart';

/// Drives one morning's round: which house is on screen, what has been
/// recorded, and what is still outstanding.
///
/// A plain [ChangeNotifier] rather than a bloc — the state is a cursor and a
/// map, and the ceremony of events/states would obscure rather than clarify it.
class RoundController extends ChangeNotifier {
  RoundController({
    required this.deliveries,
    required this.recordedBy,
    DateTime? now,
  }) : dayKey = DateKeys.day(now ?? DateTime.now());

  final DeliveryRepository deliveries;
  final String recordedBy;
  final String dayKey;

  List<Customer> _customers = const [];
  Map<String, Delivery> _recorded = const {};
  int _index = 0;

  List<Customer> get customers => _customers;
  Map<String, Delivery> get recorded => _recorded;
  int get index => _index;

  int get total => _customers.length;
  int get doneCount =>
      _customers.where((c) => _recorded.containsKey(c.id)).length;
  int get remainingCount => total - doneCount;
  bool get isComplete => total > 0 && remainingCount == 0;

  Customer? get current =>
      _index >= 0 && _index < _customers.length ? _customers[_index] : null;

  Delivery? entryFor(String customerId) => _recorded[customerId];

  /// Houses with no entry at all — what the done screen lists so nothing goes
  /// silently unrecorded.
  List<Customer> get missing =>
      _customers.where((c) => !_recorded.containsKey(c.id)).toList();

  void setCustomers(List<Customer> list) {
    _customers = list;
    if (_index >= list.length) _index = list.isEmpty ? 0 : list.length - 1;
    notifyListeners();
  }

  void setRecorded(Map<String, Delivery> recorded) {
    _recorded = recorded;
    notifyListeners();
  }

  /// Open the first house that has no entry yet, so reopening the app mid-round
  /// resumes where he stopped instead of starting over.
  void jumpToFirstPending() {
    final i = _customers.indexWhere((c) => !_recorded.containsKey(c.id));
    _index = i == -1 ? 0 : i;
    notifyListeners();
  }

  void jumpTo(String customerId) {
    final i = _customers.indexWhere((c) => c.id == customerId);
    if (i != -1) {
      _index = i;
      notifyListeners();
    }
  }

  void next() {
    if (_index < _customers.length - 1) {
      _index++;
      notifyListeners();
    }
  }

  void previous() {
    if (_index > 0) {
      _index--;
      notifyListeners();
    }
  }

  /// Record the house currently on screen, then move to the next one.
  void record({required double qtyLitres, required DeliveryStatus status}) {
    final customer = current;
    if (customer == null) return;
    recordFor(
      customerId: customer.id,
      qtyLitres: qtyLitres,
      status: status,
      advance: true,
    );
  }

  /// Record any house by id.
  ///
  /// The list and the voice entry both call this, since neither has a notion
  /// of a "current" house — he taps or names whichever one he just served.
  ///
  /// The Firestore write is deliberately **not awaited**: it lands in the local
  /// cache immediately, but the returned future only completes once the server
  /// acknowledges — which never happens while offline. Awaiting here would
  /// freeze the round the moment signal drops.
  void recordFor({
    required String customerId,
    required double qtyLitres,
    required DeliveryStatus status,
    bool advance = false,
  }) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return;

    unawaited(
      deliveries.record(
        dayKey: dayKey,
        customerId: customerId,
        qtyLitres: qtyLitres,
        status: status,
        recordedBy: recordedBy,
      ),
    );

    // Reflect it locally right away. The snapshot listener will confirm the
    // same value a moment later; showing it now keeps the row responsive.
    _recorded = {
      ..._recorded,
      customerId: Delivery(
        id: DateKeys.deliveryId(dayKey, customerId),
        dayKey: dayKey,
        customerId: customerId,
        qtyLitres: status == DeliveryStatus.skipped ? 0 : qtyLitres,
        status: status,
        recordedBy: recordedBy,
        recordedAt: DateTime.now(),
      ),
    };

    if (advance && _index < _customers.length - 1) _index++;
    notifyListeners();
  }
}

/// Local `unawaited` so this file needn't pull in dart:async for one call.
void unawaited(Future<void> future) {
  future.catchError((Object _) {
    // Firestore retries queued writes itself; a failure here means the write
    // is still pending, not lost. The sync badge is what surfaces that.
  });
}
