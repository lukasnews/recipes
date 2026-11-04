import '../../../core/matching/ingredient_matcher.dart';
import 'recipe.dart';

/// Example recipes for new households (assets/seed/recipes_de.json), linked
/// to the household's ingredients. Lines: [amount, unit, name, note].
List<Recipe> sampleRecipes(
  List<Map<String, dynamic>> raw,
  IngredientMatcher matcher,
) => [
  for (final m in raw)
    Recipe(
      id: m['id'] as String,
      title: m['title'] as String,
      category: m['category'] as String? ?? RecipeCategories.cooking,
      servings: m['servings'] as int? ?? 4,
      prepMinutes: m['prepMinutes'] as int?,
      cookMinutes: m['cookMinutes'] as int?,
      tags: [...?(m['tags'] as List<dynamic>?)?.cast<String>()],
      ingredients: [
        for (final line
            in (m['ingredients'] as List<dynamic>).cast<List<dynamic>>())
          _line(line, matcher),
      ],
      steps: [
        for (final s in (m['steps'] as List<dynamic>).cast<String>())
          RecipeStep(s),
      ],
    ),
];

RecipeIngredient _line(List<dynamic> l, IngredientMatcher matcher) {
  final amount = (l[0] as num?)?.toDouble();
  final unit = l[1] as String?;
  final name = l[2] as String;
  final note = l.length > 3 ? l[3] as String? : null;
  final amountText = amount == null
      ? null
      : (amount == amount.roundToDouble()
            ? amount.toInt().toString()
            : amount.toString().replaceAll('.', ','));
  final match = matcher.match(name);
  return RecipeIngredient(
    rawText: [?amountText, ?unit, name, if (note != null) '($note)'].join(' '),
    // Only certain matches; a fuzzy one would show as "unsicher".
    ingredientId: match.isUncertain ? null : match.id,
    amount: amount,
    unit: unit,
    name: name,
    note: note,
  );
}
