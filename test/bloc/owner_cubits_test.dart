import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:doodh_app/core/utils/formats.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/data/models/member.dart';
import 'package:doodh_app/data/models/payment.dart';
import 'package:doodh_app/data/repositories/activity_repository.dart';
import 'package:doodh_app/data/repositories/customer_repository.dart';
import 'package:doodh_app/data/repositories/dairy_refs.dart';
import 'package:doodh_app/data/repositories/delivery_repository.dart';
import 'package:doodh_app/data/repositories/member_repository.dart';
import 'package:doodh_app/data/repositories/payment_repository.dart';
import 'package:doodh_app/data/repositories/settings_repository.dart';
import 'package:doodh_app/features/auth/auth_service.dart';
import 'package:doodh_app/features/notifications/push_service.dart';
import 'package:doodh_app/features/owner/bloc/customers_cubit.dart';
import 'package:doodh_app/features/owner/bloc/history_cubit.dart';
import 'package:doodh_app/features/owner/bloc/money_cubit.dart';
import 'package:doodh_app/features/owner/bloc/reports_cubit.dart';
import 'package:doodh_app/features/owner/bloc/settings_cubit.dart';
import 'package:doodh_app/features/owner/bloc/today_cubit.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/builders.dart';

class _MockPushService extends Mock implements PushService {}

class _MockAuthService extends Mock implements AuthService {}

const _owner = 'owner@doodh.local';

