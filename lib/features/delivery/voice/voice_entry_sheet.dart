import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../data/models/customer.dart';
import 'bloc/voice_entry_bloc.dart';
import 'speech_service.dart';
import 'voice_parser.dart';

export 'bloc/voice_entry_bloc.dart' show VoiceResult;

/// Speak-to-record sheet. The logic lives in [VoiceEntryBloc]; this only
/// shows what it heard and asks for an explicit confirmation.
class VoiceEntrySheet extends StatelessWidget {
  const VoiceEntrySheet({
    super.key,
    required this.customers,
    required this.speech,
    required this.localeId,
    this.fixedCustomer,
  });

  final List<Customer> customers;
  final SpeechService speech;

  /// Resolved by the caller, which has a settled context.
  ///
  /// Listening starts as soon as the sheet is built, and reading an
  /// InheritedWidget that early is illegal. Doing so once threw before listen()
  /// was reached, leaving "speak now" on screen with the microphone shut.
  final String localeId;

  /// Set when opened from a house's own card. Then only the quantity is
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
      localeId: S.of(context).lang == AppLanguage.hindi ? 'hi_IN' : 'en_IN',
      fixedCustomer: fixedCustomer,
    ),
  );

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => VoiceEntryBloc(
      speech: speech,
      customers: customers,
      localeId: localeId,
      fixedCustomer: fixedCustomer,
    )..add(const VoiceListenRequested()),
    child: _VoiceEntryView(quantityOnly: fixedCustomer != null),
  );
}

class _VoiceEntryView extends StatelessWidget {
  const _VoiceEntryView({required this.quantityOnly});

  final bool quantityOnly;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final bloc = context.read<VoiceEntryBloc>();

    return BlocBuilder<VoiceEntryBloc, VoiceEntryState>(
      builder: (context, state) => Padding(
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
            if (state.phase == VoicePhase.unavailable)
              _Unavailable(hindi: hindi)
            else if (state.phase == VoicePhase.heardNothing)
              _HeardNothing(hindi: hindi)
            else ...[
              _MicIndicator(listening: state.isListening),
              const SizedBox(height: Sizes.gap),
              Text(
                state.isListening
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
                quantityOnly
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
              if (state.transcript.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Sizes.gap),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Sizes.radius),
                  ),
                  child: Text(
                    state.transcript,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: Sizes.bodyText),
                  ),
                ),
              const SizedBox(height: Sizes.gap),
              _Understood(entry: state.entry, hindi: hindi),
            ],
            const SizedBox(height: Sizes.gapLarge),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(hindi ? 'फिर से' : 'Again'),
                    onPressed: state.phase == VoicePhase.unavailable
                        ? null
                        : () => bloc.add(const VoiceListenRequested()),
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
                    onPressed: state.canConfirm
                        ? () => Navigator.of(context).pop(state.result)
                        : null,
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
      return _Warning(text: s.voiceHouseUnclear);
    }
    if (e.qtyLitres == null && !e.skipped) {
      return _Warning(text: s.voiceQtyUnclear);
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
              s.voiceNameUncertain,
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

/// Shown when nothing was heard within the timeout.
///
/// Names the three real causes in the order he can act on them, and points
/// back at the buttons — which always work — rather than leaving him retrying
/// a microphone that is never going to answer.
class _HeardNothing extends StatelessWidget {
  const _HeardNothing({required this.hindi});

  final bool hindi;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.mic_off, size: 64, color: AppTheme.pending),
      const SizedBox(height: Sizes.gap),
      Text(
        hindi ? 'कुछ सुनाई नहीं दिया' : 'Nothing was heard',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: Sizes.bodyText + 2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        hindi
            ? 'फिर से बोलकर देखिए।\nअगर फिर भी न चले तो नीचे बटन से भरिए — वो हमेशा चलता है।'
            : 'Try speaking again.\nIf it still does not work, use the buttons — those always work.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: Sizes.bodyText - 3),
      ),
    ],
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
