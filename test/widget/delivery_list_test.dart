import 'package:doodh_app/core/l10n/strings.dart';
import 'package:doodh_app/core/theme/app_theme.dart';
import 'package:doodh_app/data/models/customer.dart';
import 'package:doodh_app/data/models/delivery.dart';
import 'package:doodh_app/features/delivery/delivery_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/builders.dart';

void _usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget child, {AppLanguage lang = AppLanguage.hindi}) =>
    LanguageScope(
      initial: lang,
      onChanged: (_) {},
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  final customers = <Customer>[
    customer(id: 'c1', name: 'Ram Kumar', houseNo: '12', routeOrder: 1),
    customer(id: 'c2', name: 'Shyam Lal', houseNo: '14', routeOrder: 2),
    customer(id: 'c3', name: 'Sita Devi', houseNo: '15', routeOrder: 3),
  ];

  testWidgets('lists every house, recorded or not', (tester) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryListPage(
          customers: customers,
          recorded: const {},
          onTapCustomer: (_) {},
        ),
      ),
    );

    expect(find.text('Ram Kumar'), findsOneWidget);
    expect(find.text('Shyam Lal'), findsOneWidget);
    expect(find.text('Sita Devi'), findsOneWidget);
  });

  testWidgets('shows recorded litres, and skipped as "not taken"', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryListPage(
          customers: customers,
          recorded: {
            'c1': delivery(customerId: 'c1', qty: 2.5),
            'c2': delivery(customerId: 'c2', status: DeliveryStatus.skipped),
          },
          onTapCustomer: (_) {},
        ),
      ),
    );

    expect(find.text('2.5 ली'), findsOneWidget);
    expect(find.text('आज नहीं लिया'), findsOneWidget);
    // The untouched house advertises its usual amount rather than a status.
    expect(find.textContaining('रोज़ का'), findsOneWidget);
  });

  testWidgets('status icons distinguish done, skipped and pending', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    await tester.pumpWidget(
      _host(
        DeliveryListPage(
          customers: customers,
          recorded: {
            'c1': delivery(customerId: 'c1', qty: 2),
            'c2': delivery(customerId: 'c2', status: DeliveryStatus.skipped),
          },
          onTapCustomer: (_) {},
        ),
      ),
    );

    // Three visually distinct states, so the remaining work is findable
    // without reading a single word.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('tapping a row reports that customer', (tester) async {
    _usePhoneScreen(tester);
    Customer? tapped;

    await tester.pumpWidget(
      _host(
        DeliveryListPage(
          customers: customers,
          recorded: const {},
          onTapCustomer: (c) => tapped = c,
        ),
      ),
    );

    await tester.tap(find.text('Sita Devi'));
    await tester.pump();

    expect(tapped?.id, 'c3');
  });

  testWidgets('an already-recorded house can be tapped again to correct it', (
    tester,
  ) async {
    _usePhoneScreen(tester);
    Customer? tapped;

    await tester.pumpWidget(
      _host(
        DeliveryListPage(
          customers: customers,
          recorded: {'c1': delivery(customerId: 'c1', qty: 2)},
          onTapCustomer: (c) => tapped = c,
        ),
      ),
    );

    await tester.tap(find.text('Ram Kumar'));
    await tester.pump();

    expect(tapped?.id, 'c1');
  });

  group('search', () {
    testWidgets('filters by name', (tester) async {
      _usePhoneScreen(tester);
      await tester.pumpWidget(
        _host(
          DeliveryListPage(
            customers: customers,
            recorded: const {},
            onTapCustomer: (_) {},
            query: 'shyam',
          ),
        ),
      );

      expect(find.text('Shyam Lal'), findsOneWidget);
      expect(find.text('Ram Kumar'), findsNothing);
    });

    testWidgets('filters by house number', (tester) async {
      // He often knows the house number rather than the name.
      _usePhoneScreen(tester);
      await tester.pumpWidget(
        _host(
          DeliveryListPage(
            customers: customers,
            recorded: const {},
            onTapCustomer: (_) {},
            query: '15',
          ),
        ),
      );

      expect(find.text('Sita Devi'), findsOneWidget);
      expect(find.text('Ram Kumar'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      _usePhoneScreen(tester);
      await tester.pumpWidget(
        _host(
          DeliveryListPage(
            customers: customers,
            recorded: const {},
            onTapCustomer: (_) {},
            query: 'zzzz',
          ),
        ),
      );

      expect(find.text('कोई घर नहीं मिला'), findsOneWidget);
    });
  });
}
