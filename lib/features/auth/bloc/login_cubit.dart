import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth_service.dart';

part 'login_state.dart';

/// Signs in with email and password.
///
/// On success there is nothing to emit: the session stream in [AuthService]
/// moves the app on, and this page is replaced.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required this._auth}) : super(const LoginState());

  final AuthService _auth;

  void submit({required String email, required String password}) {
    if (state.submitting) return;
    unawaited(_submit(email, password));
  }

  Future<void> _submit(String email, String password) async {
    emit(const LoginState(submitting: true));
    try {
      await _auth.signIn(email: email, password: password);
      if (!isClosed) emit(const LoginState());
    } on FirebaseAuthException catch (e) {
      if (!isClosed) emit(LoginState(error: LoginError.fromCode(e.code)));
    } on Exception {
      if (!isClosed) emit(const LoginState(error: LoginError.unknown));
    }
  }
}
