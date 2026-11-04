import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../data/backup_service.dart';

/// Writes the household as JSON and opens the share sheet
/// (e.g. "In Drive speichern").
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  try {
    final json = await ref.read(backupServiceProvider).export();
    final name = (json['householdName'] as String).replaceAll(
      RegExp(r'[^\w\-äöüÄÖÜß]+'),
      '_',
    );
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/BaCo-$name-$date.json');
    await file.writeAsString(jsonEncode(json));
    await ref
        .read(sharerProvider)
        .shareFile(
          file.path,
          mimeType: 'application/json',
          subject: l10n.backupSubject,
        );
  } catch (e, st) {
    reportError(e, st);
    if (context.mounted) showSnack(context, l10n.backupFailed);
  }
}

/// A file shared or opened with BaCo: restore it after confirmation.
Future<void> restoreBackupFile(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final l10n = context.l10n;
  Map<String, dynamic> json;
  BackupInfo info;
  try {
    json = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    info = BackupService.inspect(json);
  } catch (_) {
    if (context.mounted) showSnack(context, l10n.backupInvalid);
    return;
  }
  if (!context.mounted) return;
  final target = ref.read(householdProvider).value?.name ?? '';
  final ok = await confirmDialog(
    context,
    title: l10n.restoreTitle,
    message: l10n.restoreMessage(
      info.householdName,
      info.exportedAt == null
          ? '?'
          : DateFormat('d. M. yyyy', 'de').format(info.exportedAt!.toLocal()),
      info.recipes,
      target,
    ),
    confirmLabel: l10n.restoreConfirm,
  );
  if (!ok || !context.mounted) return;
  final count = ref.read(backupServiceProvider).restore(json);
  showSnack(context, l10n.restoreDone(count));
}

/// "Wiederherstellen": explains how to hand a backup file to BaCo.
Future<void> showRestoreHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(context.l10n.restoreTitle),
    content: Text(context.l10n.restoreHelp),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.ok),
      ),
    ],
  ),
);
