import 'package:doodh_app/core/l10n/strings.dart';
import 'package:doodh_app/core/theme/app_theme.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/features/delivery/delivery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

/// Wraps the card in the minimum context it needs: the language scope plus a
/// Material ancestor.
Widget _host(Widget child, {AppLanguage lang = AppLanguage.hindi}) =>
    LanguageScope(
      initial: lang,
      onChanged: (_) {},
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

/// The default 800x600 test surface is wider and shorter than any phone this
/// runs on. Sizing it like a real handset is what makes the "both buttons fit
/// without scrolling" expectations below meaningful.
void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {});
  testWidgets('pre-fills the customer usual quantity', (tester) async {
    // A normal day must be a single tap, so the stepper opens on the house's
    // usual amount rather than at zero.
    await tester.pumpWidget(
      _host(
        DeliveryCard(
          customer: customer(defaultQty: 2.5),
          existing: null,
          onRecord: (_, _) {},
        ),
      ),
    );

    expect(find.text('2.5'), findsOneWidget);
  });

  testWidgets('confirming reports the pre-filled quantity', (tester) async {
    _usePhoneScreen(tester);
    double? qty;
    DeliveryStatus? status;

    await tester.pumpWidget(
      _host(
        DeliveryCard(
          customer: customer(defaultQty: 2.0),
          existing: null,
          onRecord: (q, s) {
            qty = q;
            status = s;
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();

    expect(qty, 2.0);
    expect(status, DeliveryStatus.delivered);
  });

  testWidgets('stepper moves in half litres', (tester) async {
    _usePhoneScreen(tester);
    double? qty;

    await tester.pumpWidget(
      _host(
        DeliveryCard(
          customer: customer(defaultQty: 2.0),
          existing: null,
          onRecord: (q, _) => qty = q,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('2.5'), findsOneWidget);

    // Pump between taps: without a rebuild the second tap reads the stale
    // value and steps down from 2.5 again rather than from 2.0.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('1.5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pump();
    expect(qty, 1.5);
  });

  testWidgets('"not taken" reports zero litres and skipped status', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    double? qty;
    DeliveryStatus? status;

    await tester.pumpWidget(
      _host(
        DeliveryCard(
          customer: customer(defaultQty: 3.0),
          existing: null,
          onRecord: (q, s) {
            qty = q;
            status = s;
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.cancel_outlined));
    await tester.pump();

    // The usual quantity must not leak through when the house took nothing.
    expect(qty, 0);
    expect(status, DeliveryStatus.skipped);
  });

  testWidgets('re-opening a recorded house shows what was recorded', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryCard(
          customer: customer(defaultQty: 2.0),
          existing: delivery(qty: 1.5),
          onRecord: (_, _) {},
        ),
      ),
    );

    // Starts from the recorded 1.5, not the usual 2.0, so a correction begins
    // at the real value.
    expect(find.text('1.5'), findsWidgets);
  });

  testWidgets('every action pairs colour with an icon and a word', (
    tester,
  ) async {
    // Colour alone must never carry the meaning — the delivery person may be
    // colourblind, and the screen is often read in bright sun.
    await tester.pumpWidget(
      _host(
        DeliveryCard(customer: customer(), existing: null, onRecord: (_, _) {}),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    expect(find.textContaining('दे दिया'), findsOneWidget);
    expect(find.text('आज नहीं लिया'), findsOneWidget);
  });

  testWidgets('renders English when the language is English', (tester) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryCard(customer: customer(), existing: null, onRecord: (_, _) {}),
        lang: AppLanguage.english,
      ),
    );

    expect(find.textContaining('Delivered'), findsOneWidget);
    expect(find.text('Not taken today'), findsOneWidget);
  });

  testWidgets('both action buttons fit on a phone without scrolling', (
    tester,
  ) async {
    // "Not taken" is used every day. If it sits below the fold, it becomes a
    // button that gets skipped rather than pressed.
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryCard(customer: customer(), existing: null, onRecord: (_, _) {}),
      ),
    );

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    for (final icon in [Icons.check_circle, Icons.cancel_outlined]) {
      final rect = tester.getRect(find.byIcon(icon));
      expect(
        rect.bottom,
        lessThanOrEqualTo(screenHeight),
        reason: '$icon is below the fold',
      );
    }
  });

  testWidgets('primary confirm button is a large tap target', (tester) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryCard(customer: customer(), existing: null, onRecord: (_, _) {}),
      ),
    );

    final button = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.check_circle),
        matching: find.byType(FilledButton),
      ),
    );

    // Well beyond Material's 48dp minimum: a mistap here writes a wrong record.
    expect(button.height, greaterThanOrEqualTo(Sizes.primaryButton));
  });
}
