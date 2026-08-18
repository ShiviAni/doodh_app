import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Kept separate from `main.dart` so tests can boot the widget tree without
/// touching Firebase at all.
Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
