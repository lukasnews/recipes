import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../shopping/domain/shopping_item.dart';
import 'recipe.dart';

enum StockStatus { available, partial, missing, unknown }

/// What the recipe needs of one ingredient, in its base unit.
class IngredientNeed {
  const IngredientNeed({
    required this.ingredient,
    required this.neededBase,
    required this.haveBase,
    this.hasUnconvertible = false,
  });

  final Ingredient ingredient;

  /// Sum of all convertible amounts (0 if none had an amount).
  final double neededBase;
  final double haveBase;

  /// A line had an amount whose unit can't be converted.
  final bool hasUnconvertible;

  double get missingBase => neededBase > haveBase ? neededBase - haveBase : 0;

  StockStatus get status {
    if (ingredient.alwaysAvailable) return StockStatus.available;
    if (neededBase <= 0 || hasUnconvertible) {
      // Amount unknown: having any stock counts as available.
      return haveBase > 0 ? StockStatus.available : StockStatus.missing;
    }
    if (haveBase >= neededBase - 1e-9) return StockStatus.available;
    return haveBase > 0 ? StockStatus.partial : StockStatus.missing;
  }

  bool get isCovered => status == StockStatus.available;
}

class RecipeCoverage {
  const RecipeCoverage(this.recipe, this.needs);

  final Recipe recipe;
  final List<IngredientNeed> needs;

  int get total => needs.length;
  int get coveredCount => needs.where((n) => n.isCovered).length;
  List<IngredientNeed> get missing => needs.where((n) => !n.isCovered).toList();

  /// Share of covered ingredients, 1.0 for recipes without linked ingredients.
  double get ratio => total == 0 ? 1 : coveredCount / total;

  /// How many of [expiring] ingredient ids this recipe uses.
  int usesExpiring(Set<String> expiring) =>
      needs.where((n) => expiring.contains(n.ingredient.id)).length;
}

/// Aggregates the needs of a recipe scaled to [servings].
RecipeCoverage computeCoverage(
  Recipe recipe,
  Map<String, Ingredient> ingredients,
  Map<String, PantryItem> pantry, {
  int? servings,
}) {
  final target = servings ?? recipe.servings;
  final needed = <String, double>{};
  final unconvertible = <String>{};
  for (final line in recipe.ingredients) {
    final id = line.ingredientId;
    final ing = id == null ? null : ingredients[id];
    if (ing == null) continue;
    needed.putIfAbsent(ing.id, () => 0);
    final amount = line.amount;
    if (amount == null) continue;
    final base = ing.toBase(
      scaleAmount(amount, recipe.servings, target),
      line.unit,
    );
    if (base == null) {
      unconvertible.add(ing.id);
    } else {
      needed[ing.id] = needed[ing.id]! + base;
    }
  }
  return RecipeCoverage(recipe, [
    for (final e in needed.entries)
      IngredientNeed(
        ingredient: ingredients[e.key]!,
        neededBase: e.value,
        haveBase: pantry[e.key]?.amount ?? 0,
        hasUnconvertible: unconvertible.contains(e.key),
      ),
  ]);
}

/// "Was kann ich kochen?": covered share descending, then most soon-expiring
/// ingredients used up ([expiring] ids), then fewest missing.
List<RecipeCoverage> rankByCoverage(
  Iterable<RecipeCoverage> list, {
  Set<String> expiring = const {},
}) => list.toList()
  ..sort((a, b) {
    final r = b.ratio.compareTo(a.ratio);
    if (r != 0) return r;
    final e = b.usesExpiring(expiring).compareTo(a.usesExpiring(expiring));
    if (e != 0) return e;
    return a.missing.length.compareTo(b.missing.length);
  });

/// One planned pantry deduction for the "cooked" dialog.
class Deduction {
  const Deduction({required this.ingredient, required this.amountBase});

  final Ingredient ingredient;
  final double amountBase;
}

/// Planned deductions for cooking [recipe] with [servings].
/// Skips always-available ingredients and amounts without conversion.
List<Deduction> plannedDeductions(
  Recipe recipe,
  Map<String, Ingredient> ingredients, {
  int? servings,
}) {
  final cov = computeCoverage(
    recipe,
    ingredients,
    const {},
    servings: servings,
  );
  return [
    for (final n in cov.needs)
      if (!n.ingredient.alwaysAvailable && n.neededBase > 0)
        Deduction(ingredient: n.ingredient, amountBase: n.neededBase),
  ];
}

/// Clamps a deduction so stock never drops below zero.
double clampDeduction(double requested, double? stock) {
  final have = stock ?? 0;
  if (requested <= 0) return 0;
  return requested > have ? have : requested;
}

/// True when "Fehlendes einkaufen" was already used for [recipeId]: an open
/// item came from it, or every missing ingredient is already open on the
/// list (merged items keep the first recipe id).
bool alreadyOnList(
  String recipeId,
  List<IngredientNeed> missing,
  List<ShoppingItem> shopping,
) {
  final open = shopping.where((i) => !i.checked);
  if (open.any((i) => i.fromRecipeId == recipeId)) return true;
  if (missing.isEmpty) return false;
  final openIds = {for (final i in open) ?i.ingredientId};
  return missing.every((n) => openIds.contains(n.ingredient.id));
}
