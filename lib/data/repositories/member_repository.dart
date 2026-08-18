import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member.dart';
import 'dairy_refs.dart';

class MemberRepository {
  MemberRepository(this._refs);

  final DairyRefs _refs;

  /// Resolve the signed-in user's role.
  ///
  /// The document key is the lowercased email, matching what the security rules
  /// read out of `request.auth.token.email`. Returns null when the account is
  /// not attached to this dairy, which the app surfaces as "no access" rather
  /// than dropping the user into an empty dashboard.
  Future<Member?> fetch(String email) async {
    final doc = await _refs.members.doc(email.toLowerCase()).get();
    if (!doc.exists) return null;
    final member = Member.fromDoc(doc);
    return member.active ? member : null;
  }

  Stream<List<Member>> watchAll() => _refs.members.snapshots().map(
    (snap) => snap.docs.map(Member.fromDoc).toList(),
  );

  Future<void> upsert(Member m) => _refs.members
      .doc(m.email.toLowerCase())
      .set(m.toMap(), SetOptions(merge: true));

  Future<void> remove(String email) =>
      _refs.members.doc(email.toLowerCase()).delete();
}
