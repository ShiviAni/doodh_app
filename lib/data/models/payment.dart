import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, upi, other }

/// Money received from a customer.
///
/// The delivery role may **create** these (he collects cash at the door) but
/// has no read access to the collection, so logging a payment never reveals a
/// running total or a due. Anything he creates lands with [approved] false and
/// only counts towards a balance once the owner approves it.
class Payment extends Equatable {
  factory Payment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Payment(
      id: doc.id,
      customerId: (d['customerId'] as String?) ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == d['method'],
        orElse: () => PaymentMethod.cash,
      ),
      dayKey: (d['dayKey'] as String?) ?? '',
      recordedBy: (d['recordedBy'] as String?) ?? '',
      approved: (d['approved'] as bool?) ?? false,
      approvedBy: d['approvedBy'] as String?,
      recordedAt: (d['recordedAt'] as Timestamp?)?.toDate(),
      note: d['note'] as String?,
    );
  }
  const Payment({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.method,
    required this.dayKey,
    required this.recordedBy,
    this.approved = false,
    this.approvedBy,
    this.recordedAt,
    this.note,
  });

  final String id;
  final String customerId;
  final double amount;
  final PaymentMethod method;
  final String dayKey;
  final String recordedBy;
  final bool approved;
  final String? approvedBy;
  final DateTime? recordedAt;
  final String? note;

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'amount': amount,
    'method': method.name,
    'dayKey': dayKey,
    'recordedBy': recordedBy,
    'approved': approved,
    if (approvedBy != null) 'approvedBy': approvedBy,
    'recordedAt': FieldValue.serverTimestamp(),
    if (note != null) 'note': note,
  };

  @override
  List<Object?> get props => [
    id,
    customerId,
    amount,
    method,
    dayKey,
    recordedBy,
    approved,
    approvedBy,
    note,
  ];
}
