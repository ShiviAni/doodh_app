import 'package:doodh_app/core/l10n/strings.dart';
import 'package:doodh_app/core/theme/app_theme.dart';
import 'package:doodh_app/data/models/customer.dart';
import 'package:doodh_app/features/delivery/voice/speech_service.dart';
import 'package:doodh_app/features/delivery/voice/voice_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scriptable stand-in for the platform recogniser.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.available = true, this.transcript, this.error});

  final bool available;

  /// Delivered as a final result when listening starts. Null means the
  /// recogniser never answers — the case a real device with no speech service
  /// produces.
  final String? transcript;
  final String? error;

  bool listenCalled = false;
  String? lastLocale;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => false;

  @override
  Future<bool> initialise() async => available;

  @override
  Future<void> listen({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(String message)? onError,
    String localeId = 'hi_IN',
  }) async {
    listenCalled = true;
    lastLocale = localeId;
    if (error != null) {
      onError?.call(error!);
      return;
    }
    if (transcript != null) onResult(transcript!, true);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // Hindi spellings matter here: the recogniser returns Devanagari, so a
  // customer with only a Latin name would never be matched.
  const customers = <Customer>[
    Customer(
      id: 'c1',
      name: 'Ram Kumar',
      nameHi: 'राम कुमार',
      houseNo: '12',
      defaultQtyLitres: 2,
      routeOrder: 1,
    ),
    Customer(
      id: 'c2',
      name: 'Shyam Lal',
      nameHi: 'श्याम लाल',
      houseNo: '14',
      defaultQtyLitres: 1.5,
      routeOrder: 2,
    ),
  ];

  /// Opens the sheet the way the app does — through `show`, so the locale is
  /// resolved from a real context.
  Future<void> openSheet(
    WidgetTester tester,
    FakeSpeechService speech, {
    AppLanguage lang = AppLanguage.hindi,
  }) async {
    await tester.pumpWidget(
      LanguageScope(
        initial: lang,
        onChanged: (_) {},
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => VoiceEntrySheet.show(
                    context,
                    customers: customers,
                    speech: speech,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('opening the sheet starts listening', (tester) async {
    // Regression test. Listening is kicked off from initState, and the sheet
    // used to read the language from an InheritedWidget there — which is
    // illegal and threw before listen() was ever reached. The sheet still
    // rendered "speak now", so the microphone appeared broken on every
    // device with no error shown.
    _usePhoneScreen(tester);
    final speech = FakeSpeechService();

    await openSheet(tester, speech);

    expect(tester.takeException(), isNull);
    expect(
      speech.listenCalled,
      isTrue,
      reason: 'the sheet must actually open the microphone',
    );
  });

  testWidgets('passes the Hindi locale when the UI is Hindi', (tester) async {
    _usePhoneScreen(tester);
    final speech = FakeSpeechService();

    await openSheet(tester, speech, lang: AppLanguage.hindi);

    expect(speech.lastLocale, 'hi_IN');
  });

  testWidgets('passes the English locale when the UI is English', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    final speech = FakeSpeechService();

    await openSheet(tester, speech, lang: AppLanguage.english);

    expect(speech.lastLocale, 'en_IN');
  });

  testWidgets('a recognised phrase is played back for confirmation', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    final speech = FakeSpeechService(transcript: 'राम कुमार ढाई लीटर');

    await openSheet(tester, speech);

    expect(find.text('राम कुमार ढाई लीटर'), findsOneWidget);
    // Played back as the house plus the amount, for him to confirm.
    expect(find.text('राम कुमार'), findsOneWidget);
    expect(find.textContaining('2.5'), findsWidgets);
  });

  testWidgets('save stays disabled until a house and amount are both known', (
    tester,
  ) async {
    // A half-understood phrase must never be savable: a wrong house is a
    // wrong bill at the end of the month.
    _usePhoneScreen(tester);
    final speech = FakeSpeechService(transcript: 'दो लीटर');

    await openSheet(tester, speech);

    final save = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byIcon(Icons.check_circle),
        matching: find.byType(FilledButton),
      ),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('a recogniser error surfaces guidance rather than hanging', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    final speech = FakeSpeechService(error: 'error_no_match');

    await openSheet(tester, speech);

    expect(find.text('कुछ सुनाई नहीं दिया'), findsOneWidget);
  });

  testWidgets('an unavailable recogniser says so instead of listening', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    final speech = FakeSpeechService(available: false);

    await openSheet(tester, speech);

    expect(speech.listenCalled, isFalse);
    expect(find.textContaining('माइक'), findsOneWidget);
  });

  testWidgets('a silent recogniser gives up instead of listening forever', (
    tester,
  ) async {
    // The device claims a recogniser exists but never answers. Without the
    // watchdog the sheet would show "speak now" indefinitely.
    _usePhoneScreen(tester);
    final speech = FakeSpeechService(transcript: null);

    await openSheet(tester, speech);
    expect(find.text('बोलिए…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('कुछ सुनाई नहीं दिया'), findsOneWidget);
  });
}
