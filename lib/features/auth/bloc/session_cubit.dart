import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/fire_and_forget.dart';
import '../auth_service.dart';

part 'session_state.dart';

/// Who is signed in, and with what role. Provided above the whole app.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({required this._auth}) : super(const SessionState.unknown()) {
    _sub = _auth.watchSession().listen(
      (session) => emit(SessionState.resolved(session)),
      onError: addError,
    );
  }

  final AuthService _auth;
  late final StreamSubscription<Session?> _sub;

  /// The session stream emits the signed-out state; nothing else to do here.
  void signOut() => fireAndForget(_auth.signOut());

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
