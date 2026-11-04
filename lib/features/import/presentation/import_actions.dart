import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/messenger.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../household/domain/allergen.dart';
import '../../pantry/domain/pantry_item.dart';
import '../data/photo_picker.dart';
import '../domain/recipe_draft.dart';
import '../domain/web_recipe.dart';

enum _AddChoice { manual, camera, gallery, link, ideas }

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
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.importLink),
            subtitle: Text(l10n.importLinkSubtitle),
            onTap: () => Navigator.pop(context, _AddChoice.link),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.ideasFromPantry),
            subtitle: Text(l10n.ideasFromPantrySubtitle),
            onTap: () => Navigator.pop(context, _AddChoice.ideas),
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
    case _AddChoice.link:
      await askAndImportLink(context, ref);
    case _AddChoice.ideas:
      await suggestRecipesFromPantry(context, ref);
  }
}

/// Recipe ideas from the AI that use up the pantry (soon-expiring first),
/// leaving out the household's allergens. Each idea is reviewed like an
/// import.
Future<void> suggestRecipesFromPantry(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final wishController = TextEditingController();
  final wish = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.ideasFromPantry),
      content: TextField(
        controller: wishController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.ideasWishLabel,
          hintText: l10n.ideasWishHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, wishController.text),
          child: Text(l10n.ideasGet),
        ),
      ],
    ),
  );
  if (wish == null || !context.mounted) return;

  final ingredients = ref.read(ingredientsByIdProvider);
  final now = DateTime.now();
  final stock =
      [
        for (final p
            in ref.read(pantryProvider).value?.values ?? <PantryItem>[])
          if (p.amount > 0 && ingredients[p.ingredientId] != null) p,
      ]..sort((a, b) {
        final ea = a.expiry(now) == Expiry.none ? 1 : 0;
        final eb = b.expiry(now) == Expiry.none ? 1 : 0;
        return ea.compareTo(eb);
      });
  final pantry = [
    for (final p in stock)
      [
        ingredients[p.ingredientId]!.name,
        ' (${formatBaseAmount(p.amount, ingredients[p.ingredientId]!.baseUnit)}',
        if (p.expiry(now) != Expiry.none) ', läuft bald ab',
        ')',
      ].join(),
  ];
  if (pantry.isEmpty) {
    showGlobalSnack(l10n.ideasPantryEmpty);
    return;
  }
  final avoid = {
    for (final m in ref.read(membersProvider).value ?? <HouseholdMember>[])
      ...m.allergens,
  }.map(l10n.allergen).toList();
  await _runImport(context, () async {
    final extractor = await ref.read(recipeExtractorProvider.future);
    final ideas = await extractor.suggestFromPantry(
      pantry: pantry,
      wish: wish,
      avoid: avoid,
    );
    return [for (final d in ideas) d.copyWith(notes: l10n.ideaNote)];
  }, message: l10n.ideasThinking);
}

Future<void> importFromPhotos(
  BuildContext context,
  WidgetRef ref,
  PhotoSource source,
) async {
  final paths = await ref.read(photoPickerProvider).pick(source);
  if (paths.isEmpty || !context.mounted) return;
  await _runImport(context, () async {
    final service = await ref.read(recipeImportServiceProvider.future);
    return service.import(paths);
  });
}

/// Asks for a web address (prefilled from the clipboard) and imports it.
Future<void> askAndImportLink(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) return;
  final controller = TextEditingController(
    text: findUrl(clip)?.toString() ?? '',
  );
  final url = await showDialog<Uri>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.importLink),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: l10n.importLinkLabel,
          hintText: 'https://…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, findUrl(controller.text)),
          child: Text(l10n.importLinkConfirm),
        ),
      ],
    ),
  );
  controller.dispose();
  if (url == null || !context.mounted) return;
  await importFromLink(context, ref, url);
}

Future<void> importFromLink(BuildContext context, WidgetRef ref, Uri url) =>
    _runImport(context, () async {
      final importer = await ref.read(linkImporterProvider.future);
      return importer.import(url);
    });

/// Shared flow: progress dialog, optional choice when several recipes were
/// found, then the review screen for each one.
Future<void> _runImport(
  BuildContext context,
  Future<List<RecipeDraft>> Function() load, {
  String? message,
}) async {
  final l10n = context.l10n;
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
              Expanded(child: Text(message ?? l10n.importReading)),
            ],
          ),
        ),
      ),
    ),
  );
  final List<RecipeDraft> drafts;
  try {
    drafts = await load();
  } catch (e) {
    navigator.pop();
    showGlobalSnack(l10n.importFailed('$e'));
    return;
  }
  navigator.pop();
  if (!context.mounted || drafts.isEmpty) return;
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
