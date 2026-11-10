/// One replacement for a missing ingredient, suggested by the AI.
class Substitute {
  const Substitute({
    required this.replacement,
    this.note = '',
    this.fromPantry = false,
  });

  factory Substitute.fromMap(Map<String, dynamic> m) => Substitute(
    replacement: '${m['replacement'] ?? ''}'.trim(),
    note: '${m['note'] ?? ''}'.trim(),
    fromPantry: m['fromPantry'] == true,
  );

  /// With amount: "150 ml Milch + 1 EL Zitronensaft".
  final String replacement;

  /// What changes ("etwas weniger säuerlich").
  final String note;

  /// Uses only things from the household's pantry.
  final bool fromPantry;
}

/// Prompt text for [RecipeExtractor.suggestSubstitutes].
String substitutePrompt({
  required String title,
  required String missingLine,
  required List<String> otherLines,
}) => [
  'Rezept: $title',
  'Fehlende Zutat: $missingLine',
  'Andere Zutaten: ${otherLines.join('; ')}',
].join('\n');
