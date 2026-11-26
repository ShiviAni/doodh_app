import 'package:doodh_app/core/di/injector.dart';
import 'package:doodh_app/core/l10n/strings.dart';
import 'package:doodh_app/core/theme/app_theme.dart';
import 'package:doodh_app/demo/demo_seed.dart';
import 'package:doodh_app/features/owner/customers_page.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await sl.reset();
    await setupInjector(
      firestore: await DemoSeed.build(),
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u', email: DemoSeed.ownerEmail),
      ),
    );
  });

  tearDown(sl.reset);

  Widget host(AppLanguage lang) => LanguageScope(
    initial: lang,
    onChanged: (_) {},
    child: MaterialApp(theme: AppTheme.light(), home: const CustomersPage()),
  );

  Future<void> openAddForm(WidgetTester tester, AppLanguage lang) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(host(lang));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('English mode shows the Hindi-name field label in English', (
    tester,
  ) async {
    await openAddForm(tester, AppLanguage.english);

    expect(find.widgetWithText(TextField, 'Name (Hindi)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Customer name'), findsOneWidget);
    expect(find.textContaining('नाम'), findsNothing);
  });

  testWidgets('Hindi mode keeps the Hindi label', (tester) async {
    await openAddForm(tester, AppLanguage.hindi);

    expect(find.widgetWithText(TextField, 'नाम (हिन्दी)'), findsOneWidget);
    expect(find.text('Name (Hindi)'), findsNothing);
  });

  testWidgets('label follows a language change while the form is open', (
    tester,
  ) async {
    await openAddForm(tester, AppLanguage.hindi);
    expect(find.widgetWithText(TextField, 'नाम (हिन्दी)'), findsOneWidget);

    LanguageScope.set(
      tester.element(find.byType(CustomersPage)),
      AppLanguage.english,
    );
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Name (Hindi)'), findsOneWidget);
    expect(find.textContaining('नाम'), findsNothing);
  });

  testWidgets('Save enables as soon as a name is typed', (tester) async {
    // Regression: the button only re-checked the name on an unrelated
    // rebuild, so typing a new house's name left Save disabled.
    await openAddForm(tester, AppLanguage.english);

    FilledButton save() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Save'), matching: find.byType(FilledButton)),
    );
    expect(save().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Customer name'),
      'Sita',
    );
    await tester.pump();

    expect(save().onPressed, isNotNull);
  });
}
