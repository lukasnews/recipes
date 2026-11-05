import '../../ingredients/domain/ingredient.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_stock.dart';

/// What the planned recipes still need beyond the pantry.
class ShoppingNeed {
  const ShoppingNeed(this.ingredient, this.missingBase);

  final Ingredient ingredient;

  /// Missing amount in the base unit; null if the amount is unknown
  /// (no amount in the recipe or no conversion) and nothing is in stock.
  final double? missingBase;
}

/// Sums the needs of all [planned] recipes (a recipe planned twice counts
/// twice) and subtracts the pantry once. Always-available items are skipped.
List<ShoppingNeed> weekShoppingNeeds(
  Iterable<Recipe> planned,
  Map<String, Ingredient> ingredients,
  Map<String, PantryItem> pantry,
) {
  final needed = <String, double>{};
  final unknown = <String>{};
  for (final r in planned) {
    final direct = <String, double>{};
    for (final n in computeCoverage(r, ingredients, const {}).needs) {
      if (n.ingredient.alwaysAvailable) continue;
      direct[n.ingredient.id] = n.neededBase;
      final ownStock = pantry[n.ingredient.id]?.amount ?? 0;
      if ((n.neededBase <= 0 || n.hasUnconvertible) && ownStock <= 0) {
        // Unknown amount of a part: buy its whole.
        unknown.add((wholeOf(n.ingredient, ingredients) ?? n.ingredient).id);
      }
    }
    // Per recipe, so parts of one whole share it (4 Eiweiß + 4 Dotter).
    for (final e in resolveParts(direct, ingredients, pantry).entries) {
      needed[e.key] = (needed[e.key] ?? 0) + e.value;
    }
    for (final id in unknown) {
      needed.putIfAbsent(id, () => 0);
    }
  }
  final result = <ShoppingNeed>[];
  for (final e in needed.entries) {
    final ing = ingredients[e.key]!;
    final have = pantry[e.key]?.amount ?? 0;
    if (e.value > 0) {
      final missing = e.value - have;
      if (missing > 1e-9) result.add(ShoppingNeed(ing, missing));
    } else if (unknown.contains(e.key) && have <= 0) {
      result.add(ShoppingNeed(ing, null));
    }
  }
  result.sort(
    (a, b) => a.ingredient.aisle.index != b.ingredient.aisle.index
        ? a.ingredient.aisle.index - b.ingredient.aisle.index
        : a.ingredient.name.compareTo(b.ingredient.name),
  );
  return result;
}
