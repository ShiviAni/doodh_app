import 'package:doodh_app/core/l10n/strings.dart';
import 'package:doodh_app/main_demo.dart';
import 'package:patrol/patrol.dart';

/// Starts the demo app (seeded fake Firestore, no Firebase project) in
/// English and waits for the role picker.
///
/// The demo seed puts today's round at 8 of 12 houses done. Anita Verma,
/// Vijay Chauhan, Pooja Rani and Dinesh Patel are still to do.
Future<void> launchDemo(PatrolIntegrationTester $) async {
  await bootstrapDemo(language: AppLanguage.english);
  await $.pumpWidgetAndSettle(const DemoApp());
}

Future<void> openAsDelivery(PatrolIntegrationTester $) async {
  await launchDemo($);
  await $('सप्लाई वाला  ·  Delivery').tap();
  await $.pumpAndSettle();
}

Future<void> openAsOwner(PatrolIntegrationTester $) async {
  await launchDemo($);
  await $('मालिक  ·  Owner').tap();
  await $.pumpAndSettle();
}
