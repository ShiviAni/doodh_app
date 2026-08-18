import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/models/delivery.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'edit_entry_sheet.dart';
import 'stat_tile.dart';

/// Live view of the round in progress.
///
/// Every stream here is a Firestore snapshot listener, so the totals move the
/// moment the delivery person taps a house — or the moment his phone regains
/// signal, if he was working offline.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final today = DateTime.now();
    final dayKey = DateKeys.day(today);

    return StreamBuilder<double>(
      stream: sl<SettingsRepository>().watchRate(),
      builder: (context, rateSnap) {
        final rate = rateSnap.data ?? SettingsRepository.defaultRate;

        return StreamBuilder<List<Customer>>(
          stream: sl<CustomerRepository>().watchActive(),
          builder: (context, custSnap) {
            final customers = custSnap.data ?? const <Customer>[];

            return StreamBuilder<Map<String, Delivery>>(
              stream: sl<DeliveryRepository>().watchDay(dayKey),
              builder: (context, delSnap) {
                final recorded = delSnap.data ?? const <String, Delivery>{};
                final summary = const ReportCalculator().summarise(
                  deliveries: recorded.values.toList(),
                  ratePerLitre: rate,
                  activeCustomerCount: customers.length,
                );

                return ListView(
                  padding: const EdgeInsets.all(Sizes.gap),
                  children: [
                    Text(
                      '${s.today} — ${Fmt.dayLabel(today)}',
                      style: const TextStyle(
                        fontSize: Sizes.bodyText + 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Sizes.gap),

                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: s.totalLitres,
                            value: '${Fmt.litres(summary.litres)} ${s.litre}',
                            icon: Icons.water_drop_outlined,
                          ),
                        ),
                        const SizedBox(width: Sizes.gap),
                        Expanded(
                          child: StatTile(
                            label: s.totalAmount,
                            value: Fmt.money(summary.amount),
                            icon: Icons.currency_rupee,
                            color: AppTheme.confirm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sizes.gap),

                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: s.housesServed,
                            value: '${summary.deliveredCount}',
                            icon: Icons.check_circle_outline,
                            color: AppTheme.confirm,
                          ),
                        ),
                        const SizedBox(width: Sizes.gap),
                        Expanded(
                          child: StatTile(
                            label: s.housesSkipped,
                            value: '${summary.skippedCount}',
                            icon: Icons.cancel_outlined,
                            color: AppTheme.decline,
                          ),
                        ),
                        const SizedBox(width: Sizes.gap),
                        Expanded(
                          child: StatTile(
                            label: s.housesPending,
                            value: '${summary.pendingCount}',
                            icon: Icons.hourglass_empty,
                            color: AppTheme.pending,
                          ),
                        ),
                      ],
                    ),

                    if (summary.pendingCount > 0) ...[
                      const SizedBox(height: Sizes.gap),
                      _PendingBanner(count: summary.pendingCount, hindi: hindi),
                    ],

                    const SizedBox(height: Sizes.gapLarge),
                    const Divider(),

                    for (final c in customers)
                      _CustomerRow(
                        customer: c,
                        delivery: recorded[c.id],
                        rate: rate,
                        hindi: hindi,
                        dayKey: dayKey,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// The missing-house alert: houses with no entry at all, neither delivered nor
/// explicitly skipped. Without this, a forgotten house looks identical to a
/// house that genuinely took nothing.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.hindi});

  final int count;
  final bool hindi;

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
        const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.pending,
          size: 30,
        ),
        const SizedBox(width: Sizes.gap),
        Expanded(
          child: Text(
            hindi
                ? '$count घर अभी दर्ज नहीं हुए हैं।'
                : '$count houses have not been recorded yet.',
            style: const TextStyle(
              fontSize: Sizes.bodyText - 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.delivery,
    required this.rate,
    required this.hindi,
    required this.dayKey,
  });

  final Customer customer;
  final Delivery? delivery;
  final double rate;
  final bool hindi;
  final String dayKey;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = delivery;

    final (IconData icon, Color color, String trailing) = switch (d) {
      null => (
        Icons.hourglass_empty,
        AppTheme.pending,
        hindi ? 'बाकी' : 'Pending',
      ),
      final x when x.isDelivered => (
        Icons.check_circle,
        AppTheme.confirm,
        '${Fmt.litres(x.qtyLitres)} ${s.litre}  ·  ${Fmt.money(x.qtyLitres * rate)}',
      ),
      _ => (Icons.cancel, AppTheme.decline, s.notTaken),
    };

    return ListTile(
      leading: Icon(icon, color: color, size: 30),
      title: Row(
        children: [
          Flexible(
            child: Text(
              customer.displayName(hindi: hindi),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (d?.wasEdited ?? false) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.pending.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.editedBadge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: customer.houseNo.isEmpty
          ? null
          : Text('${s.houseNo} ${customer.houseNo}'),
      trailing: Text(
        trailing,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      // Owner override — correcting a mistake without waiting for tomorrow.
      onTap: () => EditEntrySheet.show(
        context,
        customer: customer,
        dayKey: dayKey,
        existing: d,
      ),
    );
  }
}