/// Lets every Firestore listener deliver its next snapshot.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeFirebaseFirestore db;
  late DairyRefs refs;

  final day = DateTime(2026, 8, 18);
  final dayKey = DateKeys.day(day);

  setUp(() async {
    db = FakeFirebaseFirestore();
    refs = DairyRefs(db, 'main');
    await refs.billingSettings.set({'ratePerLitre': 70});
    for (final c in [
      customer(id: 'c1', name: 'Ram', routeOrder: 1),
      customer(id: 'c2', name: 'Shyam', routeOrder: 2),
      customer(id: 'c3', name: 'Gone', routeOrder: 3, active: false),
    ]) {
      await refs.customers.doc(c.id).set(c.toMap());
    }
  });

  Future<void> seedDelivery(Delivery d) =>
      refs.deliveries.doc(d.id).set(d.toMap());

  group('TodayCubit', () {
    TodayCubit build() => TodayCubit(
      settings: SettingsRepository(refs),
      customers: CustomerRepository(refs),
      deliveries: DeliveryRepository(refs),
      editorEmail: _owner,
      now: day,
    );

    test('summarises today against the stored rate', () async {
      await seedDelivery(delivery(customerId: 'c1', dayKey: dayKey, qty: 2));
      final cubit = build();
      await settle();

      expect(cubit.state.rate, 70);
      expect(cubit.state.customers.map((c) => c.id), ['c1', 'c2']);
      expect(cubit.state.summary.litres, 2);
      expect(cubit.state.summary.amount, 140);
      expect(cubit.state.summary.pendingCount, 1);
      await cubit.close();
    });

    test('filling a blank house is an original entry, not an edit', () async {
      final cubit = build();
      await settle();
      cubit.saveEntry(
        customer: customer(id: 'c2'),
        existing: null,
        qtyLitres: 1.5,
        status: DeliveryStatus.delivered,
        reason: 'ignored',
      );
      await settle();

      final doc = await refs.deliveries.doc('${dayKey}_c2').get();
      expect(doc.data()!['qtyLitres'], 1.5);
      expect(doc.data()!['recordedBy'], _owner);
      expect(doc.data()!['editedBy'], isNull);
      expect(doc.data()!['editReason'], isNull);
      await cubit.close();
    });

    test('changing an entry keeps who recorded it and says why', () async {
      final original = delivery(customerId: 'c1', dayKey: dayKey);
      await seedDelivery(original);
      final cubit = build();
      await settle();
      cubit.saveEntry(
        customer: customer(id: 'c1'),
        existing: original,
        qtyLitres: 3,
        status: DeliveryStatus.delivered,
        reason: '  extra for guests  ',
      );
      await settle();

      final doc = await refs.deliveries.doc('${dayKey}_c1').get();
      expect(doc.data()!['recordedBy'], 'boy@doodh.local');
      expect(doc.data()!['editedBy'], _owner);
      expect(doc.data()!['editReason'], 'extra for guests');
      await cubit.close();
    });

    test('a correction with no reason is still marked as one', () async {
      final original = delivery(customerId: 'c1', dayKey: dayKey);
      await seedDelivery(original);
      final cubit = build();
      await settle();
      cubit.saveEntry(
        customer: customer(id: 'c1'),
        existing: original,
        qtyLitres: 0,
        status: DeliveryStatus.skipped,
      );
      await settle();

      final doc = await refs.deliveries.doc('${dayKey}_c1').get();
      expect(doc.data()!['editReason'], '—');
      await cubit.close();
    });
  });

  group('CustomersCubit', () {
    CustomersCubit build() =>
        CustomersCubit(customers: CustomerRepository(refs));

    test('lists every house, active or not', () async {
      final cubit = build();
      expect(cubit.state.loaded, isFalse);
      await settle();
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.customers.length, 3);
      await cubit.close();
    });

    test('a draft with no id is added as a new house', () async {
      final cubit = build();
      await settle();
      cubit.save(customer(id: '', name: 'Sita'));
      await settle();

      expect(cubit.state.customers.map((c) => c.name), contains('Sita'));
      expect((await refs.customers.get()).docs.length, 4);
      await cubit.close();
    });

    test('a draft with an id updates that house in place', () async {
      final cubit = build();
      await settle();
      cubit.save(customer(id: 'c1', name: 'Ram Kumar', defaultQty: 3));
      await settle();

      final doc = await refs.customers.doc('c1').get();
      expect(doc.data()!['name'], 'Ram Kumar');
      expect((await refs.customers.get()).docs.length, 3);
      await cubit.close();
    });

    test('a nameless draft is not saved', () async {
      final cubit = build();
      await settle();
      cubit.save(customer(id: '', name: '   '));
      await settle();
      expect((await refs.customers.get()).docs.length, 3);
      await cubit.close();
    });
  });

  group('HistoryCubit', () {
    Future<void> seedActivity(String id, DateTime at) =>
        refs.activity.doc(id).set({
          'type': 'deliveryRecorded',
          'actorEmail': 'boy@doodh.local',
          'at': Timestamp.fromDate(at),
        });

    test('groups activity by day, newest day first', () async {
      await seedActivity('a1', DateTime(2026, 8, 17, 7));
      await seedActivity('a2', DateTime(2026, 8, 18, 7));
      await seedActivity('a3', DateTime(2026, 8, 18, 8));

      final cubit = HistoryCubit(activity: ActivityRepository(refs));
      await settle();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.byDay.keys, ['2026-08-18', '2026-08-17']);
      expect(cubit.state.byDay['2026-08-18']!.map((a) => a.id), ['a3', 'a2']);
      await cubit.close();
    });

    test('an empty log is loaded and empty, not loading', () async {
      final cubit = HistoryCubit(activity: ActivityRepository(refs));
      await settle();
      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.isEmpty, isTrue);
      await cubit.close();
    });
  });

  group('SettingsCubit', () {
    late _MockPushService push;
    late _MockAuthService auth;

    setUp(() {
      push = _MockPushService();
      auth = _MockAuthService();
      when(() => push.unregister()).thenAnswer((_) async {});
      when(() => auth.signOut()).thenAnswer((_) async {});
    });

    SettingsCubit build() => SettingsCubit(
      settings: SettingsRepository(refs),
      members: MemberRepository(refs),
      push: push,
      auth: auth,
    );

    test('loads the stored rate and marks it loaded', () async {
      final cubit = build();
      expect(cubit.state.rateLoaded, isFalse);
      await settle();
      expect(cubit.state.rate, 70);
      expect(cubit.state.rateLoaded, isTrue);
      await cubit.close();
    });

    for (final bad in ['', 'abc', '0', '-5', 'NaN', 'Infinity']) {
      test('ignores a rate of "$bad"', () async {
        final cubit = build();
        await settle();
        cubit.setRate(bad);
        await settle();
        expect(cubit.state.rate, 70);
        await cubit.close();
      });
    }

    test('saves a valid rate', () async {
      final cubit = build();
      await settle();
      cubit.setRate(' 65.5 ');
      await settle();
      expect(cubit.state.rate, 65.5);
      await cubit.close();
    });

    test('adds a member under the lowercased email', () async {
      final cubit = build();
      await settle();
      cubit.addMember(
        email: '  Boy@Doodh.Local ',
        name: '',
        role: MemberRole.delivery,
      );
      await settle();

      final m = cubit.state.members.single;
      expect(m.email, 'boy@doodh.local');
      // A blank name falls back to the email, so the list never shows a gap.
      expect(m.displayName, 'boy@doodh.local');
      await cubit.close();
    });

    test('refuses an implausible email', () async {
      final cubit = build();
      await settle();
      cubit.addMember(email: 'not-an-email', name: 'X', role: MemberRole.owner);
      await settle();
      expect(cubit.state.members, isEmpty);
      await cubit.close();
    });

    blocTest<SettingsCubit, SettingsState>(
      'sign-out drops the push token before signing out',
      build: build,
      act: (cubit) => cubit.signOut(),
      verify: (_) =>
          verifyInOrder([() => push.unregister(), () => auth.signOut()]),
    );
  });

  group('ReportsCubit', () {
    ReportsCubit build() => ReportsCubit(
      settings: SettingsRepository(refs),
      customers: CustomerRepository(refs),
      deliveries: DeliveryRepository(refs),
      now: day,
    );

    setUp(() async {
      await seedDelivery(delivery(customerId: 'c1', dayKey: '2026-08-01'));
      await seedDelivery(delivery(customerId: 'c1', dayKey: '2026-08-18'));
      await seedDelivery(
        delivery(customerId: 'c2', dayKey: '2026-08-18', qty: 1),
      );
      await seedDelivery(delivery(customerId: 'c1', dayKey: '2026-07-31'));
    });

    test('defaults to the current month', () async {
      final cubit = build();
      expect(cubit.state.loading, isTrue);
      await settle();

      expect(cubit.state.period, ReportPeriod.month);
      expect(cubit.state.dayCount, 31);
      expect(cubit.state.summary.litres, 5);
      expect(cubit.state.summary.amount, 350);
      expect(cubit.state.litresByCustomer, {'c1': 4, 'c2': 1});
      await cubit.close();
    });

    test('switching to one day narrows the range', () async {
      final cubit = build();
      await settle();
      cubit.selectPeriod(ReportPeriod.day);
      await settle();

      expect(cubit.state.dayCount, 1);
      expect(cubit.state.summary.litres, 3);
      await cubit.close();
    });

    test('stepping back a month reads that month', () async {
      final cubit = build();
      await settle();
      cubit.shift(-1);
      await settle();

      expect(cubit.state.range.$1, DateTime(2026, 7));
      expect(cubit.state.summary.litres, 2);
      await cubit.close();
    });

    test('CSV has a header and one row per customer', () async {
      final cubit = build();
      await settle();
      final lines = cubit.state.toCsv().split(RegExp(r'\r?\n'));

      expect(lines.first, 'Customer,House no,Litres,Rate,Amount');
      expect(lines.length, 1 + 3);
      expect(lines[1], startsWith('Ram,12,4'));
      await cubit.close();
    });
  });

  group('MoneyCubit', () {
    MoneyCubit build() => MoneyCubit(
      settings: SettingsRepository(refs),
      customers: CustomerRepository(refs),
      payments: PaymentRepository(refs),
      deliveries: DeliveryRepository(refs),
      ownerEmail: _owner,
      now: day,
    );

    Future<void> seedPayment(Payment p) =>
        refs.payments.doc(p.id).set(p.toMap());

    setUp(() async {
      await seedDelivery(
        delivery(customerId: 'c1', dayKey: '2026-08-01', qty: 10),
      );
      await seedPayment(
        payment(id: 'p1', customerId: 'c1', amount: 300, dayKey: '2026-08-05'),
      );
      await seedPayment(
        payment(
          id: 'p2',
          customerId: 'c1',
          amount: 200,
          dayKey: '2026-08-18',
          approved: false,
        ),
      );
    });

    test('bills the month and counts only approved payments', () async {
      final cubit = build();
      await settle();

      expect(cubit.state.bills['c1']!.amount, 700);
      expect(cubit.state.billed, 700);
      expect(cubit.state.collected, 300);
      expect(cubit.state.balance, 400);
      expect(cubit.state.pending.map((p) => p.id), ['p2']);
      expect(cubit.state.activeCustomers.map((c) => c.id), ['c1', 'c2']);
      await cubit.close();
    });

    test('approving doorstep cash makes it count', () async {
      final cubit = build();
      await settle();
      cubit.approve('p2');
      await settle();

      expect(cubit.state.pending, isEmpty);
      expect(cubit.state.collected, 500);
      final doc = await refs.payments.doc('p2').get();
      expect(doc.data()!['approvedBy'], _owner);
      await cubit.close();
    });

    test('rejecting doorstep cash removes it from the queue', () async {
      final cubit = build();
      await settle();
      cubit.reject('p2');
      await settle();

      expect(cubit.state.pending, isEmpty);
      expect(cubit.state.collected, 300);
      await cubit.close();
    });

    test('an owner-recorded payment lands approved', () async {
      final cubit = build();
      await settle();
      cubit.recordPayment(
        customerId: 'c2',
        amount: '150',
        method: PaymentMethod.upi,
        now: day,
      );
      await settle();

      final mine = cubit.state.payments.where((p) => p.customerId == 'c2');
      expect(mine.single.approved, isTrue);
      expect(mine.single.approvedBy, _owner);
      expect(mine.single.method, PaymentMethod.upi);
      await cubit.close();
    });

    test('a non-positive amount records nothing', () async {
      final cubit = build();
      await settle();
      cubit.recordPayment(
        customerId: 'c2',
        amount: '0',
        method: PaymentMethod.cash,
      );
      await settle();
      expect(cubit.state.payments.length, 2);
      await cubit.close();
    });

    test('changing month never bills last month under the new label', () async {
      final cubit = build();
      await settle();
      cubit.shiftMonth(-1);

      // Straight after the shift, before July's snapshot arrives.
      expect(cubit.state.monthKey, '2026-07');
      expect(cubit.state.deliveries, isEmpty);

      await settle();
      expect(cubit.state.bills['c1']!.amount, 0);
      await cubit.close();
    });
  });
}
