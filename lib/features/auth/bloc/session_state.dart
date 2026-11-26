part of 'session_cubit.dart';

final class SessionState extends Equatable {
  /// Before Firebase has said whether anyone is signed in.
  const SessionState.unknown() : resolved = false, session = null;

  /// [session] is null when nobody is signed in.
  const SessionState.resolved(this.session) : resolved = true;

  final bool resolved;
  final Session? session;

  @override
  List<Object?> get props => [resolved, session?.email, session?.member];
}
