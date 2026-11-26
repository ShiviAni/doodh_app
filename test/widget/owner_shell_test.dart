import 'package:doodh_app/core/di/injector.dart';
import 'package:doodh_app/core/l10n/strings.dart';
import 'package:doodh_app/core/theme/app_theme.dart';
import 'package:doodh_app/data/models/member.dart';
import 'package:doodh_app/demo/demo_seed.dart';
import 'package:doodh_app/features/auth/auth_service.dart';
import 'package:doodh_app/features/owner/customers_page.dart';
import 'package:doodh_app/features/owner/history_page.dart';
import 'package:doodh_app/features/owner/money_page.dart';
import 'package:doodh_app/features/owner/owner_shell.dart';
import 'package:doodh_app/features/owner/reports_page.dart';
import 'package:doodh_app/features/owner/settings_page.dart';
import 'package:doodh_app/features/owner/today_page.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The default 800x600 test surface is shorter than any phone; the owner
/// dashboard legitimately needs more vertical room than that.
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

  Widget host() => LanguageScope(
    initial: AppLanguage.english,
    onChanged: (_) {},
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const OwnerShell(
        session: Session(
          email: DemoSeed.ownerEmail,
          member: Member(
            email: DemoSeed.ownerEmail,
            role: MemberRole.owner,
            displayName: 'Owner',
          ),
        ),
      ),
    ),
  );

  testWidgets('every nav destination opens its own page', (tester) async {
    // Regression test. The History tab was once added to the page list but not
    // to the destination list, which silently shifted every later tab onto the
    // wrong page and left Settings unreachable entirely — with no analyzer
    // error and no crash to notice.
    _usePhoneScreen(tester);
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 100));

    final expectedPages = <Type>[
      TodayPage,
      HistoryPage,
      ReportsPage,
      CustomersPage,
      MoneyPage,
      SettingsPage,
    ];

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      bar.destinations.length,
      expectedPages.length,
      reason:
          'a page without a destination is unreachable, and shifts the '
          'tabs after it onto the wrong screens',
    );

    for (var i = 0; i < expectedPages.length; i++) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(expectedPages[i]),
        findsOneWidget,
        reason: 'tab $i should show ${expectedPages[i]}',
      );
    }
  });

  testWidgets('opens on the live Today view', (tester) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TodayPage), findsOneWidget);
  });
}
