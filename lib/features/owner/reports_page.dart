import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'bloc/reports_cubit.dart';
import 'stat_tile.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ReportsCubit(
      settings: sl<SettingsRepository>(),
      customers: sl<CustomerRepository>(),
      deliveries: sl<DeliveryRepository>(),
    ),
    child: const _ReportsView(),
  );
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  static String _rangeLabel(ReportsState state) {
    final (from, to) = state.range;
    return switch (state.period) {
      ReportPeriod.day => Fmt.dayLabel(from),
      ReportPeriod.week => '${Fmt.shortDay(from)} – ${Fmt.shortDay(to)}',
      ReportPeriod.month => Fmt.monthLabel(from),
      ReportPeriod.year => '${from.year}',
    };
  }

  static Future<void> _exportCsv(ReportsState state) =>
      SharePlus.instance.share(
        ShareParams(
          text: state.toCsv(),
          subject: 'Doodh Hisab — ${_rangeLabel(state)}',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final cubit = context.read<ReportsCubit>();

    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        final rate = state.rate;
        final customers = state.customers;
        final deliveries = state.deliveries!;
        final summary = state.summary;
        final byCustomer = state.litresByCustomer;
        final byDay = state.litresByDay;

        return ListView(
          padding: const EdgeInsets.all(Sizes.gap),
          children: [
            SegmentedButton<ReportPeriod>(
              segments: [
                ButtonSegment(value: ReportPeriod.day, label: Text(s.day)),
                ButtonSegment(value: ReportPeriod.week, label: Text(s.week)),
                ButtonSegment(value: ReportPeriod.month, label: Text(s.month)),
                ButtonSegment(value: ReportPeriod.year, label: Text(s.year)),
              ],
              selected: {state.period},
              showSelectedIcon: false,
              onSelectionChanged: (sel) => cubit.selectPeriod(sel.first),
            ),
            const SizedBox(height: Sizes.gap),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => cubit.shift(-1),
                ),
                Expanded(
                  child: Text(
                    _rangeLabel(state),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: Sizes.bodyText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => cubit.shift(1),
                ),
              ],
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

            if (byDay.length > 1) ...[
              _TrendChart(byDay: byDay),
              const SizedBox(height: Sizes.gap),
            ],

            OutlinedButton.icon(
              icon: const Icon(Icons.table_view_outlined),
              label: Text(s.exportCsv),
              onPressed: deliveries.isEmpty ? null : () => _exportCsv(state),
            ),

            const SizedBox(height: Sizes.gap),
            const Divider(),

            for (final c in customers)
              if ((byCustomer[c.id] ?? 0) > 0)
                ListTile(
                  title: Text(c.displayName(hindi: hindi)),
                  subtitle: c.houseNo.isEmpty
                      ? null
                      : Text('${s.houseNo} ${c.houseNo}'),
                  trailing: Text(
                    '${Fmt.litres(byCustomer[c.id]!)} ${s.litre}'
                    '  ·  ${Fmt.money(byCustomer[c.id]! * rate)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),

            if (deliveries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Sizes.gapLarge),
                child: Text(
                  hindi
                      ? 'इस अवधि का कोई रिकॉर्ड नहीं है।'
                      : 'No records for this period.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Minimal bar chart of litres per day.
///
/// Drawn with plain containers rather than a charting package: it is one series
/// of small non-negative numbers, and a dependency would cost more than it
/// saves.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.byDay});

  final Map<String, double> byDay;

  @override
  Widget build(BuildContext context) {
    final keys = byDay.keys.toList()..sort();
    final max = byDay.values.fold<double>(0, (m, v) => v > m ? v : m);
    if (max <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final k in keys)
            Expanded(
              child: Tooltip(
                message: '$k — ${Fmt.litres(byDay[k]!)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    height: (byDay[k]! / max) * 110,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
