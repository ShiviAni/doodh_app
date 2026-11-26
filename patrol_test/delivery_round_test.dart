import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

void main() {
  patrolTest('shows the round in progress', ($) async {
    await openAsDelivery($);

    expect($('8/12'), findsOneWidget);
    expect($('4 houses left'), findsOneWidget);
  });

  patrolTest('recording a house moves the progress on', ($) async {
    await openAsDelivery($);

    await $('Anita Verma').scrollTo().tap();
    // The label carries the quantity: "Delivered  2 litre".
    await $(RegExp('^Delivered')).tap();
    await $.pumpAndSettle();

    expect($('9/12'), findsOneWidget);
    expect($('3 houses left'), findsOneWidget);
  });

  patrolTest('a house that took nothing still counts as done', ($) async {
    await openAsDelivery($);

    await $('Vijay Chauhan').scrollTo().tap();
    await $('Not taken today').tap();
    await $.pumpAndSettle();

    expect($('9/12'), findsOneWidget);
  });

  patrolTest('finishing every house shows the round as complete', ($) async {
    await openAsDelivery($);

    for (final name in [
      'Anita Verma',
      'Vijay Chauhan',
      'Pooja Rani',
      'Dinesh Patel',
    ]) {
      await $(name).scrollTo().tap();
      // The label carries the quantity: "Delivered  2 litre".
      await $(RegExp('^Delivered')).tap();
      await $.pumpAndSettle();
    }

    expect($('12/12'), findsOneWidget);
    expect($("Today's round is complete"), findsOneWidget);
  });

  patrolTest('search narrows the list to matching houses', ($) async {
    await openAsDelivery($);

    await $(Icons.search).tap();
    await $(TextField).enterText('Pooja');
    await $.pumpAndSettle();

    expect($('Pooja Rani'), findsOneWidget);
    expect($('Ram Kumar'), findsNothing);
  });

  patrolTest('cash taken at the door is logged without showing a balance', (
    $,
  ) async {
    await openAsDelivery($);

    await $('Ram Kumar').scrollTo().tap();
    await $('Money received').tap();
    await $('+₹500').tap();
    await $('+₹100').tap();
    expect($('₹600'), findsOneWidget);

    await $('Save').tap();
    await $.pumpAndSettle();

    expect($('Sent ✓'), findsOneWidget);
  });
}
