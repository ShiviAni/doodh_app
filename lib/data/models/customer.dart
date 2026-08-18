import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A house on the milk round.
///
/// Deliberately carries **no money fields**. Firestore rules grant access per
/// document, never per field — so a balance stored here would be readable by
/// the delivery role the moment it read the customer's name. Money lives in
/// separate owner-only collections instead.
class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.houseNo,
    required this.defaultQtyLitres,
    required this.routeOrder,
    this.nameHi,
    this.phone,
    this.photoUrl,
    this.active = true,
  });

  final String id;
  final String name;

  /// Optional Devanagari spelling; the delivery card prefers this when the UI
  /// language is Hindi.
  final String? nameHi;
  final String houseNo;
  final String? phone;
  final String? photoUrl;

  /// Pre-filled quantity on the delivery card, so a normal day is one tap.
  final double defaultQtyLitres;

  /// Position on the walking route. Drives the order of the delivery cards.
  final int routeOrder;
  final bool active;

  String displayName({required bool hindi}) =>
      hindi && (nameHi?.isNotEmpty ?? false) ? nameHi! : name;

  factory Customer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Customer(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      nameHi: d['nameHi'] as String?,
      houseNo: (d['houseNo'] as String?) ?? '',
      phone: d['phone'] as String?,
      photoUrl: d['photoUrl'] as String?,
      defaultQtyLitres: (d['defaultQtyLitres'] as num?)?.toDouble() ?? 1.0,
      routeOrder: (d['routeOrder'] as num?)?.toInt() ?? 0,
      active: (d['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'nameHi': nameHi,
    'houseNo': houseNo,
    'phone': phone,
    'photoUrl': photoUrl,
    'defaultQtyLitres': defaultQtyLitres,
    'routeOrder': routeOrder,
    'active': active,
  };

  Customer copyWith({
    String? name,
    String? nameHi,
    String? houseNo,
    String? phone,
    String? photoUrl,
    double? defaultQtyLitres,
    int? routeOrder,
    bool? active,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    nameHi: nameHi ?? this.nameHi,
    houseNo: houseNo ?? this.houseNo,
    phone: phone ?? this.phone,
    photoUrl: photoUrl ?? this.photoUrl,
    defaultQtyLitres: defaultQtyLitres ?? this.defaultQtyLitres,
    routeOrder: routeOrder ?? this.routeOrder,
    active: active ?? this.active,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    nameHi,
    houseNo,
    phone,
    photoUrl,
    defaultQtyLitres,
    routeOrder,
    active,
  ];
}
