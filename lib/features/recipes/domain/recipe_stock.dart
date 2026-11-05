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

/// Needs of a recipe as written: ingredient id -> base amount (0 when no
/// line had an amount), plus ids with an amount that can't be converted.
({Map<String, double> needed, Set<String> unconvertible}) _directNeeds(
  Recipe recipe,
  Map<String, Ingredient> ingredients,
  int? servings,
) {
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
  return (needed: needed, unconvertible: unconvertible);
}

/// The whole a part comes from (Eiweiß -> Ei), if it exists.
Ingredient? wholeOf(Ingredient ing, Map<String, Ingredient> ingredients) {
  final p = ing.partOf;
  if (p == null || p.id == ing.id) return null;
  return ingredients[p.id];
}

/// What actually leaves the pantry: a part (Eiweiß, Zitronensaft) is taken
/// from its own stock first, the rest from its whole. Parts of the same
/// whole share it (4 Eiweiß + 4 Dotter = 4 Eier, not 8), and a whole
/// counted in pieces is rounded up (30 ml Zitronensaft = 1 Zitrone).
Map<String, double> resolveParts(
  Map<String, double> needed,
  Map<String, Ingredient> ingredients,
  Map<String, PantryItem> pantry,
) {
  final result = <String, double>{};
  final fromParts = <String, double>{};
  for (final e in needed.entries) {
    final ing = ingredients[e.key];
    final whole = ing == null ? null : wholeOf(ing, ingredients);
    if (ing == null || whole == null) {
      result[e.key] = (result[e.key] ?? 0) + e.value;
      continue;
    }
    final own = pantry[ing.id]?.amount ?? 0;
    final take = e.value < own ? e.value : own;
    if (take > 0) result[ing.id] = (result[ing.id] ?? 0) + take;
    final rest = e.value - take;
    if (rest <= 1e-9) continue;
    var forWhole = rest * ing.partOf!.per;
    if (whole.baseUnit == BaseUnit.pcs) {
      forWhole = (forWhole - 1e-9).ceilToDouble();
    }
    final prev = fromParts[whole.id] ?? 0;
    if (forWhole > prev) fromParts[whole.id] = forWhole;
  }
  for (final e in fromParts.entries) {
    result[e.key] = (result[e.key] ?? 0) + e.value;
  }
  return result;
}

/// Aggregates the needs of a recipe scaled to [servings]. A part (Eiweiß)
/// counts as available when its own stock or the whole's stock left over
/// by the recipe covers it.
RecipeCoverage computeCoverage(
  Recipe recipe,
  Map<String, Ingredient> ingredients,
  Map<String, PantryItem> pantry, {
  int? servings,
}) {
  final (:needed, :unconvertible) = _directNeeds(recipe, ingredients, servings);
  double have(Ingredient ing) {
    final own = pantry[ing.id]?.amount ?? 0;
    final whole = wholeOf(ing, ingredients);
    if (whole == null) return own;
    final spare = (pantry[whole.id]?.amount ?? 0) - (needed[whole.id] ?? 0);
    return spare > 0 ? own + spare / ing.partOf!.per : own;
  }

  return RecipeCoverage(recipe, [
    for (final e in needed.entries)
      IngredientNeed(
        ingredient: ingredients[e.key]!,
        neededBase: e.value,
        haveBase: have(ingredients[e.key]!),
        hasUnconvertible: unconvertible.contains(e.key),
      ),
  ]);
}

/// What to buy for [recipe] beyond the pantry, parts bought as their whole
/// (missing Eiweiß -> Eier, Zitronensaft -> Zitronen). [missingBase] null
/// = amount unknown and nothing in stock.
List<({Ingredient ingredient, double? missingBase})> missingToBuy(
  Recipe recipe,
  Map<String, Ingredient> ingredients,
  Map<String, PantryItem> pantry, {
  int? servings,
}) {
  final (:needed, :unconvertible) = _directNeeds(recipe, ingredients, servings);
  final known = {
    for (final e in needed.entries)
      if (e.value > 0) e.key: e.value,
  };
  final resolved = resolveParts(known, ingredients, pantry);
  final result = <({Ingredient ingredient, double? missingBase})>[];
  for (final e in resolved.entries) {
    final ing = ingredients[e.key];
    if (ing == null || ing.alwaysAvailable) continue;
    final missing = e.value - (pantry[e.key]?.amount ?? 0);
    if (missing > 1e-9) result.add((ingredient: ing, missingBase: missing));
  }
  // Unknown amounts: buy (the whole) only when nothing is in stock.
  for (final e in needed.entries) {
    if (e.value > 0 && !unconvertible.contains(e.key)) continue;
    final ing = ingredients[e.key]!;
    if (ing.alwaysAvailable || (pantry[ing.id]?.amount ?? 0) > 0) continue;
    final buy = wholeOf(ing, ingredients) ?? ing;
    if ((pantry[buy.id]?.amount ?? 0) > 0) continue;
    if (result.any((r) => r.ingredient.id == buy.id)) continue;
    result.add((ingredient: buy, missingBase: null));
  }
  return result;
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

/// Planned deductions for cooking [recipe] with [servings]; parts beyond
/// their own stock come out of their whole (see [resolveParts]).
/// Skips always-available ingredients and amounts without conversion.
List<Deduction> plannedDeductions(
  Recipe recipe,
  Map<String, Ingredient> ingredients, {
  int? servings,
  Map<String, PantryItem> pantry = const {},
}) {
  final (:needed, unconvertible: _) = _directNeeds(
    recipe,
    ingredients,
    servings,
  );
  final resolved = resolveParts(needed, ingredients, pantry);
  return [
    for (final e in resolved.entries)
      if (ingredients[e.key] case final ing?
          when !ing.alwaysAvailable && e.value > 0)
        Deduction(ingredient: ing, amountBase: e.value),
  ];
}

/// Units in [recipe] that a linked ingredient can't convert yet
/// (e.g. "g" for Schlagobers kept in ml): ingredient id -> units.
Map<String, Set<String>> unconvertibleUnits(
  Recipe recipe,
  Map<String, Ingredient> ingredients,
) {
  final result = <String, Set<String>>{};
  for (final line in recipe.ingredients) {
    final ing = ingredients[line.ingredientId];
    final unit = line.unit;
    if (ing == null || ing.alwaysAvailable || line.amount == null) continue;
    if (unit == null || ing.toBase(line.amount!, unit) != null) continue;
    result.putIfAbsent(ing.id, () => {}).add(unit);
  }
  return result;
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
  Iterable<String> missingIds,
  List<ShoppingItem> shopping,
) {
  final open = shopping.where((i) => !i.checked);
  if (open.any((i) => i.fromRecipeId == recipeId)) return true;
  if (missingIds.isEmpty) return false;
  final openIds = {for (final i in open) ?i.ingredientId};
  return missingIds.every(openIds.contains);
}
