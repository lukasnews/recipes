/// Estimated nutrition per serving (by the AI, so only a rough guide).
class Nutrition {
  const Nutrition({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  static Nutrition? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final kcal = m['kcal'];
    if (kcal is! num) return null;
    double g(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return Nutrition(
      kcal: kcal.round(),
      protein: g('protein'),
      fat: g('fat'),
      carbs: g('carbs'),
    );
  }

  final int kcal;

  /// Grams per serving.
  final double protein;
  final double fat;
  final double carbs;

  Map<String, dynamic> toMap() => {
    'kcal': kcal,
    'protein': protein,
    'fat': fat,
    'carbs': carbs,
  };
}

/// The recipe as plain text for the AI estimate.
String nutritionPrompt({
  required String title,
  required int servings,
  required List<String> ingredientLines,
}) => [
  title,
  'Portionen: $servings',
  'Zutaten:',
  for (final l in ingredientLines) '- $l',
].join('\n');
