import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';

/// Sign-in screen.
///
/// The delivery person sees this once — the owner types his credentials in when
/// handing the phone over, and Firebase keeps the session indefinitely after
/// that. It is therefore optimised for the owner, not for repeat use.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await sl<AuthService>().signIn(
        email: _email.text,
        password: _password.text,
      );
      // On success the session stream drives navigation; nothing to do here.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _humanMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context).loginFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanMessage(String code) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;
    switch (code) {
      case 'invalid-email':
        return hindi ? 'ईमेल सही नहीं है' : 'That email is not valid';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return hindi
            ? 'ईमेल या पासवर्ड गलत है'
            : 'Email or password is incorrect';
      case 'network-request-failed':
        return hindi
            ? 'इंटरनेट नहीं है — लॉगिन के लिए इंटरनेट चाहिए'
            : 'No internet — signing in needs a connection';
      case 'too-many-requests':
        return hindi
            ? 'बहुत बार कोशिश हुई, थोड़ी देर बाद करें'
            : 'Too many attempts, try again shortly';
      default:
        return s.loginFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
                    if (_error != null) ...[
                      const SizedBox(height: Sizes.gap),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: Sizes.gapLarge),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
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
