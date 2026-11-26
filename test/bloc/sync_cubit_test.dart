import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:doodh_app/data/repositories/delivery_repository.dart';
import 'package:doodh_app/features/delivery/bloc/sync_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeliveryRepository extends Mock implements DeliveryRepository {}

void main() {
  late _MockDeliveryRepository repo;
  late StreamController<int> pending;

  setUp(() {
    repo = _MockDeliveryRepository();
    pending = StreamController<int>();
    when(
      () => repo.watchPendingCount('2026-08-18'),
    ).thenAnswer((_) => pending.stream);
  });

  tearDown(() => pending.close());

  SyncCubit build() => SyncCubit(deliveries: repo, dayKey: '2026-08-18');

  test('starts as all synced', () async {
    final cubit = build();
    expect(cubit.state, 0);
    await cubit.close();
  });

  blocTest<SyncCubit, int>(
    'follows the pending-write count as it rises and drains',
    build: build,
    act: (_) async {
      pending
        ..add(2)
        ..add(1)
        ..add(0);
    },
    expect: () => const [2, 1, 0],
  );

  test('stops listening once closed', () async {
    final cubit = build();
    await cubit.close();
    expect(pending.hasListener, isFalse);
  });
}
