import 'package:cloud_firestore/cloud_firestore.dart';

import 'dairy_refs.dart';

/// The ₹/litre rate. Owner-only by rule — the delivery app never receives it,
/// which is what makes "he cannot work out the money" true rather than a
/// matter of which buttons are hidden.
class SettingsRepository {
  SettingsRepository(this._refs);

  final DairyRefs _refs;

  static const double defaultRate = 60;

  Stream<double> watchRate() => _refs.billingSettings.snapshots().map(
    (doc) => (doc.data()?['ratePerLitre'] as num?)?.toDouble() ?? defaultRate,
  );

  Future<double> fetchRate() async {
    final doc = await _refs.billingSettings.get();
    return (doc.data()?['ratePerLitre'] as num?)?.toDouble() ?? defaultRate;
  }

  Future<void> setRate(double rate) => _refs.billingSettings.set({
    'ratePerLitre': rate,
  }, SetOptions(merge: true));
}
