import 'dart:async';

import 'package:csv/csv.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/formats.dart';
import '../../../data/models/bill.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/settings_repository.dart';

part 'reports_state.dart';

/// Totals for a chosen day, week, month or year.
///
/// Changing the period or stepping through it swaps the delivery listener for
/// one over the new range; the rate and customer listeners stay put. The
/// previous figures stay on screen until the new range arrives, which from
/// the offline cache is near-instant, rather than flashing a spinner.
class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit({
    required SettingsRepository settings,
    required CustomerRepository customers,
    required this._deliveries,
    DateTime? now,
  }) : super(ReportsState(anchor: now ?? DateTime.now())) {
    _subs = [
      settings.watchRate().listen(
        (rate) => emit(state.copyWith(rate: rate)),
        onError: addError,
      ),
      customers.watchAll().listen(
        (list) => emit(state.copyWith(customers: list)),
        onError: addError,
      ),
    ];
    _watchRange();
  }

  final DeliveryRepository _deliveries;
  late final List<StreamSubscription<Object?>> _subs;
  StreamSubscription<List<Delivery>>? _rangeSub;

  void selectPeriod(ReportPeriod period) {
    if (period == state.period) return;
    emit(state.copyWith(period: period));
    _watchRange();
  }

  /// One period back (-1) or forward (+1).
  void shift(int direction) {
    final anchor = state.anchor;
    final next = switch (state.period) {
      ReportPeriod.day => anchor.add(Duration(days: direction)),
      ReportPeriod.week => anchor.add(Duration(days: 7 * direction)),
      ReportPeriod.month => DateTime(anchor.year, anchor.month + direction, 1),
      ReportPeriod.year => DateTime(anchor.year + direction, 1, 1),
    };
    emit(state.copyWith(anchor: next));
    _watchRange();
  }

  void _watchRange() {
    unawaited(_rangeSub?.cancel());
    final (from, to) = state.range;
    _rangeSub = _deliveries
        .watchRange(DateKeys.day(from), DateKeys.day(to))
        .listen(
          (list) => emit(state.copyWith(deliveries: list)),
          onError: addError,
        );
  }

  @override
  Future<void> close() async {
    await _rangeSub?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    return super.close();
  }
}
