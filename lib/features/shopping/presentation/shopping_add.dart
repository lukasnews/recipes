import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/firebase/fire.dart';
import '../../../core/units/ingredient_line_parser.dart';
import '../../ingredients/domain/ingredient.dart';
import '../domain/shopping_item.dart';

/// A typed or scanned line and the ingredient it belongs to. Only a
/// certain match links; free text like "Spülmittel" stays as is.
({ParsedIngredientLine parsed, Ingredient? ingredient}) resolveShoppingLine(
  WidgetRef ref,
  String text,
) {
  final parsed = parseIngredientLine(text);
  final match = ref.read(ingredientMatcherProvider).match(parsed.name);
  final ing = match.isMatch && !match.isUncertain
      ? ref.read(ingredientsByIdProvider)[match.id]
      : null;
  return (parsed: parsed, ingredient: ing);
}

/// Open item of the same ingredient: the amount is added to it.
ShoppingItem? openItemFor(Ingredient? ing, List<ShoppingItem> items) =>
    ing == null
    ? null
    : items.where((i) => !i.checked && i.ingredientId == ing.id).firstOrNull;

/// Adds [text] to the shopping list (merged with an open item of the same
/// ingredient, see ShoppingRepository.add).
void addShoppingLine(WidgetRef ref, String text) {
  final (:parsed, :ingredient) = resolveShoppingLine(ref, text);
  fire(
    ref
        .read(shoppingRepositoryProvider)
        .add(
          text: ingredient?.name ?? parsed.name,
          current: ref.read(shoppingProvider).value ?? const [],
          ingredientId: ingredient?.id,
          amount: parsed.amount,
          unit: parsed.unit ?? (parsed.amount != null ? 'Stk.' : null),
          aisle: ingredient?.aisle ?? Aisle.other,
        ),
  );
}
