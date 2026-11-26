import 'package:bloc_test/bloc_test.dart';
import 'package:doodh_app/data/repositories/dairy_refs.dart';
import 'package:doodh_app/data/repositories/payment_repository.dart';
import 'package:doodh_app/features/delivery/bloc/cash_log_cubit.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  CashLogCubit build() => CashLogCubit(
    payments: PaymentRepository(DairyRefs(db, 'main')),
    customerId: 'c1',
    dayKey: '2026-08-18',
    recordedBy: 'boy@doodh.local',
  );

  blocTest<CashLogCubit, CashLogState>(
    'tapping notes adds them up, the way counting notes does',
    build: build,
    act: (cubit) => cubit
      ..addNote(500)
      ..addNote(100)
      ..addNote(20),
    expect: () => const [
      CashLogState(amount: 500),
      CashLogState(amount: 600),
      CashLogState(amount: 620),
    ],
  );

  blocTest<CashLogCubit, CashLogState>(
    'clear starts over',
    build: build,
    seed: () => const CashLogState(amount: 300),
    act: (cubit) => cubit.clear(),
    expect: () => const [CashLogState()],
  );

  blocTest<CashLogCubit, CashLogState>(
    'nothing is submitted for a zero amount',
    build: build,
    act: (cubit) => cubit.submit(),
    expect: () => const <CashLogState>[],
    verify: (_) async {
      final snap = await db.collection('dairies/main/payments').get();
      expect(snap.docs, isEmpty);
    },
  );

  blocTest<CashLogCubit, CashLogState>(
    'submit writes an unapproved cash payment',
    // Only the owner's approval makes it count against the bill.
    build: build,
    seed: () => const CashLogState(amount: 200),
    act: (cubit) => cubit.submit(),
    expect: () => const [CashLogState(amount: 200, submitted: true)],
    verify: (_) async {
      final snap = await db.collection('dairies/main/payments').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.single.data();
      expect(data['amount'], 200);
      expect(data['customerId'], 'c1');
      expect(data['method'], 'cash');
      expect(data['approved'], isFalse);
      expect(data['recordedBy'], 'boy@doodh.local');
    },
  );

  blocTest<CashLogCubit, CashLogState>(
    'a second tap on save does not write twice',
    build: build,
    seed: () => const CashLogState(amount: 200),
    act: (cubit) => cubit
      ..submit()
      ..submit(),
    verify: (_) async {
      final snap = await db.collection('dairies/main/payments').get();
      expect(snap.docs.length, 1);
    },
  );
}
