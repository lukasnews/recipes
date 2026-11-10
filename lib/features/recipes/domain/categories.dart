import 'recipe.dart';

/// All categories in the household's order: its own order first (also
/// categories without recipes), then built-ins and categories that only
/// appear on recipes, not ordered yet (built-in order, then A–Z).
List<String> allCategories({
  List<String>? order,
  required Iterable<Recipe> recipes,
}) {
  final result = <String>[...?order];
  for (final c in RecipeCategories.builtIn) {
    if (!result.contains(c)) result.add(c);
  }
  final custom = {
    for (final r in recipes)
      if (!result.contains(r.category)) r.category,
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [...result, ...custom];
}

/// Shown as chips and in the editor; [RecipeCategories.cooking] is never
/// hidden (it is where deleted categories' recipes go).
List<String> visibleCategories(List<String> all, Set<String> hidden) => [
  for (final c in all)
    if (c == RecipeCategories.cooking || !hidden.contains(c)) c,
];

/// Recipe count per category.
Map<String, int> categoryCounts(Iterable<Recipe> recipes) {
  final counts = <String, int>{};
  for (final r in recipes) {
    counts[r.category] = (counts[r.category] ?? 0) + 1;
  }
  return counts;
}
