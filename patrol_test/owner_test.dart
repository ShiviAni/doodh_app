import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

void main() {
  patrolTest('every owner tab opens', ($) async {
    await openAsOwner($);

    for (final tab in [
      'History',
      'Reports',
      'Customers',
      'Money',
      'Settings',
      'Today',
    ]) {
      await $(NavigationBar).$(tab).tap();
      await $.pumpAndSettle();
      expect($(ErrorWidget), findsNothing, reason: '$tab tab failed to build');
    }
  });

  patrolTest('adding a customer puts them in the list', ($) async {
    await openAsOwner($);
    await $(NavigationBar).$('Customers').tap();

    await $('Add customer').tap();
    await $(TextField).containing('Customer name').enterText('Test House');
    await $('Save').tap();
    await $.pumpAndSettle();

    await $('Test House').scrollTo();
    expect($('Test House'), findsOneWidget);
  });

  patrolTest('approving doorstep cash clears it from the queue', ($) async {
    await openAsOwner($);
    await $(NavigationBar).$('Money').tap();

    expect($(RegExp('^Pending approvals')), findsOneWidget);
    await $(IconButton).which<IconButton>((b) => b.tooltip == 'Approve').tap();
    await $.pumpAndSettle();

    expect($(RegExp('^Pending approvals')), findsNothing);
  });
}
