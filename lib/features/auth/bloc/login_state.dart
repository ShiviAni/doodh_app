part of 'login_cubit.dart';

/// Why a sign-in failed, in terms the page can phrase for the user.
///
/// Firebase's raw codes never reach the screen, and "user not found" is
/// deliberately folded into [wrongCredentials] so the page does not reveal
/// which emails have accounts.
enum LoginError {
  invalidEmail,
  wrongCredentials,
  noInternet,
  tooManyAttempts,
  unknown;

  static LoginError fromCode(String code) => switch (code) {
    'invalid-email' => invalidEmail,
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => wrongCredentials,
    'network-request-failed' => noInternet,
    'too-many-requests' => tooManyAttempts,
    _ => unknown,
  };
}

final class LoginState extends Equatable {
  const LoginState({this.submitting = false, this.error});

  final bool submitting;
  final LoginError? error;

  @override
  List<Object?> get props => [submitting, error];
}
