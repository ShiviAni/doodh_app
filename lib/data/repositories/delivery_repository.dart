import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/formats.dart';
import '../models/delivery.dart';
import 'dairy_refs.dart';

class DeliveryRepository {
  DeliveryRepository(this._refs);

  final DairyRefs _refs;

  /// Every delivery for one day, keyed by customer ID for O(1) lookup while
  /// paging through the round.
  Stream<Map<String, Delivery>> watchDay(String dayKey) => _refs.deliveries
      .where('dayKey', isEqualTo: dayKey)
      .snapshots()
      .map(
        (snap) => {
          for (final doc in snap.docs)
            Delivery.fromDoc(doc).customerId: Delivery.fromDoc(doc),
        },
      );

  /// Inclusive range over the `dayKey` string. Works because `yyyy-MM-dd` sorts
  /// lexicographically in the same order as chronologically.
  Stream<List<Delivery>> watchRange(String fromDayKey, String toDayKey) => _refs
      .deliveries
      .where('dayKey', isGreaterThanOrEqualTo: fromDayKey)
      .where('dayKey', isLessThanOrEqualTo: toDayKey)
      .snapshots()
      .map((snap) => snap.docs.map(Delivery.fromDoc).toList());

  Future<List<Delivery>> fetchRange(String fromDayKey, String toDayKey) async {
    final snap = await _refs.deliveries
        .where('dayKey', isGreaterThanOrEqualTo: fromDayKey)
        .where('dayKey', isLessThanOrEqualTo: toDayKey)
        .get();
    return snap.docs.map(Delivery.fromDoc).toList();
  }

  /// Record (or correct) one house for one day.
  ///
  /// Deliberately **not** awaited by the delivery UI. Firestore applies the
  /// write to its local cache synchronously and resolves this future only once
  /// the server acknowledges it — which never happens while offline. Awaiting
  /// would freeze the round the moment signal drops.
  Future<void> record({
    required String dayKey,
    required String customerId,
    required double qtyLitres,
    required DeliveryStatus status,
    required String recordedBy,
    String? editedBy,
    String? editReason,
  }) {
    final id = DateKeys.deliveryId(dayKey, customerId);
    final delivery = Delivery(
      id: id,
      dayKey: dayKey,
      customerId: customerId,
      qtyLitres: status == DeliveryStatus.skipped ? 0 : qtyLitres,
      status: status,
      recordedBy: recordedBy,
      editedBy: editedBy,
      editReason: editReason,
    );
    // set+merge on a deterministic ID: replaying a queued offline write
    // overwrites one document instead of creating a second.
    return _refs.deliveries
        .doc(id)
        .set(delivery.toMap(), SetOptions(merge: true));
  }

  /// Count of writes still queued locally, surfaced as the sync badge.
  ///
  /// `hasPendingWrites` on the *metadata* is Firestore's own signal that a
  /// document exists in the local cache but has not been acknowledged.
  Stream<int> watchPendingCount(String dayKey) => _refs.deliveries
      .where('dayKey', isEqualTo: dayKey)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snap) => snap.docs.where((d) => d.metadata.hasPendingWrites).length,
      );
}
