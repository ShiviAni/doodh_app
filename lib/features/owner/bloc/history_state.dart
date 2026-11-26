part of 'history_cubit.dart';

final class HistoryState extends Equatable {
  const HistoryState({this.loaded = false, this.byDay = const {}});

  final bool loaded;

  /// Day key to that day's activity.
  final Map<String, List<Activity>> byDay;

  bool get isEmpty => byDay.isEmpty;

  @override
  List<Object?> get props => [loaded, byDay];
}
