part of 'round_cubit.dart';

enum RoundStatus { loading, ready, failure }

/// One morning's round: the houses, what has been recorded for each, and the
/// search the delivery person has typed.
final class RoundState extends Equatable {
  const RoundState({
    required this.dayKey,
    this.status = RoundStatus.loading,
    this.customers = const [],
    this.recorded = const {},
    this.query = '',
  });

  final String dayKey;
  final RoundStatus status;
  final List<Customer> customers;
  final Map<String, Delivery> recorded;
  final String query;

  int get total => customers.length;
  int get doneCount =>
      customers.where((c) => recorded.containsKey(c.id)).length;
  int get remainingCount => total - doneCount;
  bool get isComplete => total > 0 && remainingCount == 0;

  Delivery? entryFor(String customerId) => recorded[customerId];

  /// Houses with no entry at all, so nothing goes silently unrecorded.
  List<Customer> get missing =>
      customers.where((c) => !recorded.containsKey(c.id)).toList();

  RoundState copyWith({
    RoundStatus? status,
    List<Customer>? customers,
    Map<String, Delivery>? recorded,
    String? query,
  }) => RoundState(
    dayKey: dayKey,
    status: status ?? this.status,
    customers: customers ?? this.customers,
    recorded: recorded ?? this.recorded,
    query: query ?? this.query,
  );

  @override
  List<Object?> get props => [dayKey, status, customers, recorded, query];
}
