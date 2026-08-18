import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/dairy_refs.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../features/auth/auth_service.dart';
import '../../features/delivery/voice/speech_service.dart';
import '../../features/notifications/push_service.dart';
import '../l10n/strings.dart';

final sl = GetIt.instance;

/// Single dairy per install. Kept as a constant rather than a lookup because
/// this app serves one business; multi-tenancy would change the routing, not
/// just this string.
const kDairyId = 'main';

Future<void> setupInjector({
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;

  // Offline-first. Firestore keeps the pending write queue on disk, so entries
  // recorded with no signal survive an app kill and replay on reconnect —
  // which is the whole reason the round can be walked offline.
  //
  // The in-memory fake used by the demo entrypoint and the tests has no
  // settings to configure, and is already entirely local.
  try {
    db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } on UnimplementedError {
    // Fake Firestore — nothing to configure.
  } on NoSuchMethodError {
    // Fake Firestore — nothing to configure.
  }

  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  final refs = DairyRefs(db, kDairyId);
  sl.registerSingleton<DairyRefs>(refs);
  sl.registerSingleton<CustomerRepository>(CustomerRepository(refs));
  sl.registerSingleton<DeliveryRepository>(DeliveryRepository(refs));
  sl.registerSingleton<PaymentRepository>(PaymentRepository(refs));
  sl.registerSingleton<SettingsRepository>(SettingsRepository(refs));
  sl.registerSingleton<MemberRepository>(MemberRepository(refs));
  sl.registerSingleton<ActivityRepository>(ActivityRepository(refs));
  sl.registerSingleton<ReportCalculator>(const ReportCalculator());
  sl.registerSingleton<PushService>(PushService(refs));
  // Single instance: initialising the recogniser is slow, so it is warmed once
  // and reused for every mic tap.
  sl.registerSingleton<SpeechService>(DeviceSpeechService());
  sl.registerSingleton<AuthService>(
    AuthService(auth ?? FirebaseAuth.instance, sl<MemberRepository>()),
  );
}

const _langKey = 'ui_language';

AppLanguage loadLanguage() =>
    sl<SharedPreferences>().getString(_langKey) == 'en'
    ? AppLanguage.english
    : AppLanguage.hindi;

Future<void> saveLanguage(AppLanguage lang) => sl<SharedPreferences>()
    .setString(_langKey, lang == AppLanguage.english ? 'en' : 'hi');
