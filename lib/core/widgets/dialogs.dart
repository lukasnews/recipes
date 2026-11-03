import 'package:flutter/material.dart';

import 'l10n_ext.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel ?? l10n.ok),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

/// Parses a user typed number with comma or dot.
double? parseUserNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
