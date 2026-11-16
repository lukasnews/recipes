import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/recipe.dart';
import '../domain/recipe_pdf.dart';

/// Prints (Android print dialog, also "Als PDF speichern") or shares one
/// PDF with all [recipes] (recipe and servings, null = as in the recipe),
/// each with its first photo when cached or reachable.
Future<void> printRecipes(
  WidgetRef ref,
  AppLocalizations l10n,
  List<(Recipe, int?)> recipes, {
  required String title,
  bool share = false,
}) async {
  final items = <PdfRecipe>[];
  for (final (recipe, servings) in recipes) {
    Uint8List? photo;
    if (recipe.photoPaths.isNotEmpty) {
      try {
        photo = await ref
            .read(photoFileProvider(recipe.photoPaths.first).future)
            .then((f) => f.readAsBytes());
      } on Object {
        // Offline and not cached: this recipe comes without its photo.
      }
    }
    items.add((recipe: recipe, servings: servings, photo: photo));
  }
  final pdf = await buildRecipesPdf(
    items,
    title: title,
    labels: (
      ingredients: l10n.ingredientsTitle,
      steps: l10n.stepsTitle,
      notes: l10n.notesTitle,
      servings: l10n.servingsCount,
      prep: l10n.pdfPrep,
      cook: l10n.pdfCook,
      footer: l10n.pdfFooter,
    ),
    ingredients: ref.read(ingredientsByIdProvider),
    regularFont: await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    display: ref.read(unitDisplayProvider),
  );
  final printer = ref.read(recipePrinterProvider);
  final name = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  await (share ? printer.share(pdf, '$name.pdf') : printer.print(pdf, title));
}
