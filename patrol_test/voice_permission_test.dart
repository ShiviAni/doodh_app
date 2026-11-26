import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

/// The microphone is the one place the app meets a native dialog, so it is
/// the part a widget test cannot cover.
void main() {
  patrolTest(
    'denying the microphone falls back to the buttons, not a dead sheet',
    ($) async {
      await openAsDelivery($);
      await $(Icons.mic).tap();

      if (await $.platform.mobile.isPermissionDialogVisible(
        timeout: const Duration(seconds: 5),
      )) {
        await $.platform.mobile.denyPermission();
      }
      await $.pumpAndSettle();

      // Either the recogniser reports itself unavailable, or it never
      // answers and the watchdog gives up. Both must point at the buttons.
      final unavailable = $(
        'Microphone is not working.\nUse the buttons instead.',
      );
      final heardNothing = $('Nothing was heard');
      try {
        await unavailable.waitUntilVisible(
          timeout: const Duration(seconds: 12),
        );
      } on WaitUntilVisibleTimeoutException {
        await heardNothing.waitUntilVisible();
      }

      await $('Cancel').tap();
      expect($('8/12'), findsOneWidget);
    },
  );
}
