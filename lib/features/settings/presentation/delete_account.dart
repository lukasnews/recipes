import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../data/account_deletion.dart';

/// Confirm, sign in again, delete the data, then the account.
Future<void> deleteAccount(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final auth = ref.read(authRepositoryProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null) return;
  final ok = await confirmDialog(
    context,
    title: l10n.deleteAccountTitle,
    message: l10n.deleteAccountMessage,
    confirmLabel: l10n.deleteAccountConfirm,
  );
  if (!ok || !context.mounted) return;

  String? password;
  if (auth.usesPassword) {
    password = await _askPassword(context);
    if (password == null || !context.mounted) return;
  }

  final deletion = ref.read(accountDeletionProvider);
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  var progressOpen = true;
  void closeProgress() {
    if (progressOpen && nav.mounted) nav.pop();
    progressOpen = false;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          spacing: 24,
          children: [
            const CircularProgressIndicator(),
            Expanded(child: Text(l10n.deletingAccount)),
          ],
        ),
      ),
    ),
  ).ignore();

  try {
    // First, so a failed sign-in never leaves data deleted but the
    // account alive.
    await auth.reauthenticate(password: password);
    await deletion.deleteData(uid);
    closeProgress();
    await auth.deleteUser();
    messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
  } catch (e, st) {
    closeProgress();
    final message = switch (e) {
      NeedsOnlineException() => l10n.needsOnline,
      FirebaseAuthException(code: 'wrong-password' || 'invalid-credential') =>
        l10n.wrongPassword,
      _ => l10n.deleteAccountFailed,
    };
    if (e is! NeedsOnlineException && e is! FirebaseAuthException) {
      reportError(e, st);
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<String?> _askPassword(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const _PasswordDialog(),
);

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.confirmPasswordTitle),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.passwordLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
