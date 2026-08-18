import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../auth/auth_service.dart';
import 'cash_log_sheet.dart';
import 'delivery_card.dart';
import 'round_controller.dart';
import 'sync_badge.dart';

/// The delivery person's entire app.
///
/// There is exactly one job here — walk the route and record each house — so
/// there is no navigation, no menu and no dashboard. Anything that is not the
/// current house is one tap away at most.
class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key, required this.session});

  final Session session;

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  late final RoundController _round = RoundController(
    deliveries: sl<DeliveryRepository>(),
    recordedBy: widget.session.email,
  );

  bool _seeded = false;

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return StreamBuilder<List<Customer>>(
      stream: sl<CustomerRepository>().watchActive(),
      builder: (context, customerSnap) {
        return StreamBuilder<Map<String, Delivery>>(
          stream: sl<DeliveryRepository>().watchDay(_round.dayKey),
          builder: (context, deliverySnap) {
            final customers = customerSnap.data;
            if (customers == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            _round.setCustomers(customers);
            _round.setRecorded(deliverySnap.data ?? const {});

            // Resume where he left off, but only once — re-running this on
            // every rebuild would yank the screen away mid-tap.
            if (!_seeded && customers.isNotEmpty) {
              _seeded = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _round.jumpToFirstPending(),
              );
            }

            if (customers.isEmpty) return _EmptyState(strings: s);

            return AnimatedBuilder(
              animation: _round,
              builder: (context, _) => _round.isComplete
                  ? _DoneScreen(round: _round, session: widget.session)
                  : _RoundScreen(round: _round, session: widget.session),
            );
          },
        );
      },
    );
  }
}

class _RoundScreen extends StatelessWidget {
  const _RoundScreen({required this.round, required this.session});

  final RoundController round;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final customer = round.current;
    if (customer == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        automaticallyImplyLeading: false,
        title: _Progress(done: round.doneCount, total: round.total),
        actions: [SyncBadge(dayKey: round.dayKey)],
      ),
      body: SafeArea(
        child: DeliveryCard(
          customer: customer,
          existing: round.entryFor(customer.id),
          onRecord: (qty, status) =>
              round.record(qtyLitres: qty, status: status),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Sizes.gapLarge,
            0,
            Sizes.gapLarge,
            Sizes.gap,
          ),
          child: Row(
            children: [
              // Going back to fix the previous house is the single most likely
              // recovery action, so it stays visible rather than hidden in a
              // menu.
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: Text(s.back),
                  onPressed: round.index > 0 ? round.previous : null,
                ),
              ),
              const SizedBox(width: Sizes.gap),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.currency_rupee),
                  label: Text(s.moneyReceived),
                  onPressed: () => CashLogSheet.show(
                    context,
                    customer: customer,
                    dayKey: round.dayKey,
                    recordedBy: session.email,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar plus a plain count. The bar carries the meaning for a user who reads
/// slowly; the numbers confirm it for one who reads fine.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              s.progress(done, total),
              style: const TextStyle(
                fontSize: Sizes.bodyText + 2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: Sizes.gap),
            Text(
              s.housesLeft(total - done),
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 12,
            color: AppTheme.confirm,
          ),
        ),
      ],
    );
  }
}

/// Shown once every house has an entry.
class _DoneScreen extends StatelessWidget {
  const _DoneScreen({required this.round, required this.session});

  final RoundController round;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final delivered = round.recorded.values.where((d) => d.isDelivered).length;
    final skipped = round.recorded.values.where((d) => !d.isDelivered).length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(s.roundComplete),
        actions: [SyncBadge(dayKey: round.dayKey)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Sizes.gapLarge),
          children: [
            const Icon(Icons.verified, size: 96, color: AppTheme.confirm),
            const SizedBox(height: Sizes.gap),
            Text(
              s.housesDone(delivered),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: Sizes.titleText,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (skipped > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${s.housesSkipped}: $skipped',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: Sizes.bodyText),
                ),
              ),
            const SizedBox(height: Sizes.gapLarge),
            const Divider(),

            // Every house stays reachable after the round so a mistake can be
            // corrected without waiting for the owner.
            for (final c in round.customers)
              _DoneRow(
                customer: c,
                delivery: round.entryFor(c.id),
                hindi: hindi,
                onTap: () => round.jumpTo(c.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({
    required this.customer,
    required this.delivery,
    required this.hindi,
    required this.onTap,
  });

  final Customer customer;
  final Delivery? delivery;
  final bool hindi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = delivery;
    final delivered = d?.isDelivered ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: Icon(
        delivered ? Icons.check_circle : Icons.cancel,
        color: delivered ? AppTheme.confirm : AppTheme.decline,
        size: 34,
      ),
      title: Text(
        customer.displayName(hindi: hindi),
        style: const TextStyle(
          fontSize: Sizes.bodyText,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        delivered ? '${_litres(d!)} ${s.litre}' : s.notTaken,
        style: const TextStyle(
          fontSize: Sizes.bodyText,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }

  String _litres(Delivery d) {
    final v = d.qtyLitres.toStringAsFixed(1);
    return v.endsWith('.0') ? v.substring(0, v.length - 2) : v;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings});

  final S strings;

  @override
  Widget build(BuildContext context) {
    final hindi = strings.lang == AppLanguage.hindi;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Sizes.gapLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_outlined, size: 72),
              const SizedBox(height: Sizes.gap),
              Text(
                hindi
                    ? 'अभी कोई घर नहीं जोड़ा गया।\nमालिक से कहें कि ग्राहक जोड़ें।'
                    : 'No houses added yet.\nAsk the owner to add customers.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: Sizes.bodyText),
              ),
              const SizedBox(height: Sizes.gapLarge),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(strings.logout),
                onPressed: () => sl<AuthService>().signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
