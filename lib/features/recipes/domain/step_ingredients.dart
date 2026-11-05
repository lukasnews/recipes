import '../../ingredients/domain/ingredient.dart';
import 'recipe.dart';

final _word = RegExp(r'[a-zäöüß]+');

/// Endings a word may have beyond an ingredient term ("Eier", "Zwiebeln",
/// "Äpfeln" stays unmatched – then the synonym "Äpfel" helps).
const _endings = {'', 'e', 'en', 'n', 's', 'er', 'es', 'ern'};

/// Indices of [lines] that [stepText] mentions, by the ingredient's name,
/// its synonyms or the line's own name. Used by the cook mode to show
/// "Dazu: 3 Eier, 200 g Mehl" under each step.
List<int> ingredientsInStep(
  String stepText,
  List<RecipeIngredient> lines,
  Map<String, Ingredient> ingredients,
) {
  final text = stepText.toLowerCase();
  final words = _word.allMatches(text).map((m) => m.group(0)!).toList();
  bool mentions(String term) {
    final t = term.toLowerCase().trim();
    if (t.isEmpty) return false;
    if (t.contains(' ')) return text.contains(t);
    for (final w in words) {
      if (!w.startsWith(t)) continue;
      final rest = w.substring(t.length);
      // Short terms ("Ei") only exactly or as plural, never "Eis".
      if (t.length < 3
          ? (rest.isEmpty || rest == 'er')
          : _endings.contains(rest)) {
        return true;
      }
    }
    return false;
  }

  return [
    for (final (i, line) in lines.indexed)
      if ([
        ?ingredients[line.ingredientId]?.name,
        ...?ingredients[line.ingredientId]?.synonyms,
        ?line.name,
      ].any(mentions))
        i,
  ];
}
