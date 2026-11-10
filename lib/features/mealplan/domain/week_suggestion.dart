import 'dart:math';

import '../../ingredients/domain/ingredient.dart';
import '../../pantry/domain/frozen_meal.dart';
import '../../pantry/domain/pantry_item.dart';
import '../../recipes/domain/cook_history.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_stock.dart';

/// One suggested day: a recipe or a dish from the freezer.
class DaySuggestion {
  const DaySuggestion(this.dayKey, {this.recipe, this.frozen});

  final String dayKey;
  final Recipe? recipe;
  final FrozenMeal? frozen;

  String get title => recipe?.title ?? frozen!.title;
}

/// Fills [freeDays] (day keys, in order) with main dishes: what the pantry
/// covers, uses up soon-expiring items, hasn't been cooked for a while and
/// is rated well. One freezer dish (oldest first) per week. Recipes already
/// in [plannedIds] and cookies/cakes are skipped; no recipe twice.
List<DaySuggestion> suggestWeek({
  required List<String> freeDays,
  required Iterable<Recipe> recipes,
  required Map<String, Ingredient> ingredients,
  required Map<String, PantryItem> pantry,
  required Map<String, CookStats> stats,
  required List<FrozenMeal> frozen,
  required DateTime now,
  Set<String> plannedIds = const {},
  Set<String> plannedFrozenIds = const {},
}) {
  if (freeDays.isEmpty) return const [];
  final expiring = expiringIds(pantry, now);
  final scored = <(Recipe, double, int)>[];
  for (final r in recipes) {
    if (RecipeCategories.notMeals.contains(r.category) ||
        r.category == RecipeCategories.cake ||
        plannedIds.contains(r.id)) {
      continue;
    }
    final cov = computeCoverage(r, ingredients, pantry);
    final usesExpiring = cov.usesExpiring(expiring);
    final last = stats[r.id]?.lastCooked;
    final staleness = last == null
        ? 1.0
        : min(2, daysBetween(last, now) / 30).toDouble();
    final score = cov.ratio * 3 + usesExpiring * 2 + staleness + r.rating * 0.2;
    scored.add((r, score, usesExpiring));
  }
  scored.sort((a, b) {
    final s = b.$2.compareTo(a.$2);
    return s != 0 ? s : a.$1.title.compareTo(b.$1.title);
  });

  final freezer =
      frozen
          .where((m) => m.portions > 0 && !plannedFrozenIds.contains(m.id))
          .toList()
        ..sort((a, b) => a.frozenOn.compareTo(b.frozenOn));
  final useFrozen = freezer.isNotEmpty && plannedFrozenIds.isEmpty;
  final recipeSlots = freeDays.length - (useFrozen ? 1 : 0);
  // Recipes using soon-expiring items go first in the week.
  final picked = scored.take(recipeSlots).toList()
    ..sort((a, b) => b.$3.compareTo(a.$3));

  final result = <DaySuggestion>[];
  var r = 0;
  for (final (i, day) in freeDays.indexed) {
    // Freezer dish mid-week (or on the only free day).
    final frozenHere =
        useFrozen &&
        (i == min(2, freeDays.length - 1) || r >= picked.length) &&
        !result.any((s) => s.frozen != null);
    if (frozenHere) {
      result.add(DaySuggestion(day, frozen: freezer.first));
    } else if (r < picked.length) {
      result.add(DaySuggestion(day, recipe: picked[r++].$1));
    }
  }
  return result;
}
