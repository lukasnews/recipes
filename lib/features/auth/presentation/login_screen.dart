import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';

String authErrorText(AppLocalizations l10n, Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'INVALID_LOGIN_CREDENTIALS' => l10n.authErrorInvalid,
      'email-already-in-use' => l10n.authErrorEmailInUse,
      'weak-password' => l10n.authErrorWeakPassword,
      'invalid-email' => l10n.authErrorInvalidEmail,
      'network-request-failed' => l10n.authErrorNetwork,
      _ => l10n.errorGeneric(error.message ?? error.code),
    };
  }
  return l10n.errorGeneric('$error');
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GoogleSignInCancelled {
      // Closed the account picker: nothing to report.
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!_form.currentState!.validate()) return;
    final auth = ref.read(authRepositoryProvider);
    await _run(() async {
      await (_register
          ? auth.registerWithEmail(_name.text, _email.text, _password.text)
          : auth.signInWithEmail(_email.text, _password.text));
      // Lets Samsung Pass / Google Password Manager offer to save the login.
      TextInput.finishAutofillContext();
    });
  }

  Future<void> _resetPassword() async {
    final l10n = context.l10n;
    if (_email.text.trim().isEmpty) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) showSnack(context, l10n.passwordResetSent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.menu_book,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.appTitle,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        l10n.appTagline,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.loginSubtitle, textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                ref
                                    .read(authRepositoryProvider)
                                    .signInWithGoogle,
                              ),
                        icon: const Icon(Icons.account_circle),
                        label: Text(l10n.loginGoogle),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(l10n.loginOr),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          autofillHints: const [AutofillHints.name],
                          decoration: InputDecoration(
                            labelText: l10n.nameLabel,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: required,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        decoration: InputDecoration(labelText: l10n.emailLabel),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                        ),
                        obscureText: true,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        validator: required,
                        onFieldSubmitted: (_) => _submitEmail(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _busy ? null : _submitEmail,
                        child: Text(
                          _register ? l10n.registerEmail : l10n.loginEmail,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _register = !_register),
                        child: Text(
                          _register
                              ? l10n.switchToLogin
                              : l10n.switchToRegister,
                        ),
                      ),
                      if (!_register)
                        TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: Text(l10n.forgotPassword),
                        ),
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
