import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injector.dart';
import 'core/l10n/strings.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/delivery/delivery_shell.dart';
import 'features/owner/owner_shell.dart';
import 'firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  await setupInjector();
  runApp(const DoodhApp());
}

class DoodhApp extends StatelessWidget {
  const DoodhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      initial: loadLanguage(),
      onChanged: saveLanguage,
      child: Builder(
        builder: (context) => MaterialApp(
          title: S.of(context).appName,
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
          home: const _RootGate(),
        ),
      ),
    );
  }
}

/// Decides which app the user gets.
///
/// One APK serves both roles; the role comes from the member document, and the
/// security rules enforce the same split server-side. Hiding the owner screens
/// is a convenience — the rules are what actually protect the money.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session?>(
      stream: sl<AuthService>().watchSession(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snap.data;
        if (session == null) return const LoginPage();
        if (!session.hasAccess) return _NoAccessPage(email: session.email);

        return session.isOwner
            ? OwnerShell(session: session)
            : DeliveryShell(session: session);
      },
    );
  }
}

/// Signed in to Firebase, but not listed as a member of this dairy.
class _NoAccessPage extends StatelessWidget {
  const _NoAccessPage({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gapLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 72),
              const SizedBox(height: Sizes.gap),
              Text(
                s.noAccessTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Sizes.gap),
              Text(s.noAccessBody, textAlign: TextAlign.center),
              const SizedBox(height: Sizes.gap),
              Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: Sizes.gapLarge),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(s.logout),
                onPressed: () => sl<AuthService>().signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
