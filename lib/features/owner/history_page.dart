import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/activity.dart';
import '../../data/repositories/activity_repository.dart';

/// The permanent record of everything that happened to the data.
///
/// Every entry is written server-side by a Cloud Function, so this is not a
/// log the app keeps about itself — it is a log of what actually reached the
/// database, including anything an altered app might have preferred not to
/// mention.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return StreamBuilder<List<Activity>>(
      stream: sl<ActivityRepository>().watchRecent(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snap.data ?? const <Activity>[];
        if (all.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.gapLarge),
              child: Text(
                hindi ? 'अभी कोई बदलाव नहीं हुआ।' : 'Nothing has happened yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Grouped by day so a month of entries stays readable, newest first.
        final grouped = <String, List<Activity>>{};
        for (final a in all) {
          grouped.putIfAbsent(DateKeys.day(a.at), () => []).add(a);
        }

        return ListView(
          padding: const EdgeInsets.all(Sizes.gap),
          children: [
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, Sizes.gap, 4, 6),
                child: Text(
                  Fmt.dayLabel(DateKeys.parseDay(entry.key)),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final a in entry.value)
                _ActivityRow(activity: a, hindi: hindi),
            ],
          ],
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.hindi});

  final Activity activity;
  final bool hindi;

  /// Edits are the entries the owner actually asked to be told about, so they
  /// are the ones that carry a colour and a distinct icon; routine records stay
  /// visually quiet.
  (IconData, Color) get _look => switch (activity.type) {
    ActivityType.deliveryRecorded => (Icons.check_circle, AppTheme.confirm),
    ActivityType.deliveryEdited => (Icons.edit, AppTheme.pending),
    ActivityType.deliveryRemoved => (Icons.delete_outline, AppTheme.decline),
    ActivityType.paymentLogged => (Icons.currency_rupee, AppTheme.pending),
    ActivityType.paymentApproved => (Icons.verified, AppTheme.confirm),
    ActivityType.customerChanged => (Icons.person_outline, AppTheme.seed),
    ActivityType.unknown => (Icons.circle_outlined, Colors.grey),
  };

  String _describe() {
    final a = activity;
    final name = a.customerName ?? a.customerId ?? '';

    String qty(double? v) => v == null ? '' : Fmt.litres(v);

    switch (a.type) {
      case ActivityType.deliveryRecorded:
        if (a.afterStatus == 'skipped') {
          return hindi ? '$name — आज नहीं लिया' : '$name — not taken';
        }
        return hindi
            ? '$name — ${qty(a.afterLitres)} ली दिया'
            : '$name — ${qty(a.afterLitres)} L delivered';

      case ActivityType.deliveryEdited:
        final from = a.beforeStatus == 'skipped'
            ? (hindi ? 'नहीं लिया' : 'not taken')
            : '${qty(a.beforeLitres)} ${hindi ? 'ली' : 'L'}';
        final to = a.afterStatus == 'skipped'
            ? (hindi ? 'नहीं लिया' : 'not taken')
            : '${qty(a.afterLitres)} ${hindi ? 'ली' : 'L'}';
        return hindi
            ? '$name — $from से बदलकर $to'
            : '$name — changed from $from to $to';

      case ActivityType.deliveryRemoved:
        return hindi ? '$name — एंट्री हटाई गई' : '$name — entry removed';

      case ActivityType.paymentLogged:
        return hindi
            ? '$name — ${Fmt.money(a.amount ?? 0)} मिले'
            : '$name — ${Fmt.money(a.amount ?? 0)} collected';

      case ActivityType.paymentApproved:
        return hindi
            ? '$name — ${Fmt.money(a.amount ?? 0)} मंज़ूर'
            : '$name — ${Fmt.money(a.amount ?? 0)} approved';

      case ActivityType.customerChanged:
        if (a.reason != null) return '$name — ${a.reason}';
        return hindi
            ? '$name — रोज़ का दूध ${qty(a.beforeLitres)} से ${qty(a.afterLitres)} ली'
            : '$name — usual changed ${qty(a.beforeLitres)} to ${qty(a.afterLitres)} L';

      case ActivityType.unknown:
        return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look;
    final isEdit =
        activity.type == ActivityType.deliveryEdited ||
        activity.type == ActivityType.deliveryRemoved;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.gap,
        vertical: Sizes.gap - 6,
      ),
      decoration: BoxDecoration(
        // Edits get a tinted card; routine records stay flat, so scanning a
        // long day finds the changes without reading every line.
        color: isEdit ? color.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(Sizes.radius - 6),
        border: isEdit
            ? Border.all(color: color.withValues(alpha: 0.4))
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: Sizes.gap - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _describe(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isEdit ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    DateFormat('h:mm a').format(activity.at),
                    if (activity.dayKey != null &&
                        activity.dayKey != DateKeys.day(activity.at))
                      // Flags an entry recorded for a different day than it was
                      // saved on — a late offline sync, or a back-dated fix.
                      '${hindi ? 'तारीख' : 'for'} ${activity.dayKey}',
                    activity.actorEmail.split('@').first,
                    if (activity.reason != null) activity.reason!,
                  ].join('  ·  '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
