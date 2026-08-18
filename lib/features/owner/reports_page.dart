import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
import 'stat_tile.dart';

enum ReportPeriod { day, week, month, year }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  ReportPeriod _period = ReportPeriod.month;
  DateTime _anchor = DateTime.now();

  /// Inclusive `yyyy-MM-dd` bounds for the selected period.
  (DateTime, DateTime) get _range => switch (_period) {
    ReportPeriod.day => (
      DateKeys.startOfDay(_anchor),
      DateKeys.startOfDay(_anchor),
    ),
    ReportPeriod.week => (
      DateKeys.startOfWeek(_anchor),
      DateKeys.startOfWeek(_anchor).add(const Duration(days: 6)),
    ),
    ReportPeriod.month => (
      DateKeys.startOfMonth(_anchor),
      DateKeys.endOfMonth(_anchor),
    ),
    ReportPeriod.year => (
      DateKeys.startOfYear(_anchor),
      DateTime(_anchor.year, 12, 31),
    ),
  };

  int get _dayCount {
    final (from, to) = _range;
    return to.difference(from).inDays + 1;
  }

  void _shift(int direction) {
    setState(() {
      _anchor = switch (_period) {
        ReportPeriod.day => _anchor.add(Duration(days: direction)),
        ReportPeriod.week => _anchor.add(Duration(days: 7 * direction)),
        ReportPeriod.month => DateTime(
          _anchor.year,
          _anchor.month + direction,
          1,
        ),
        ReportPeriod.year => DateTime(_anchor.year + direction, 1, 1),
      };
    });
  }

  String get _rangeLabel {
    final (from, to) = _range;
    return switch (_period) {
      ReportPeriod.day => Fmt.dayLabel(from),
      ReportPeriod.week => '${Fmt.shortDay(from)} – ${Fmt.shortDay(to)}',
      ReportPeriod.month => Fmt.monthLabel(from),
      ReportPeriod.year => '${from.year}',
    };
  }

  Future<void> _exportCsv(
    List<Customer> customers,
    List<Delivery> deliveries,
    double rate,
  ) async {
    final byCustomer = const ReportCalculator().litresByCustomer(deliveries);
    final rows = <List<dynamic>>[
      ['Customer', 'House no', 'Litres', 'Rate', 'Amount'],
      for (final c in customers)
        [
          c.name,
          c.houseNo,
          byCustomer[c.id] ?? 0,
          rate,
          (byCustomer[c.id] ?? 0) * rate,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await SharePlus.instance.share(
      ShareParams(text: csv, subject: 'Doodh Hisab — $_rangeLabel'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    final (from, to) = _range;

    return StreamBuilder<double>(
      stream: sl<SettingsRepository>().watchRate(),
      builder: (context, rateSnap) {
        final rate = rateSnap.data ?? SettingsRepository.defaultRate;

        return StreamBuilder<List<Customer>>(
          stream: sl<CustomerRepository>().watchAll(),
          builder: (context, custSnap) {
            final customers = custSnap.data ?? const <Customer>[];
            final activeCount = customers.where((c) => c.active).length;

            return StreamBuilder<List<Delivery>>(
              stream: sl<DeliveryRepository>().watchRange(
                DateKeys.day(from),
                DateKeys.day(to),
              ),
              builder: (context, delSnap) {
                if (delSnap.connectionState == ConnectionState.waiting &&
                    !delSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final deliveries = delSnap.data ?? const <Delivery>[];
                final calc = const ReportCalculator();
                final summary = calc.summarise(
                  deliveries: deliveries,
                  ratePerLitre: rate,
                  activeCustomerCount: activeCount,
                  expectedDays: _dayCount,
                );
                final byCustomer = calc.litresByCustomer(deliveries);
                final byDay = calc.litresByDay(deliveries);

                return ListView(
                  padding: const EdgeInsets.all(Sizes.gap),
                  children: [
                    SegmentedButton<ReportPeriod>(
                      segments: [
                        ButtonSegment(
                          value: ReportPeriod.day,
                          label: Text(s.day),
                        ),
                        ButtonSegment(
                          value: ReportPeriod.week,
                          label: Text(s.week),
                        ),
                        ButtonSegment(
                          value: ReportPeriod.month,
                          label: Text(s.month),
                        ),
                        ButtonSegment(
                          value: ReportPeriod.year,
                          label: Text(s.year),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (sel) =>
                          setState(() => _period = sel.first),
                    ),
                    const SizedBox(height: Sizes.gap),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _shift(-1),
                        ),
                        Text(
                          _rangeLabel,
                          style: const TextStyle(
                            fontSize: Sizes.bodyText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _shift(1),
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
                      onPressed: deliveries.isEmpty
                          ? null
                          : () => _exportCsv(customers, deliveries, rate),
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
          },
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
