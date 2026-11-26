import 'package:bloc_test/bloc_test.dart';
import 'package:doodh_app/data/models/customer.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/features/delivery/voice/bloc/voice_entry_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_speech_service.dart';

void main() {
  const ram = Customer(
    id: 'c1',
    name: 'Ram Kumar',
    nameHi: 'राम कुमार',
    houseNo: '12',
    defaultQtyLitres: 2,
    routeOrder: 1,
  );
  const shyam = Customer(
    id: 'c2',
    name: 'Shyam Lal',
    nameHi: 'श्याम लाल',
    houseNo: '14',
    defaultQtyLitres: 1.5,
    routeOrder: 2,
  );

  VoiceEntryBloc build(
    FakeSpeechService speech, {
    Customer? fixed,
    Duration timeout = const Duration(seconds: 9),
  }) => VoiceEntryBloc(
    speech: speech,
    customers: const [ram, shyam],
    localeId: 'hi_IN',
    fixedCustomer: fixed,
    firstWordTimeout: timeout,
  );

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    'a recognised phrase becomes a confirmable result',
    build: () => build(FakeSpeechService(transcript: 'राम कुमार ढाई लीटर')),
    act: (bloc) => bloc.add(const VoiceListenRequested()),
    expect: () => [
      const VoiceEntryState(),
      const VoiceEntryState(phase: VoicePhase.listening),
      isA<VoiceEntryState>()
          .having((s) => s.phase, 'phase', VoicePhase.heard)
          .having((s) => s.canConfirm, 'canConfirm', isTrue)
          .having(
            (s) => s.result,
            'result',
            const VoiceResult(
              customer: ram,
              qtyLitres: 2.5,
              status: DeliveryStatus.delivered,
            ),
          ),
    ],
  );

  test('passes the locale it was given to the recogniser', () async {
    // The sheet resolves the locale from a settled context; the bloc must
    // pass it through untouched.
    final speech = FakeSpeechService(transcript: 'x');
    final bloc = build(speech)..add(const VoiceListenRequested());
    await Future<void>.delayed(Duration.zero);
    expect(speech.listenCalled, isTrue);
    expect(speech.lastLocale, 'hi_IN');
    await bloc.close();
  });

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    'a name with no quantity cannot be confirmed',
    build: () => build(FakeSpeechService(transcript: 'राम कुमार')),
    act: (bloc) => bloc.add(const VoiceListenRequested()),
    verify: (bloc) {
      expect(bloc.state.entry?.hasCustomer, isTrue);
      expect(bloc.state.canConfirm, isFalse);
      expect(bloc.state.result, isNull);
    },
  );

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    'on a house card only the quantity is listened for',
    build: () => build(FakeSpeechService(transcript: 'ढाई लीटर'), fixed: shyam),
    act: (bloc) => bloc.add(const VoiceListenRequested()),
    verify: (bloc) {
      expect(bloc.state.result?.customer, shyam);
      expect(bloc.state.result?.qtyLitres, 2.5);
    },
  );

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    'a recogniser error ends in "heard nothing"',
    build: () => build(FakeSpeechService(error: 'no_match')),
    act: (bloc) => bloc.add(const VoiceListenRequested()),
    expect: () => [
      const VoiceEntryState(),
      const VoiceEntryState(phase: VoicePhase.listening),
      const VoiceEntryState(phase: VoicePhase.heardNothing),
    ],
  );

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    'no recogniser on the device says so instead of listening',
    build: () => build(FakeSpeechService(available: false)),
    act: (bloc) => bloc.add(const VoiceListenRequested()),
    expect: () => [
      const VoiceEntryState(),
      const VoiceEntryState(phase: VoicePhase.unavailable),
    ],
  );

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    'a silent recogniser gives up after the timeout',
    // A device with no speech service reports available and then never
    // answers. Without the watchdog the sheet would listen forever.
    build: () =>
        build(FakeSpeechService(), timeout: const Duration(milliseconds: 20)),
    act: (bloc) => bloc.add(const VoiceListenRequested()),
    wait: const Duration(milliseconds: 60),
    expect: () => [
      const VoiceEntryState(),
      const VoiceEntryState(phase: VoicePhase.listening),
      const VoiceEntryState(phase: VoicePhase.heardNothing),
    ],
  );

  blocTest<VoiceEntryBloc, VoiceEntryState>(
    '"again" starts a fresh attempt',
    build: () => build(FakeSpeechService(transcript: 'राम कुमार दो लीटर')),
    act: (bloc) => bloc
      ..add(const VoiceListenRequested())
      ..add(const VoiceListenRequested()),
    verify: (bloc) {
      expect(bloc.state.phase, VoicePhase.heard);
      expect(bloc.state.result?.qtyLitres, 2);
    },
  );
}
