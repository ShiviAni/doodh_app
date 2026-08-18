import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../auth/auth_service.dart';
import '../notifications/push_service.dart';
import 'customers_page.dart';
import 'history_page.dart';
import 'money_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'today_page.dart';

/// The owner's app: five tabs, all read-write, all money-aware.
///
/// The delivery role never reaches this widget — but that is convenience, not
/// security. The Firestore rules deny the underlying reads outright, so an
/// altered build gets nothing.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key, required this.session});

  final Session session;

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Owner devices only. Registering a delivery phone here would put it in the
    // owner-token list and send it notifications about its own work.
    sl<PushService>().startForOwner();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pages = [
      const TodayPage(),
      const HistoryPage(),
      const ReportsPage(),
      const CustomersPage(),
      MoneyPage(session: widget.session),
      SettingsPage(session: widget.session),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: s.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: s.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: s.tabReports,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: s.tabCustomers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.currency_rupee_outlined),
            selectedIcon: const Icon(Icons.currency_rupee),
            label: s.tabMoney,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s.tabSettings,
          ),
        ],
      ),
    );
  }
}
