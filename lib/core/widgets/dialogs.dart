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

/// One text field in a dialog; returns the text on confirm, null on cancel.
/// The field's controller lives as long as the dialog (also during its
/// closing animation).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? hint,
  String? helper,
  String? suffix,
  String? confirmLabel,
  TextInputType? keyboardType,
  TextCapitalization capitalization = TextCapitalization.none,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(
    title: title,
    label: label,
    initial: initial,
    hint: hint,
    helper: helper,
    suffix: suffix,
    confirmLabel: confirmLabel,
    keyboardType: keyboardType,
    capitalization: capitalization,
  ),
);

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.capitalization,
    this.hint,
    this.helper,
    this.suffix,
    this.confirmLabel,
    this.keyboardType,
  });

  final String title;
  final String label;
  final String initial;
  final String? hint;
  final String? helper;
  final String? suffix;
  final String? confirmLabel;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.capitalization,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 3,
          suffixText: widget.suffix,
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel ?? l10n.ok),
        ),
      ],
    );
  }
}
