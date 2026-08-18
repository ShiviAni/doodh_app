import 'package:doodh_app/core/utils/formats.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/data/repositories/dairy_refs.dart';
import 'package:doodh_app/data/repositories/delivery_repository.dart';
import 'package:doodh_app/features/delivery/round_controller.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void main() {
  late FakeFirebaseFirestore db;
  late DeliveryRepository repo;
  late RoundController round;

  final day = DateTime(2026, 8, 18);
  final dayKey = DateKeys.day(day);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = DeliveryRepository(DairyRefs(db, 'main'));
    round = RoundController(
      deliveries: repo,
      recordedBy: 'boy@doodh.local',
      now: day,
    );
    round.setCustomers([
      customer(id: 'c1', name: 'Ram', routeOrder: 1),
      customer(id: 'c2', name: 'Shyam', routeOrder: 2),
      customer(id: 'c3', name: 'Sita', routeOrder: 3),
    ]);
  });

  tearDown(() => round.dispose());

  test('starts at the first house', () {
    expect(round.current?.id, 'c1');
    expect(round.total, 3);
    expect(round.doneCount, 0);
    expect(round.isComplete, isFalse);
  });

  test('recording advances to the next house', () {
    round.record(qtyLitres: 2.0, status: DeliveryStatus.delivered);

    expect(round.current?.id, 'c2');
    expect(round.doneCount, 1);
  });

  test('a skipped house is recorded as an entry with zero litres', () {
    // Distinguishing "took nothing" from "never visited" is what makes the
    // missing-house alert meaningful.
    round.record(qtyLitres: 3.0, status: DeliveryStatus.skipped);

    final entry = round.entryFor('c1')!;
    expect(entry.status, DeliveryStatus.skipped);
    expect(entry.qtyLitres, 0);
    expect(entry.effectiveLitres, 0);
    expect(round.doneCount, 1);
  });

  test('does not advance past the last house', () {
    round.record(qtyLitres: 1, status: DeliveryStatus.delivered);
    round.record(qtyLitres: 1, status: DeliveryStatus.delivered);
    round.record(qtyLitres: 1, status: DeliveryStatus.delivered);

    expect(round.current?.id, 'c3');
    expect(round.isComplete, isTrue);
    expect(round.remainingCount, 0);
  });

  test('missing lists only houses with no entry', () {
    round.record(qtyLitres: 2.0, status: DeliveryStatus.delivered);

    expect(round.missing.map((c) => c.id), ['c2', 'c3']);
  });

  test('jumpToFirstPending resumes mid-round rather than restarting', () {
    // Reopening the app after two houses should land on the third, not the
    // first — otherwise he re-walks work he already did.
    round.setRecorded({
      'c1': delivery(customerId: 'c1', dayKey: dayKey),
      'c2': delivery(customerId: 'c2', dayKey: dayKey),
    });
    round.jumpToFirstPending();

    expect(round.current?.id, 'c3');
  });

  test('going back re-opens the previous house', () {
    round.record(qtyLitres: 2.0, status: DeliveryStatus.delivered);
    round.previous();

    expect(round.current?.id, 'c1');
  });

  test('previous does nothing at the first house', () {
    round.previous();
    expect(round.current?.id, 'c1');
  });

  test('writes land in Firestore under the deterministic id', () async {
    round.record(qtyLitres: 2.5, status: DeliveryStatus.delivered);
    // The write is intentionally not awaited by the UI; give it a turn.
    await Future<void>.delayed(Duration.zero);

    final doc = await db
        .collection('dairies/main/deliveries')
        .doc('${dayKey}_c1')
        .get();

    expect(doc.exists, isTrue);
    expect(doc.data()!['qtyLitres'], 2.5);
    expect(doc.data()!['status'], 'delivered');
    expect(doc.data()!['recordedBy'], 'boy@doodh.local');
  });

  test(
    're-recording the same house overwrites instead of duplicating',
    () async {
      // This is the property that makes replaying a queued offline write safe.
      round.record(qtyLitres: 2.0, status: DeliveryStatus.delivered);
      round.previous();
      round.record(qtyLitres: 3.0, status: DeliveryStatus.delivered);
      await Future<void>.delayed(Duration.zero);

      final snap = await db
          .collection('dairies/main/deliveries')
          .where('customerId', isEqualTo: 'c1')
          .get();

      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['qtyLitres'], 3.0);
    },
  );

  test('recordFor records a house that is not the current one', () async {
    // The delivery person taps the third house while the cursor is on the
    // first. Recording must land on the house he tapped.
    round.recordFor(
      customerId: 'c3',
      qtyLitres: 1.5,
      status: DeliveryStatus.delivered,
    );
    await Future<void>.delayed(Duration.zero);

    expect(round.entryFor('c3')?.qtyLitres, 1.5);
    expect(round.entryFor('c1'), isNull);
    // The cursor must not jump around under him.
    expect(round.current?.id, 'c1');
  });

  test('recordFor ignores an unknown customer id', () {
    // A voice match against a stale list must not create an orphan entry.
    round.recordFor(
      customerId: 'does-not-exist',
      qtyLitres: 2,
      status: DeliveryStatus.delivered,
    );

    expect(round.doneCount, 0);
  });

  test('recordFor writes under the deterministic id', () async {
    round.recordFor(
      customerId: 'c2',
      qtyLitres: 3,
      status: DeliveryStatus.delivered,
    );
    await Future<void>.delayed(Duration.zero);

    final doc = await db
        .collection('dairies/main/deliveries')
        .doc('${dayKey}_c2')
        .get();

    expect(doc.exists, isTrue);
    expect(doc.data()!['qtyLitres'], 3);
  });

  test(
    'recordFor twice on one house overwrites rather than duplicates',
    () async {
      round.recordFor(
        customerId: 'c1',
        qtyLitres: 2,
        status: DeliveryStatus.delivered,
      );
      round.recordFor(
        customerId: 'c1',
        qtyLitres: 2.5,
        status: DeliveryStatus.delivered,
      );
      await Future<void>.delayed(Duration.zero);

      final snap = await db
          .collection('dairies/main/deliveries')
          .where('customerId', isEqualTo: 'c1')
          .get();

      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['qtyLitres'], 2.5);
    },
  );

  test('shrinking the customer list keeps the cursor in range', () {
    // The owner deactivating a house mid-round must not leave the index
    // pointing past the end of the list.
    round.record(qtyLitres: 1, status: DeliveryStatus.delivered);
    round.record(qtyLitres: 1, status: DeliveryStatus.delivered);
    round.setCustomers([customer(id: 'c1', routeOrder: 1)]);

    expect(round.current?.id, 'c1');
  });
}

// --- recordFor: the path used by the list and by voice entry ---------------
//
// Neither the list nor the microphone has a notion of a "current" house — he
// taps or names whichever one he just served — so recording by id has to work
// independently of where the cursor happens to sit.
