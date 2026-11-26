import 'package:bloc_test/bloc_test.dart';
import 'package:doodh_app/core/utils/formats.dart';
import 'package:doodh_app/data/models/customer.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/data/repositories/customer_repository.dart';
import 'package:doodh_app/data/repositories/dairy_refs.dart';
import 'package:doodh_app/data/repositories/delivery_repository.dart';
import 'package:doodh_app/features/delivery/bloc/round_cubit.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void main() {
  late FakeFirebaseFirestore db;
  late DairyRefs refs;

  final day = DateTime(2026, 8, 18);
  final dayKey = DateKeys.day(day);

  Future<void> seedCustomers(List<Customer> list) async {
    for (final c in list) {
      await refs.customers.doc(c.id).set(c.toMap());
    }
  }

  RoundCubit build() => RoundCubit(
    customers: CustomerRepository(refs),
    deliveries: DeliveryRepository(refs),
    recordedBy: 'boy@doodh.local',
    now: day,
  );

  /// Lets both Firestore listeners deliver their first snapshot.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    db = FakeFirebaseFirestore();
    refs = DairyRefs(db, 'main');
    await seedCustomers([
      customer(id: 'c1', name: 'Ram', routeOrder: 1),
      customer(id: 'c2', name: 'Shyam', routeOrder: 2),
      customer(id: 'c3', name: 'Sita', routeOrder: 3),
    ]);
  });

  test('starts loading, then lists the active houses', () async {
    final cubit = build();
    expect(cubit.state.status, RoundStatus.loading);
    expect(cubit.state.dayKey, dayKey);

    await settle();

    expect(cubit.state.status, RoundStatus.ready);
    expect(cubit.state.customers.map((c) => c.id), ['c1', 'c2', 'c3']);
    expect(cubit.state.doneCount, 0);
    expect(cubit.state.isComplete, isFalse);
    await cubit.close();
  });

  blocTest<RoundCubit, RoundState>(
    'recording a house shows it as done straight away',
    build: build,
    act: (cubit) async {
      await settle();
      cubit.record(
        customerId: 'c3',
        qtyLitres: 1.5,
        status: DeliveryStatus.delivered,
      );
    },
    verify: (cubit) {
      expect(cubit.state.entryFor('c3')?.qtyLitres, 1.5);
      expect(cubit.state.entryFor('c1'), isNull);
      expect(cubit.state.doneCount, 1);
    },
  );

  blocTest<RoundCubit, RoundState>(
    'a skipped house is an entry with zero litres',
    // Telling "took nothing" apart from "never visited" is what makes the
    // missing-house list meaningful.
    build: build,
    act: (cubit) async {
      await settle();
      cubit.record(
        customerId: 'c1',
        qtyLitres: 3,
        status: DeliveryStatus.skipped,
      );
    },
    verify: (cubit) {
      final entry = cubit.state.entryFor('c1')!;
      expect(entry.status, DeliveryStatus.skipped);
      expect(entry.qtyLitres, 0);
      expect(entry.effectiveLitres, 0);
      expect(cubit.state.doneCount, 1);
    },
  );

  blocTest<RoundCubit, RoundState>(
    'every house recorded completes the round',
    build: build,
    act: (cubit) async {
      await settle();
      for (final id in ['c1', 'c2', 'c3']) {
        cubit.record(
          customerId: id,
          qtyLitres: 1,
          status: DeliveryStatus.delivered,
        );
      }
    },
    verify: (cubit) {
      expect(cubit.state.isComplete, isTrue);
      expect(cubit.state.remainingCount, 0);
    },
  );

  blocTest<RoundCubit, RoundState>(
    'missing lists only houses with no entry',
    build: build,
    act: (cubit) async {
      await settle();
      cubit.record(
        customerId: 'c1',
        qtyLitres: 2,
        status: DeliveryStatus.delivered,
      );
    },
    verify: (cubit) =>
        expect(cubit.state.missing.map((c) => c.id), ['c2', 'c3']),
  );

  blocTest<RoundCubit, RoundState>(
    'ignores an unknown customer id',
    // A voice match against a stale list must not create an orphan entry.
    build: build,
    act: (cubit) async {
      await settle();
      cubit.record(
        customerId: 'does-not-exist',
        qtyLitres: 2,
        status: DeliveryStatus.delivered,
      );
    },
    verify: (cubit) => expect(cubit.state.doneCount, 0),
  );

  blocTest<RoundCubit, RoundState>(
    'search updates the query',
    build: build,
    act: (cubit) async {
      await settle();
      cubit.search('ram');
    },
    verify: (cubit) {
      expect(cubit.state.query, 'ram');
      // Searching filters the view, never the round itself.
      expect(cubit.state.total, 3);
    },
  );

  test('entries already in Firestore count as done', () async {
    // Reopening the app mid-round must show the houses he already did.
    await refs.deliveries
        .doc('${dayKey}_c1')
        .set(delivery(customerId: 'c1', dayKey: dayKey).toMap());

    final cubit = build();
    await settle();

    expect(cubit.state.entryFor('c1'), isNotNull);
    expect(cubit.state.doneCount, 1);
    await cubit.close();
  });

  test('writes land in Firestore under the deterministic id', () async {
    final cubit = build();
    await settle();
    cubit.record(
      customerId: 'c2',
      qtyLitres: 2.5,
      status: DeliveryStatus.delivered,
    );
    await settle();

    final doc = await refs.deliveries.doc('${dayKey}_c2').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['qtyLitres'], 2.5);
    expect(doc.data()!['status'], 'delivered');
    expect(doc.data()!['recordedBy'], 'boy@doodh.local');
    await cubit.close();
  });

  test('recording one house twice overwrites instead of duplicating', () async {
    // This is the property that makes replaying a queued offline write safe.
    final cubit = build();
    await settle();
    cubit
      ..record(customerId: 'c1', qtyLitres: 2, status: DeliveryStatus.delivered)
      ..record(
        customerId: 'c1',
        qtyLitres: 3,
        status: DeliveryStatus.delivered,
      );
    await settle();

    final snap = await refs.deliveries
        .where('customerId', isEqualTo: 'c1')
        .get();
    expect(snap.docs.length, 1);
    expect(snap.docs.first.data()['qtyLitres'], 3);
    await cubit.close();
  });

  test('a house deactivated mid-round drops out of the list', () async {
    final cubit = build();
    await settle();

    await refs.customers.doc('c3').update({'active': false});
    await settle();

    expect(cubit.state.customers.map((c) => c.id), ['c1', 'c2']);
    expect(cubit.state.total, 2);
    await cubit.close();
  });

  test('closing cancels both Firestore listeners', () async {
    final cubit = build();
    await settle();
    await cubit.close();

    // A snapshot after close would throw "emit after close" if a listener
    // had been left running.
    await refs.customers.doc('c4').set(customer(id: 'c4').toMap());
    await settle();
    expect(cubit.isClosed, isTrue);
  });
}
