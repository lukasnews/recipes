import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/recipes/domain/step_ingredients.dart';

void main() {
  const ingredients = {
    'ei': Ingredient(id: 'ei', name: 'Ei', synonyms: ['Eier']),
    'mehl': Ingredient(id: 'mehl', name: 'Mehl glatt', synonyms: ['Mehl']),
    'milch': Ingredient(id: 'milch', name: 'Milch'),
    'zwiebel': Ingredient(id: 'zwiebel', name: 'Zwiebel'),
    'eis': Ingredient(id: 'eis', name: 'Eis'),
    'dotter': Ingredient(
      id: 'dotter',
      name: 'Eidotter',
      synonyms: ['Dotter', 'Eigelb'],
    ),
  };
  RecipeIngredient line(String id) =>
      RecipeIngredient(rawText: id, ingredientId: id, amount: 1);
  final lines = [for (final id in ingredients.keys) line(id)];

  List<String> found(String step) => [
    for (final i in ingredientsInStep(step, lines, ingredients))
      lines[i].ingredientId!,
  ];

  test('names, synonyms and plurals', () {
    expect(found('Mehl mit der Milch und den Eiern verrühren.'), [
      'ei',
      'mehl',
      'milch',
    ]);
    expect(found('Zwiebeln fein hacken.'), ['zwiebel']);
    expect(found('Die Dotter mit Zucker schaumig rühren.'), ['dotter']);
  });

  test('short terms do not match longer words', () {
    expect(found('Mit Vanilleeis servieren.'), isEmpty);
    expect(found('Eis dazu reichen, 1 Ei aufschlagen.'), ['ei', 'eis']);
    expect(found('Eigelb unterheben.'), ['dotter']);
  });
}
