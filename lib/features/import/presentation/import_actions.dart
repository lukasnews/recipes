import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/messenger.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../data/photo_picker.dart';
import '../domain/recipe_draft.dart';

enum _AddChoice { manual, camera, gallery }

/// Bottom sheet behind the "+" button: empty recipe, photo or screenshot.
Future<void> showAddRecipeSheet(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final choice = await showModalBottomSheet<_AddChoice>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l10n.addRecipeManual),
            onTap: () => Navigator.pop(context, _AddChoice.manual),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.importCamera),
            subtitle: Text(l10n.importSubtitle),
            onTap: () => Navigator.pop(context, _AddChoice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.importGallery),
            subtitle: Text(l10n.importSubtitle),
            onTap: () => Navigator.pop(context, _AddChoice.gallery),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case _AddChoice.manual:
      await context.push(Routes.newRecipe);
    case _AddChoice.camera:
      await importFromPhotos(context, ref, PhotoSource.camera);
    case _AddChoice.gallery:
      await importFromPhotos(context, ref, PhotoSource.gallery);
  }
}

Future<void> importFromPhotos(
  BuildContext context,
  WidgetRef ref,
  PhotoSource source,
) async {
  final l10n = context.l10n;
  final paths = await ref.read(photoPickerProvider).pick(source);
  if (paths.isEmpty || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(l10n.importReading)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final service = await ref.read(recipeImportServiceProvider.future);
    final drafts = await service.import(paths);
    navigator.pop();
    if (!context.mounted) return;
    final chosen = drafts.length == 1
        ? drafts
        : await _chooseDrafts(context, drafts);
    // Review one after another; back on one just skips it.
    for (final (i, d) in chosen.indexed) {
      if (!context.mounted) return;
      await context.push(
        Routes.newRecipe,
        extra: d.copyWith(position: i + 1, count: chosen.length),
      );
    }
  } catch (e) {
    navigator.pop();
    showGlobalSnack(l10n.importFailed('$e'));
  }
}

Future<List<RecipeDraft>> _chooseDrafts(
  BuildContext context,
  List<RecipeDraft> drafts,
) async {
  final l10n = context.l10n;
  final selected = {for (var i = 0; i < drafts.length; i++) i};
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.importMultipleTitle(drafts.length)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importMultipleHint),
            for (final (i, d) in drafts.indexed)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.contains(i),
                title: Text(d.title),
                onChanged: (v) => setState(
                  () => v == true ? selected.add(i) : selected.remove(i),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, true),
            child: Text(l10n.importMultipleConfirm),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return const [];
  return [
    for (final (i, d) in drafts.indexed)
      if (selected.contains(i)) d,
  ];
}
