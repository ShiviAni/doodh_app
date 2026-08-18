import 'package:cloud_firestore/cloud_firestore.dart';

/// Central place where every Firestore path is built.
///
/// The split of collections here *is* the security model: `customers` and
/// `deliveries` are readable by the delivery role, while `settings`, `payments`,
/// `balances`, `bills` and `rollups` are owner-only. Because Firestore grants
/// access per document and never per field, no rupee value may ever be stored
/// on a customer or delivery document.
class DairyRefs {
  DairyRefs(this.db, this.dairyId);

  final FirebaseFirestore db;
  final String dairyId;

  DocumentReference<Map<String, dynamic>> get dairy =>
      db.collection('dairies').doc(dairyId);

  // --- readable by delivery role ---
  CollectionReference<Map<String, dynamic>> get members =>
      dairy.collection('members');
  CollectionReference<Map<String, dynamic>> get customers =>
      dairy.collection('customers');
  CollectionReference<Map<String, dynamic>> get deliveries =>
      dairy.collection('deliveries');

  // --- owner only ---
  DocumentReference<Map<String, dynamic>> get billingSettings =>
      dairy.collection('settings').doc('billing');
  CollectionReference<Map<String, dynamic>> get payments =>
      dairy.collection('payments');
  CollectionReference<Map<String, dynamic>> get monthlyRollups =>
      dairy.collection('monthlyRollups');

  /// Permanent change history. Written only by Cloud Functions running with
  /// admin credentials — no client, owner included, may write here.
  CollectionReference<Map<String, dynamic>> get activity =>
      dairy.collection('activity');

  /// Device push tokens for the owner. Written by the owner's app on launch,
  /// read by the Cloud Function that sends notifications.
  CollectionReference<Map<String, dynamic>> get ownerTokens =>
      dairy.collection('ownerTokens');
}
