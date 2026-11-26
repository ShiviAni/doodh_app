import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/payment_repository.dart';
import 'bloc/cash_log_cubit.dart';

/// Lets the delivery person note cash handed to him at the door.
///
/// Write-only by design. He picks an amount and it is gone — no total, no
/// balance, no history is ever shown back, and the security rules deny him read
/// access to the payments collection so that stays true off-device too. What he
/// records lands unapproved and only counts once the owner confirms it.
class CashLogSheet extends StatelessWidget {
  const CashLogSheet({
    super.key,
    required this.customer,
    required this.dayKey,
    required this.recordedBy,
  });

  final Customer customer;
  final String dayKey;
  final String recordedBy;

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required String dayKey,
    required String recordedBy,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => CashLogSheet(
      customer: customer,
      dayKey: dayKey,
      recordedBy: recordedBy,
    ),
  );

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CashLogCubit(
      payments: sl<PaymentRepository>(),
      customerId: customer.id,
      dayKey: dayKey,
      recordedBy: recordedBy,
    ),
    child: _CashLogView(customer: customer),
  );
}

class _CashLogView extends StatelessWidget {
  const _CashLogView({required this.customer});

  final Customer customer;

  /// Common note denominations. Tapping builds up the amount the way counting
  /// notes does, which avoids a numeric keypad entirely.
  static const _notes = [500.0, 200.0, 100.0, 50.0, 20.0, 10.0];

  void _onSubmitted(BuildContext context) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.confirm,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              '${S.of(context).moneySent} ✓',
              style: const TextStyle(
                color: Colors.white,
                fontSize: Sizes.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final cubit = context.read<CashLogCubit>();

    return BlocConsumer<CashLogCubit, CashLogState>(
      listenWhen: (prev, next) => !prev.submitted && next.submitted,
      listener: (context, _) => _onSubmitted(context),
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
            Text(
              customer.displayName(hindi: hindi),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: Sizes.bodyText + 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.amountReceived,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: Sizes.bodyText),
            ),
            const SizedBox(height: Sizes.gap),

            Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Sizes.radius),
              ),
              child: Text(
                Fmt.money(state.amount),
                style: const TextStyle(
                  fontSize: Sizes.hugeNumber,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: Sizes.gap),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final note in _notes)
                  SizedBox(
                    width: 100,
                    height: 64,
                    child: OutlinedButton(
                      onPressed: () => cubit.addNote(note),
                      child: Text('+${Fmt.money(note)}'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Sizes.gap),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.amount == 0 ? null : cubit.clear,
                    child: Text(s.cancel),
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
                    icon: const Icon(Icons.check),
                    label: Text(s.save),
                    onPressed: state.canSubmit ? cubit.submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
