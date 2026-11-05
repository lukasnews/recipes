import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/units.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/l10n_ext.dart';
import '../../import/data/photo_picker.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/presentation/ingredient_picker.dart';
import '../../shopping/domain/pack_sizes.dart';
import '../data/barcode_repository.dart';
import '../domain/product.dart';
import 'pantry_screen.dart';

/// Photo of a barcode -> known code or Open Food Facts -> ingredient ->
/// add sheet prefilled with the package size. The code is remembered.
Future<void> scanToPantry(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final l10n = context.l10n;
  final paths = await container
      .read(photoPickerProvider)
      .pick(PhotoSource.camera, multiple: false);
  if (paths.isEmpty || !context.mounted) return;
  final code = await container.read(barcodeReaderProvider).read(paths.first);
  if (!context.mounted) return;
  if (code == null) {
    showSnack(context, l10n.barcodeNotFound);
    return;
  }
  final ingredients = container.read(ingredientsByIdProvider);
  final barcodes = container.read(barcodeRepositoryProvider);

  final known = await barcodes.get(code).catchError((_) => null);
  final knownIng = known == null ? null : ingredients[known.ingredientId];
  if (!context.mounted) return;
  if (known != null && knownIng != null) {
    await showAddSheetFor(
      context,
      IngredientChoice.existing(knownIng),
      title: known.name,
      amount: known.amount,
      unit: known.unit,
    );
    return;
  }

  Product? product;
  try {
    product = await container.read(productLookupProvider).lookup(code);
    if (product == null && context.mounted) {
      showSnack(context, l10n.productUnknown(code));
    }
  } catch (e) {
    if (context.mounted) showSnack(context, l10n.productLookupFailed);
  }
  if (!context.mounted) return;

  IngredientChoice? choice;
  final guess = product == null
      ? null
      : _guessIngredient(container, product.name, ingredients);
  if (guess != null) {
    choice = IngredientChoice.existing(guess);
  } else {
    choice = await pickIngredient(context, initialQuery: product?.name ?? '');
  }
  if (choice == null || !context.mounted) return;
  final title = product == null
      ? null
      : [?product.brand, product.name].join(' · ');
  await showAddSheetFor(
    context,
    choice,
    title: title,
    amount: product?.amount,
    unit: product?.unit,
    onSaved: (ing, amount, unit) {
      fire(
        barcodes.save(
          code,
          KnownBarcode(
            ingredientId: ing.id,
            amount: amount,
            unit: unit,
            name: title,
          ),
        ),
      );
      // The package size is a pack size worth remembering.
      final latest = container.read(ingredientsByIdProvider)[ing.id] ?? ing;
      final base = latest.toBase(
        amount,
        unit == 'Stk.' && latest.baseUnit == BaseUnit.pcs ? null : unit,
      );
      final learned = base == null
          ? null
          : learnPackSize(latest.packSizes, base);
      if (learned != null) {
        fire(
          container
              .read(ingredientRepositoryProvider)
              .setPackSizes(ing.id, learned),
        );
      }
    },
  );
}

/// Certain match on the whole product name or one of its words
/// ("Bio Vollmilch 3,5 %" -> Milch via synonym "Vollmilch").
Ingredient? _guessIngredient(
  ProviderContainer container,
  String name,
  Map<String, Ingredient> ingredients,
) {
  final matcher = container.read(ingredientMatcherProvider);
  final words = name.split(RegExp(r'[\s,/()%-]+')).where((w) => w.length > 2);
  for (final candidate in [name, ...words]) {
    final m = matcher.match(candidate);
    if (m.isMatch && !m.isUncertain) return ingredients[m.id];
  }
  return null;
}
