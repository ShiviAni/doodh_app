import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MemberRole { owner, delivery }

/// A person with access to a dairy.
///
/// The document ID is the member's **lowercased email**, which is what lets the
/// security rules resolve a role straight from `request.auth.token.email` with
/// no Cloud Function and no uid-claiming step.
class Member extends Equatable {
  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Member(
      email: doc.id,
      role: d['role'] == 'owner' ? MemberRole.owner : MemberRole.delivery,
      displayName: (d['displayName'] as String?) ?? doc.id,
      phone: d['phone'] as String?,
      active: (d['active'] as bool?) ?? true,
    );
  }
  const Member({
    required this.email,
    required this.role,
    required this.displayName,
    this.phone,
    this.active = true,
  });

  final String email;
  final MemberRole role;
  final String displayName;
  final String? phone;
  final bool active;

  bool get isOwner => role == MemberRole.owner;
  bool get isDelivery => role == MemberRole.delivery;

  Map<String, dynamic> toMap() => {
    'role': role.name,
    'displayName': displayName,
    if (phone != null) 'phone': phone,
    'active': active,
  };

  @override
  List<Object?> get props => [email, role, displayName, phone, active];
}
