import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment.dart';
import 'dairy_refs.dart';

class PaymentRepository {
  PaymentRepository(this._refs);

  final DairyRefs _refs;

  /// Owner-only. The delivery role has no read rule for this collection, so
  /// calling this from the delivery app fails at the server, not just in UI.
  Stream<List<Payment>> watchAll() => _refs.payments.snapshots().map(
    (snap) =>
        snap.docs.map(Payment.fromDoc).toList()
          ..sort((a, b) => b.dayKey.compareTo(a.dayKey)),
  );

  Stream<List<Payment>> watchPendingApproval() =>
      watchAll().map((all) => all.where((p) => !p.approved).toList());

  /// Called by both roles. The `approved` flag is forced false for the delivery
  /// role by the security rules, so an unapproved entry can never silently
  /// reduce a customer's balance.
  Future<void> create(Payment p) => _refs.payments.doc().set(p.toMap());

  Future<void> approve(String paymentId, String approverEmail) =>
      _refs.payments.doc(paymentId).update({
        'approved': true,
        'approvedBy': approverEmail,
        'approvedAt': FieldValue.serverTimestamp(),
      });

  Future<void> reject(String paymentId) =>
      _refs.payments.doc(paymentId).delete();
}
