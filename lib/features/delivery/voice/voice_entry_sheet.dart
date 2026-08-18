import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery.dart';
import 'speech_service.dart';
import 'voice_parser.dart';

/// Result handed back when he confirms a spoken entry.
class VoiceResult {
  const VoiceResult({
    required this.customer,
    required this.qtyLitres,
    required this.status,
  });

  final Customer customer;
  final double qtyLitres;
  final DeliveryStatus status;
}

/// Speak-to-record: "राम कुमार ढाई लीटर".
///
/// Always ends in an explicit confirmation rather than saving straight from the
/// recogniser. Speech recognition of Indian names is unreliable enough that a
/// silent save would eventually put milk against the wrong house, and a wrong
/// house is a wrong bill at the end of the month.
class VoiceEntrySheet extends StatefulWidget {
  const VoiceEntrySheet({
    super.key,
    required this.customers,
    required this.speech,
    this.fixedCustomer,
  });

  final List<Customer> customers;
  final SpeechService speech;

  /// Set when opened from a house's own card — then only the quantity is
  /// listened for and the name is not second-guessed.
  final Customer? fixedCustomer;

  static Future<VoiceResult?> show(
    BuildContext context, {
    required List<Customer> customers,
    required SpeechService speech,
    Customer? fixedCustomer,
  }) => showModalBottomSheet<VoiceResult>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    builder: (_) => VoiceEntrySheet(
      customers: customers,
      speech: speech,
      fixedCustomer: fixedCustomer,
    ),
  );

  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<VoiceEntrySheet> {
  static const _parser = VoiceParser();

  String _transcript = '';
  VoiceEntry? _entry;
  bool _listening = false;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    widget.speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = widget.speech.isAvailable || await widget.speech.initialise();
    if (!mounted) return;
    if (!ok) {
      setState(() => _unavailable = true);
      return;
    }

    setState(() {
      _listening = true;
      _transcript = '';
      _entry = null;
    });

    final hindi = S.of(context).lang == AppLanguage.hindi;
    await widget.speech.listen(
      localeId: hindi ? 'hi_IN' : 'en_IN',
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcript = text;
          _entry = _interpret(text);
          if (isFinal) _listening = false;
        });
      },
    );
  }

  /// On a card the house is already known, so only a quantity is looked for.
  VoiceEntry _interpret(String text) {
    final fixed = widget.fixedCustomer;
    if (fixed == null) return _parser.parse(text, widget.customers);

    final qty = _parser.parseQuantity(text);
    return VoiceEntry(
      transcript: text,
      customer: fixed,
      qtyLitres: qty,
      skipped: qty == 0,
      nameConfidence: 1,
    );
  }

  void _confirm() {
    final entry = _entry;
    if (entry == null || !entry.isUsable) return;
    Navigator.of(context).pop(
      VoiceResult(
        customer: entry.customer!,
        qtyLitres: entry.qtyLitres ?? 0,
        status: entry.skipped
            ? DeliveryStatus.skipped
            : DeliveryStatus.delivered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return Padding(
      padding: EdgeInsets.only(
        left: Sizes.gapLarge,
        right: Sizes.gapLarge,
        top: Sizes.gapLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sizes.gapLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_unavailable)
            _Unavailable(hindi: hindi)
          else ...[
            _MicIndicator(listening: _listening),
            const SizedBox(height: Sizes.gap),
            Text(
              _listening
                  ? (hindi ? 'बोलिए…' : 'Speak now…')
                  : (hindi ? 'सुन लिया' : 'Got it'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: Sizes.bodyText + 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.fixedCustomer != null
                  ? (hindi ? 'जैसे: "ढाई लीटर"' : 'e.g. "two and half"')
                  : (hindi
                        ? 'जैसे: "राम कुमार ढाई लीटर"'
                        : 'e.g. "Ram Kumar two and half"'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Sizes.gap),
            if (_transcript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Sizes.gap),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Sizes.radius),
                ),
                child: Text(
                  _transcript,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: Sizes.bodyText),
                ),
              ),
            const SizedBox(height: Sizes.gap),
            _Understood(entry: _entry, hindi: hindi),
          ],
          const SizedBox(height: Sizes.gapLarge),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(hindi ? 'फिर से' : 'Again'),
                  onPressed: _unavailable ? null : _start,
                ),
              ),
              const SizedBox(width: Sizes.gap),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.confirm,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: Text(s.save),
                  // Deliberately disabled until a house *and* a quantity are
                  // both understood — never a half-guessed save.
                  onPressed: (_entry?.isUsable ?? false) ? _confirm : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.gap),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
  }
}

class _MicIndicator extends StatelessWidget {
  const _MicIndicator({required this.listening});

  final bool listening;

  @override
  Widget build(BuildContext context) {
    final colour = listening
        ? AppTheme.decline
        : Theme.of(context).colorScheme.primary;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: listening ? 110 : 96,
        width: listening ? 110 : 96,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: colour, width: 3),
        ),
        child: Icon(
          listening ? Icons.mic : Icons.mic_none,
          size: 52,
          color: colour,
        ),
      ),
    );
  }
}

/// Plays back what the app believes it heard, in plain words.
class _Understood extends StatelessWidget {
  const _Understood({required this.entry, required this.hindi});

  final VoiceEntry? entry;
  final bool hindi;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final e = entry;
    if (e == null || e.transcript.isEmpty) return const SizedBox.shrink();

    if (!e.hasCustomer) {
      return _Warning(
        text: hindi
            ? 'घर समझ नहीं आया — नाम दोबारा बोलिए'
            : 'Could not tell which house — say the name again',
      );
    }
    if (e.qtyLitres == null && !e.skipped) {
      return _Warning(
        text: hindi ? 'कितना दूध? दोबारा बोलिए' : 'How much milk? Say it again',
      );
    }

    final name = e.customer!.displayName(hindi: hindi);
    final amount = e.skipped
        ? s.notTaken
        : '${Fmt.litres(e.qtyLitres!)} ${s.litre}';

    return Container(
      padding: const EdgeInsets.all(Sizes.gap),
      decoration: BoxDecoration(
        color: AppTheme.confirm.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Sizes.radius),
        border: Border.all(color: AppTheme.confirm, width: 2),
      ),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: Sizes.bodyText + 4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: Sizes.titleText,
              fontWeight: FontWeight.w800,
              color: AppTheme.confirm,
            ),
          ),
          // A partial name match is flagged rather than hidden, so a doubtful
          // guess gets a second look instead of a silent wrong entry.
          if (e.nameConfidence < 0.99) ...[
            const SizedBox(height: 6),
            Text(
              hindi
                  ? 'नाम पक्का नहीं — देख लीजिए'
                  : 'Name uncertain — check it',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.pending,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Sizes.gap),
    decoration: BoxDecoration(
      color: AppTheme.pending.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(Sizes.radius),
      border: Border.all(color: AppTheme.pending),
    ),
    child: Row(
      children: [
        const Icon(Icons.help_outline, color: AppTheme.pending, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: Sizes.bodyText - 2),
          ),
        ),
      ],
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.hindi});

  final bool hindi;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.mic_off, size: 64, color: AppTheme.decline),
      const SizedBox(height: Sizes.gap),
      Text(
        hindi
            ? 'माइक काम नहीं कर रहा।\nहाथ से भरिए — वही ठीक रहेगा।'
            : 'Microphone is not working.\nUse the buttons instead.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: Sizes.bodyText),
      ),
    ],
  );
}
