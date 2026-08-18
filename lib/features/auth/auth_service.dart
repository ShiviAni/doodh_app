import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/member.dart';
import '../../data/repositories/member_repository.dart';

/// The signed-in user together with the role the dairy has granted them.
class Session {
  const Session({required this.email, required this.member});

  final String email;

  /// Null when the account exists in Firebase Auth but is not listed as a
  /// member of this dairy — the app shows "no access" rather than an empty
  /// dashboard, so a mistyped invite is obvious instead of confusing.
  final Member? member;

  bool get hasAccess => member != null;
  bool get isOwner => member?.isOwner ?? false;
  bool get isDelivery => member?.isDelivery ?? false;
}

class AuthService {
  AuthService(this._auth, this._members);

  final FirebaseAuth _auth;
  final MemberRepository _members;

  /// Emits on every sign-in/sign-out, resolving the role each time.
  Stream<Session?> watchSession() =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null || user.email == null) return null;
        final email = user.email!.toLowerCase();
        return Session(email: email, member: await _members.fetch(email));
      });

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

  Future<void> signOut() => _auth.signOut();

  String? get currentEmail => _auth.currentUser?.email?.toLowerCase();
}
