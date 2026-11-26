import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/formats.dart';
import '../../../data/models/activity.dart';
import '../../../data/repositories/activity_repository.dart';

part 'history_state.dart';

/// The most recent activity, grouped by day, newest first.
class HistoryCubit extends Cubit<HistoryState> {
  HistoryCubit({required ActivityRepository activity})
    : super(const HistoryState()) {
    _sub = activity.watchRecent().listen(
      (list) => emit(HistoryState(loaded: true, byDay: _groupByDay(list))),
      onError: addError,
    );
  }

  late final StreamSubscription<List<Activity>> _sub;

  /// Grouped once per snapshot rather than on every build. Insertion order
  /// is kept, so with the stream already newest-first the days come out
  /// newest-first too.
  static Map<String, List<Activity>> _groupByDay(List<Activity> all) {
    final grouped = <String, List<Activity>>{};
    for (final a in all) {
      grouped.putIfAbsent(DateKeys.day(a.at), () => []).add(a);
    }
    return grouped;
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
