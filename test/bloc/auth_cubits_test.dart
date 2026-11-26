import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:doodh_app/data/models/member.dart';
import 'package:doodh_app/features/auth/auth_service.dart';
import 'package:doodh_app/features/auth/bloc/login_cubit.dart';
import 'package:doodh_app/features/auth/bloc/session_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthService auth;

  setUp(() => auth = _MockAuthService());

  group('LoginCubit', () {
    void signInAnswers(Future<void> Function() answer) => when(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => answer());

    blocTest<LoginCubit, LoginState>(
      'shows progress, then clears it on success',
      setUp: () => signInAnswers(() async {}),
      build: () => LoginCubit(auth: auth),
      act: (cubit) => cubit.submit(email: 'a@b.c', password: 'pw'),
      expect: () => const [LoginState(submitting: true), LoginState()],
      verify: (_) =>
          verify(() => auth.signIn(email: 'a@b.c', password: 'pw')).called(1),
    );

    for (final (code, error) in [
      ('invalid-email', LoginError.invalidEmail),
      ('wrong-password', LoginError.wrongCredentials),
      ('invalid-credential', LoginError.wrongCredentials),
      // Folded in with wrong password so the page never reveals which
      // emails have accounts.
      ('user-not-found', LoginError.wrongCredentials),
      ('network-request-failed', LoginError.noInternet),
      ('too-many-requests', LoginError.tooManyAttempts),
      ('something-new', LoginError.unknown),
    ]) {
      blocTest<LoginCubit, LoginState>(
        'Firebase "$code" becomes $error',
        setUp: () =>
            signInAnswers(() async => throw FirebaseAuthException(code: code)),
        build: () => LoginCubit(auth: auth),
        act: (cubit) => cubit.submit(email: 'a@b.c', password: 'pw'),
        expect: () => [
          const LoginState(submitting: true),
          LoginState(error: error),
        ],
      );
    }

    blocTest<LoginCubit, LoginState>(
      'a second tap while signing in does not sign in twice',
      setUp: () => signInAnswers(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      ),
      build: () => LoginCubit(auth: auth),
      act: (cubit) => cubit
        ..submit(email: 'a@b.c', password: 'pw')
        ..submit(email: 'a@b.c', password: 'pw'),
      wait: const Duration(milliseconds: 30),
      verify: (_) => verify(
        () => auth.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).called(1),
    );
  });

  group('SessionCubit', () {
    late StreamController<Session?> sessions;

    setUp(() {
      sessions = StreamController<Session?>();
      when(() => auth.watchSession()).thenAnswer((_) => sessions.stream);
      when(() => auth.signOut()).thenAnswer((_) async {});
    });

    tearDown(() => sessions.close());

    const owner = Session(
      email: 'owner@doodh.local',
      member: Member(
        email: 'owner@doodh.local',
        role: MemberRole.owner,
        displayName: 'Owner',
      ),
    );

    test('is unresolved until Firebase answers', () async {
      final cubit = SessionCubit(auth: auth);
      expect(cubit.state.resolved, isFalse);
      await cubit.close();
    });

    blocTest<SessionCubit, SessionState>(
      'follows sign-in and sign-out',
      build: () => SessionCubit(auth: auth),
      act: (_) => sessions
        ..add(owner)
        ..add(null),
      expect: () => const [
        SessionState.resolved(owner),
        SessionState.resolved(null),
      ],
    );

    blocTest<SessionCubit, SessionState>(
      'signOut asks the auth service to sign out',
      build: () => SessionCubit(auth: auth),
      act: (cubit) => cubit.signOut(),
      verify: (_) => verify(() => auth.signOut()).called(1),
    );
  });
}
