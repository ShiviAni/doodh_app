import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer.dart';
import 'dairy_refs.dart';

class CustomerRepository {
  CustomerRepository(this._refs);

  final DairyRefs _refs;

  /// Active houses in walking order — the sequence the delivery cards follow.
  ///
  /// Ordering is applied client-side so the query needs no composite index and
  /// no `active == true` filter that would fight Firestore's offline cache.
  Stream<List<Customer>> watchActive() => _refs.customers.snapshots().map((
    snap,
  ) {
    final list = snap.docs.map(Customer.fromDoc).where((c) => c.active).toList()
      ..sort((a, b) {
        final byOrder = a.routeOrder.compareTo(b.routeOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return list;
  });

  Stream<List<Customer>> watchAll() => _refs.customers.snapshots().map((snap) {
    final list = snap.docs.map(Customer.fromDoc).toList()
      ..sort((a, b) => a.routeOrder.compareTo(b.routeOrder));
    return list;
  });

  Future<void> upsert(Customer c) =>
      _refs.customers.doc(c.id).set(c.toMap(), SetOptions(merge: true));

  Future<String> add(Customer c) async {
    final doc = _refs.customers.doc();
    await doc.set(c.toMap());
    return doc.id;
  }

  /// Customers are deactivated, never deleted — their delivery history has to
  /// stay intact for past months' bills to remain correct.
  Future<void> deactivate(String id) =>
      _refs.customers.doc(id).update({'active': false});
}
