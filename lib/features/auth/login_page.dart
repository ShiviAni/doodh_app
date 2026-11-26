import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';
import 'bloc/login_cubit.dart';

/// Sign-in screen.
///
/// The delivery person sees this once — the owner types his credentials in when
/// handing the phone over, and Firebase keeps the session indefinitely after
/// that. It is therefore optimised for the owner, not for repeat use.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoginCubit(auth: sl<AuthService>()),
    child: const _LoginView(),
  );
}

/// Owns only the text controllers, the form key and the show-password toggle.
/// Submitting and its outcome live in [LoginCubit].
class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<LoginCubit>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  String _message(S s, LoginError error) {
    final hindi = s.lang == AppLanguage.hindi;
    return switch (error) {
      LoginError.invalidEmail =>
        hindi ? 'ईमेल सही नहीं है' : 'That email is not valid',
      LoginError.wrongCredentials =>
        hindi ? 'ईमेल या पासवर्ड गलत है' : 'Email or password is incorrect',
      LoginError.noInternet =>
        hindi
            ? 'इंटरनेट नहीं है — लॉगिन के लिए इंटरनेट चाहिए'
            : 'No internet — signing in needs a connection',
      LoginError.tooManyAttempts =>
        hindi
            ? 'बहुत बार कोशिश हुई, थोड़ी देर बाद करें'
            : 'Too many attempts, try again shortly',
      LoginError.unknown => s.loginFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final login = context.watch<LoginCubit>().state;
    final error = login.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sizes.gapLarge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.local_drink_outlined, size: 72),
                    const SizedBox(height: Sizes.gap),
                    Text(
                      s.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Sizes.gapLarge * 1.5),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: s.email,
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? s.email : null,
                    ),
                    const SizedBox(height: Sizes.gap),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: s.password,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? s.password : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: Sizes.gap),
                      Text(
                        _message(s, error),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: Sizes.gapLarge),
                    FilledButton(
                      onPressed: login.submitting ? null : _submit,
                      child: login.submitting
                          ? const SizedBox(
                              height: 26,
                              width: 26,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Text(s.login),
                    ),
                    const SizedBox(height: Sizes.gap),
                    TextButton.icon(
                      icon: const Icon(Icons.translate),
                      label: Text(
                        s.lang == AppLanguage.hindi ? 'English' : 'हिन्दी',
                      ),
                      onPressed: () => LanguageScope.set(
                        context,
                        s.lang == AppLanguage.hindi
                            ? AppLanguage.english
                            : AppLanguage.hindi,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
