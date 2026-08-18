import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../core/utils/formats.dart';

enum DeliveryStatus { delivered, skipped }

/// One house, one day.
///
/// Document ID is `yyyy-MM-dd_customerId` (see [DateKeys.deliveryId]). That
/// determinism is what makes replaying the offline write queue safe — a repeat
/// sync overwrites the same document rather than creating a duplicate.
class Delivery extends Equatable {
  const Delivery({
    required this.id,
    required this.dayKey,
    required this.customerId,
    required this.qtyLitres,
    required this.status,
    required this.recordedBy,
    this.recordedAt,
    this.editedBy,
    this.editedAt,
    this.editReason,
  });

  final String id;
  final String dayKey;
  final String customerId;
  final double qtyLitres;
  final DeliveryStatus status;

  /// Email of whoever recorded it.
  final String recordedBy;
  final DateTime? recordedAt;

  /// Set only when the owner corrects a past entry. The presence of these
  /// fields is the audit trail — the original is never silently replaced.
  final String? editedBy;
  final DateTime? editedAt;
  final String? editReason;

  bool get wasEdited => editedBy != null;
  bool get isDelivered => status == DeliveryStatus.delivered;

  /// Skipped houses record 0 L, so summing [effectiveLitres] over a range is
  /// always correct regardless of status.
  double get effectiveLitres => isDelivered ? qtyLitres : 0;

  factory Delivery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Delivery(
      id: doc.id,
      dayKey: (d['dayKey'] as String?) ?? '',
      customerId: (d['customerId'] as String?) ?? '',
      qtyLitres: (d['qtyLitres'] as num?)?.toDouble() ?? 0,
      status: d['status'] == 'skipped'
          ? DeliveryStatus.skipped
          : DeliveryStatus.delivered,
      recordedBy: (d['recordedBy'] as String?) ?? '',
      recordedAt: (d['recordedAt'] as Timestamp?)?.toDate(),
      editedBy: d['editedBy'] as String?,
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
      editReason: d['editReason'] as String?,
    );
  }

  /// [recordedAt] uses a server timestamp so an unsynced phone with a wrong
  /// clock cannot distort the record; [deviceRecordedAt] keeps the local time
  /// for comparison when diagnosing a late sync.
  Map<String, dynamic> toMap() => {
    'dayKey': dayKey,
    'customerId': customerId,
    'qtyLitres': qtyLitres,
    'status': status.name,
    'recordedBy': recordedBy,
    'recordedAt': FieldValue.serverTimestamp(),
    'deviceRecordedAt': Timestamp.fromDate(DateTime.now()),
    if (editedBy != null) 'editedBy': editedBy,
    if (editedBy != null) 'editedAt': FieldValue.serverTimestamp(),
    if (editReason != null) 'editReason': editReason,
  };

  @override
  List<Object?> get props => [
    id,
    dayKey,
    customerId,
    qtyLitres,
    status,
    recordedBy,
    editedBy,
    editReason,
  ];
}
