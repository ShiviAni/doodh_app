import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doodh_app/data/models/activity.dart';
import 'package:doodh_app/data/repositories/activity_repository.dart';
import 'package:doodh_app/data/repositories/dairy_refs.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityType.parse', () {
    test('maps the wire strings the Cloud Function writes', () {
      // These strings are a contract with functions/index.js — a mismatch here
      // silently degrades every history row to "unknown".
      expect(
        ActivityType.parse('delivery_recorded'),
        ActivityType.deliveryRecorded,
      );
      expect(
        ActivityType.parse('delivery_edited'),
        ActivityType.deliveryEdited,
      );
      expect(
        ActivityType.parse('delivery_removed'),
        ActivityType.deliveryRemoved,
      );
      expect(ActivityType.parse('payment_logged'), ActivityType.paymentLogged);
      expect(
        ActivityType.parse('payment_approved'),
        ActivityType.paymentApproved,
      );
      expect(
        ActivityType.parse('customer_changed'),
        ActivityType.customerChanged,
      );
    });

    test('falls back to unknown rather than throwing', () {
      // A newer function version writing a type this build does not know must
      // degrade to one odd-looking row, never a crashed history screen.
      expect(ActivityType.parse('something_new'), ActivityType.unknown);
      expect(ActivityType.parse(null), ActivityType.unknown);
    });
  });

  group('Activity.fromDoc', () {
    late FakeFirebaseFirestore db;
    late DairyRefs refs;

    setUp(() {
      db = FakeFirebaseFirestore();
      refs = DairyRefs(db, 'main');
    });

    test('reads a recorded delivery', () async {
      await refs.activity.doc('a1').set({
        'type': 'delivery_recorded',
        'actorEmail': 'boy@doodh.local',
        'at': Timestamp.fromDate(DateTime(2026, 8, 18, 6, 30)),
        'customerId': 'c1',
        'customerName': 'Ram Kumar',
        'dayKey': '2026-08-18',
        'afterLitres': 2.0,
        'afterStatus': 'delivered',
      });

      final doc = await refs.activity.doc('a1').get();
      final activity = Activity.fromDoc(doc);

      expect(activity.type, ActivityType.deliveryRecorded);
      expect(activity.customerName, 'Ram Kumar');
      expect(activity.afterLitres, 2.0);
      expect(activity.isChange, isFalse);
    });

    test('an edit carries both the before and after values', () async {
      // The whole point of the history: showing what it was, not just what it
      // is now.
      await refs.activity.doc('a2').set({
        'type': 'delivery_edited',
        'actorEmail': 'owner@doodh.local',
        'at': Timestamp.fromDate(DateTime(2026, 8, 18, 20, 0)),
        'customerId': 'c1',
        'customerName': 'Ram Kumar',
        'dayKey': '2026-08-18',
        'beforeLitres': 2.0,
        'afterLitres': 3.0,
        'beforeStatus': 'delivered',
        'afterStatus': 'delivered',
        'reason': 'took extra',
      });

      final activity = Activity.fromDoc(await refs.activity.doc('a2').get());

      expect(activity.type, ActivityType.deliveryEdited);
      expect(activity.beforeLitres, 2.0);
      expect(activity.afterLitres, 3.0);
      expect(activity.reason, 'took extra');
      expect(activity.isChange, isTrue);
    });

    test('survives a document missing every optional field', () async {
      // Defensive: a partially-written entry must not crash the history screen.
      await refs.activity.doc('a3').set({'type': 'delivery_recorded'});

      final activity = Activity.fromDoc(await refs.activity.doc('a3').get());

      expect(activity.actorEmail, '');
      expect(activity.customerName, isNull);
      expect(activity.beforeLitres, isNull);
      expect(activity.at, isNotNull);
    });

    test('reads integer litres written by the function as doubles', () async {
      // JavaScript sends a whole number as an int; Dart must not choke on it.
      await refs.activity.doc('a4').set({
        'type': 'delivery_recorded',
        'afterLitres': 3,
        'amount': 500,
      });

      final activity = Activity.fromDoc(await refs.activity.doc('a4').get());

      expect(activity.afterLitres, 3.0);
      expect(activity.amount, 500.0);
    });
  });

  group('ActivityRepository', () {
    test('returns the newest entries first', () async {
      final db = FakeFirebaseFirestore();
      final refs = DairyRefs(db, 'main');

      for (final (id, hour) in [('old', 6), ('newest', 20), ('mid', 12)]) {
        await refs.activity.doc(id).set({
          'type': 'delivery_recorded',
          'actorEmail': 'boy@doodh.local',
          'at': Timestamp.fromDate(DateTime(2026, 8, 18, hour)),
        });
      }

      final entries = await ActivityRepository(refs).watchRecent().first;

      expect(entries.map((e) => e.id), ['newest', 'mid', 'old']);
    });

    test('filters to one customer', () async {
      final db = FakeFirebaseFirestore();
      final refs = DairyRefs(db, 'main');

      await refs.activity.doc('a1').set({
        'type': 'delivery_recorded',
        'customerId': 'c1',
        'at': Timestamp.fromDate(DateTime(2026, 8, 18, 6)),
      });
      await refs.activity.doc('a2').set({
        'type': 'delivery_recorded',
        'customerId': 'c2',
        'at': Timestamp.fromDate(DateTime(2026, 8, 18, 7)),
      });

      final entries = await ActivityRepository(
        refs,
      ).watchForCustomer('c1').first;

      expect(entries.length, 1);
      expect(entries.single.customerId, 'c1');
    });
  });
}
