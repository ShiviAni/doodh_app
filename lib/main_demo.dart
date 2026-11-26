import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injector.dart';
import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formats.dart';
import 'data/models/member.dart';
import 'demo/demo_seed.dart';
import 'features/auth/auth_service.dart';
import 'features/delivery/delivery_shell.dart';
import 'features/owner/owner_shell.dart';

/// Runs the whole app against seeded in-memory data.
///
///     flutter run -t lib/main_demo.dart
///
/// No Firebase project, no login, no internet. Everything is real app code —
/// the same screens, repositories and calculations — reading a fake Firestore
/// rather than a real one, so what you see here is what the built app does.
/// A role switcher replaces the login screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await DemoSeed.build();
  await setupInjector(
    firestore: db,
    auth: MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'demo-owner',
        email: DemoSeed.ownerEmail,
        displayName: 'Shivani',
      ),
    ),
  );

  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      initial: loadLanguage(),
      onChanged: saveLanguage,
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Doodh Hisab (demo)',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('hi'), Locale('en')],
          locale: LanguageScope.current(context) == AppLanguage.hindi
              ? const Locale('hi')
              : const Locale('en'),
          home: const RolePicker(),
        ),
      ),
    );
  }
}

/// Stands in for the login screen, so both sides can be seen without creating
/// two accounts.
class RolePicker extends StatelessWidget {
  const RolePicker({super.key});

  static Session _session(MemberRole role) => Session(
    email: role == MemberRole.owner
        ? DemoSeed.ownerEmail
        : DemoSeed.deliveryEmail,
    member: Member(
      email: role == MemberRole.owner
          ? DemoSeed.ownerEmail
          : DemoSeed.deliveryEmail,
      role: role,
      displayName: role == MemberRole.owner ? 'Shivani' : 'Ramesh',
    ),
  );

  void _open(BuildContext context, MemberRole role) {
    final session = _session(role);
    // No overlay button to switch back — it covered the progress counter. The
    // Android back button already pops this route and returns to the picker.
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => role == MemberRole.owner
              ? OwnerShell(session: session)
              : DeliveryShell(session: session),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sizes.gapLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.local_drink_outlined, size: 72),
                const SizedBox(height: Sizes.gap),
                Text(
                  s.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Demo · ${DemoSeed.houseCount} houses · '
                  '${Fmt.money(DemoSeed.ratePerLitre)}/litre',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Sizes.gapLarge * 1.5),
                FilledButton.icon(
                  icon: const Icon(Icons.delivery_dining, size: 30),
                  label: const Text('सप्लाई वाला  ·  Delivery'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.confirm,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _open(context, MemberRole.delivery),
                ),
                const SizedBox(height: Sizes.gap),
                FilledButton.icon(
                  icon: const Icon(Icons.admin_panel_settings, size: 30),
                  label: const Text('मालिक  ·  Owner'),
                  onPressed: () => _open(context, MemberRole.owner),
                ),
                const SizedBox(height: Sizes.gapLarge),
                OutlinedButton.icon(
                  icon: const Icon(Icons.translate),
                  label: Text(
                    s.lang == AppLanguage.hindi ? 'English' : 'हिन्दी',
                  ),
                  onPressed: () => LanguageScope.set(
                    context,
                    s.lang == AppLanguage.hindi
                        ? AppLanguage.english
                        : AppLanguage.hindi,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
