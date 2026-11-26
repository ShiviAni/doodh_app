import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// What happened.
enum ActivityType {
  deliveryRecorded,
  deliveryEdited,
  deliveryRemoved,
  paymentLogged,
  paymentApproved,
  customerChanged,
  unknown;

  static ActivityType parse(String? raw) => switch (raw) {
    'delivery_recorded' => ActivityType.deliveryRecorded,
    'delivery_edited' => ActivityType.deliveryEdited,
    'delivery_removed' => ActivityType.deliveryRemoved,
    'payment_logged' => ActivityType.paymentLogged,
    'payment_approved' => ActivityType.paymentApproved,
    'customer_changed' => ActivityType.customerChanged,
    _ => ActivityType.unknown,
  };
}

/// One entry in the permanent change history.
///
/// Written by a Cloud Function on the server, never by the app. That matters:
/// the history has to record what *happened to the data*, so it cannot depend
/// on the client choosing to report it. A modified APK still trips the trigger.
class Activity extends Equatable {
  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Activity(
      id: doc.id,
      type: ActivityType.parse(d['type'] as String?),
      actorEmail: (d['actorEmail'] as String?) ?? '',
      at: (d['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customerId: d['customerId'] as String?,
      customerName: d['customerName'] as String?,
      dayKey: d['dayKey'] as String?,
      beforeLitres: (d['beforeLitres'] as num?)?.toDouble(),
      afterLitres: (d['afterLitres'] as num?)?.toDouble(),
      beforeStatus: d['beforeStatus'] as String?,
      afterStatus: d['afterStatus'] as String?,
      amount: (d['amount'] as num?)?.toDouble(),
      reason: d['reason'] as String?,
    );
  }
  const Activity({
    required this.id,
    required this.type,
    required this.actorEmail,
    required this.at,
    this.customerId,
    this.customerName,
    this.dayKey,
    this.beforeLitres,
    this.afterLitres,
    this.beforeStatus,
    this.afterStatus,
    this.amount,
    this.reason,
  });

  final String id;
  final ActivityType type;

  /// Who caused it — the delivery person or the owner.
  final String actorEmail;
  final DateTime at;

  final String? customerId;

  /// Denormalised so the history still reads correctly after a customer is
  /// renamed or deactivated.
  final String? customerName;
  final String? dayKey;

  /// Null on a first record; set when a value was changed, so the history shows
  /// "2 litres changed to 3" rather than just the new number.
  final double? beforeLitres;
  final double? afterLitres;
  final String? beforeStatus;
  final String? afterStatus;

  final double? amount;
  final String? reason;

  bool get isChange => beforeLitres != null || beforeStatus != null;

  @override
  List<Object?> get props => [id, type, actorEmail, at, customerId, dayKey];
}
