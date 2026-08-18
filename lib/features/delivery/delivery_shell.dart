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
import 'delivery_list_page.dart';
import 'round_controller.dart';
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
  late final RoundController _round = RoundController(
    deliveries: sl<DeliveryRepository>(),
    recordedBy: widget.session.email,
  );

  final _searchController = TextEditingController();
  late final SpeechService _speech = sl<SpeechService>();

  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Warm the recogniser up front so the first tap on the mic starts
    // listening immediately rather than after a visible pause.
    _speech.initialise();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _round.dispose();
    super.dispose();
  }

  /// Open one house's entry card.
  Future<void> _openCustomer(Customer customer) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntrySheet(
        customer: customer,
        existing: _round.entryFor(customer.id),
        dayKey: _round.dayKey,
        recordedBy: widget.session.email,
        speech: _speech,
        onRecord: (qty, status) {
          _round.recordFor(
            customerId: customer.id,
            qtyLitres: qty,
            status: status,
          );
        },
      ),
    );
  }

  Future<void> _openVoice() async {
    final result = await VoiceEntrySheet.show(
      context,
      customers: _round.customers,
      speech: _speech,
    );
    if (result == null || !mounted) return;

    _round.recordFor(
      customerId: result.customer.id,
      qtyLitres: result.qtyLitres,
      status: result.status,
    );

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

            if (customers.isEmpty) return _EmptyState(strings: s);

            return AnimatedBuilder(
              animation: _round,
              builder: (context, _) => Scaffold(
                appBar: AppBar(
                  toolbarHeight: 76,
                  automaticallyImplyLeading: false,
                  title: _searching
                      ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: s.lang == AppLanguage.hindi
                                ? 'नाम या घर नं.'
                                : 'Name or house no.',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: Sizes.bodyText),
                          onChanged: (v) => setState(() => _query = v),
                        )
                      : _Progress(done: _round.doneCount, total: _round.total),
                  actions: [
                    IconButton(
                      iconSize: 30,
                      icon: Icon(_searching ? Icons.close : Icons.search),
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) {
                          _query = '';
                          _searchController.clear();
                        }
                      }),
                    ),
                    if (!_searching) SyncBadge(dayKey: _round.dayKey),
                  ],
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      if (_round.isComplete) _CompleteBanner(strings: s),
                      Expanded(
                        child: DeliveryListPage(
                          customers: _round.customers,
                          recorded: _round.recorded,
                          query: _query,
                          onTapCustomer: _openCustomer,
                        ),
                      ),
                    ],
                  ),
                ),
                // The mic is the largest control on the screen because it is
                // the fastest way to record without reading anything at all.
                floatingActionButton: FloatingActionButton.large(
                  backgroundColor: AppTheme.confirm,
                  foregroundColor: Colors.white,
                  onPressed: _openVoice,
                  tooltip: s.lang == AppLanguage.hindi
                      ? 'बोलकर भरें'
                      : 'Record by voice',
                  child: const Icon(Icons.mic, size: 44),
                ),
              ),
            );
          },
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
                onPressed: () => sl<AuthService>().signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
