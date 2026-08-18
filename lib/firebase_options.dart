// PLACEHOLDER — replace by running:
//
//   flutterfire configure
//
// That command talks to your Firebase project and rewrites this whole file with
// real API keys. It is checked in as a stub only so the project compiles and
// `flutter analyze` runs before Firebase has been set up.
//
// The values below are intentionally invalid. Launching the app without
// configuring first throws the message in [_notConfigured] rather than failing
// somewhere deep inside the Firebase SDK.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError(_notConfigured);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        throw UnsupportedError(_notConfigured);
      default:
        throw UnsupportedError('Doodh Hisab targets Android and iOS only.');
    }
  }

  static const _notConfigured = '''
Firebase is not configured yet.

Run this once from the project root:

    dart pub global activate flutterfire_cli
    flutterfire configure

It will create the Firebase project link and overwrite
lib/firebase_options.dart with real credentials.
''';
}
