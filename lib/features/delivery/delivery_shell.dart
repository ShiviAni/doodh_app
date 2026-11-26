import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../auth/auth_service.dart';
import '../auth/bloc/session_cubit.dart';
import 'bloc/round_cubit.dart';
import 'cash_log_sheet.dart';
import 'delivery_card.dart';
import 'delivery_list_page.dart';
import 'sync_badge.dart';
import 'voice/speech_service.dart';
import 'voice/voice_entry_sheet.dart';

/// The delivery person's entire app: a list of houses he taps as he goes.
///
/// He does not walk a fixed order in practice — he hands over the milk, then
/// reaches for the phone — so the list is the home screen and any house is one
/// tap away. The mic is the fast path: speaking "राम कुमार ढाई लीटर" fills the
/// same entry without finding the row at all.
class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key, required this.session});

  final Session session;

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  late final SpeechService _speech = sl<SpeechService>();

  @override
  void initState() {
    super.initState();
    // Warm the recogniser up front so the first tap on the mic starts
    // listening immediately rather than after a visible pause.
    unawaited(_speech.initialise());
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RoundCubit(
      customers: sl<CustomerRepository>(),
      deliveries: sl<DeliveryRepository>(),
      recordedBy: widget.session.email,
    ),
    child: _RoundView(session: widget.session, speech: _speech),
  );
}

class _RoundView extends StatefulWidget {
  const _RoundView({required this.session, required this.speech});

  final Session session;
  final SpeechService speech;

  @override
  State<_RoundView> createState() => _RoundViewState();
}

/// Only the search field's open/closed toggle and its text controller live
/// here; everything about the round itself is in [RoundCubit].
class _RoundViewState extends State<_RoundView> {
  final _searchController = TextEditingController();
  bool _searching = false;

  RoundCubit get _round => context.read<RoundCubit>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchController.clear();
      _round.search('');
    }
  }

  void _record(Customer customer, double qty, DeliveryStatus status) =>
      _round.record(customerId: customer.id, qtyLitres: qty, status: status);

  /// Open one house's entry card.
  Future<void> _openCustomer(Customer customer) async {
    final state = _round.state;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntrySheet(
        customer: customer,
        existing: state.entryFor(customer.id),
        dayKey: state.dayKey,
        recordedBy: widget.session.email,
        speech: widget.speech,
        onRecord: (qty, status) => _record(customer, qty, status),
      ),
    );
  }

  Future<void> _openVoice() async {
    final result = await VoiceEntrySheet.show(
      context,
      customers: _round.state.customers,
      speech: widget.speech,
    );
    if (result == null || !mounted) return;

    _record(result.customer, result.qtyLitres, result.status);

    final s = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.confirm,
        content: Text(
          '${result.customer.displayName(hindi: s.lang == AppLanguage.hindi)}  ✓',
          style: const TextStyle(color: Colors.white, fontSize: Sizes.bodyText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return BlocBuilder<RoundCubit, RoundState>(
      builder: (context, round) {
        // A stream error before any customers arrived keeps the spinner, as
        // the StreamBuilder did. Firestore retries on its own, and saying
        // "no houses" would be wrong.
        final waiting =
            round.status == RoundStatus.loading ||
            (round.status == RoundStatus.failure && round.customers.isEmpty);
        if (waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (round.customers.isEmpty) return _EmptyState(strings: s);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            automaticallyImplyLeading: false,
            title: _searching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: s.searchHint,
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: Sizes.bodyText),
                    onChanged: _round.search,
                  )
                : _Progress(done: round.doneCount, total: round.total),
            actions: [
              IconButton(
                iconSize: 30,
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: _toggleSearch,
              ),
              if (!_searching) SyncBadge(dayKey: round.dayKey),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (round.isComplete) _CompleteBanner(strings: s),
                Expanded(
                  child: DeliveryListPage(
                    customers: round.customers,
                    recorded: round.recorded,
                    query: round.query,
                    onTapCustomer: _openCustomer,
                  ),
                ),
              ],
            ),
          ),
          // The mic is the largest control on the screen because it is the
          // fastest way to record without reading anything at all.
          floatingActionButton: FloatingActionButton.large(
            backgroundColor: AppTheme.confirm,
            foregroundColor: Colors.white,
            onPressed: _openVoice,
            tooltip: s.lang == AppLanguage.hindi
                ? 'बोलकर भरें'
                : 'Record by voice',
            child: const Icon(Icons.mic, size: 44),
          ),
        );
      },
    );
  }
}

/// One house's entry, opened from the list.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({
    required this.customer,
    required this.existing,
    required this.dayKey,
    required this.recordedBy,
    required this.speech,
    required this.onRecord,
  });

  final Customer customer;
  final Delivery? existing;
  final String dayKey;
  final String recordedBy;
  final SpeechService speech;
  final void Function(double qty, DeliveryStatus status) onRecord;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  double? _voiceQty;

  Future<void> _speakQuantity() async {
    final result = await VoiceEntrySheet.show(
      context,
      customers: [widget.customer],
      speech: widget.speech,
      fixedCustomer: widget.customer,
    );
    if (result == null || !mounted) return;

    widget.onRecord(result.qtyLitres, result.status);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Sizes.gap),
            DeliveryCard(
              customer: widget.customer,
              existing: widget.existing,
              initialQty: _voiceQty,
              onRecord: (qty, status) {
                widget.onRecord(qty, status);
                Navigator.of(context).pop();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.gapLarge,
                0,
                Sizes.gapLarge,
                Sizes.gapLarge,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.mic, size: 28),
                      label: Text(
                        s.lang == AppLanguage.hindi ? 'बोलकर' : 'Speak',
                      ),
                      onPressed: _speakQuantity,
                    ),
                  ),
                  const SizedBox(width: Sizes.gap),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.currency_rupee),
                      label: Text(s.moneyReceived),
                      onPressed: () => CashLogSheet.show(
                        context,
                        customer: widget.customer,
                        dayKey: widget.dayKey,
                        recordedBy: widget.recordedBy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            Flexible(
              child: Text(
                s.housesLeft(total - done),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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

class _CompleteBanner extends StatelessWidget {
  const _CompleteBanner({required this.strings});

  final S strings;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppTheme.confirm.withValues(alpha: 0.12),
    padding: const EdgeInsets.symmetric(horizontal: Sizes.gap, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.verified, color: AppTheme.confirm, size: 30),
        const SizedBox(width: 10),
        Text(
          strings.roundComplete,
          style: const TextStyle(
            fontSize: Sizes.bodyText,
            fontWeight: FontWeight.w700,
            color: AppTheme.confirm,
          ),
        ),
      ],
    ),
  );
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
                onPressed: () => context.read<SessionCubit>().signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
