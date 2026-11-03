import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';

void main() {
  const paradeiser = Ingredient(
    id: 'paradeiser',
    name: 'Paradeiser',
    synonyms: ['Tomaten', 'Tomate', 'Paradeis'],
  );

  test('preferred synonym becomes the name, old name a synonym', () {
    final t = paradeiser.withPreferredName('Tomate');
    expect(t.id, 'paradeiser');
    expect(t.name, 'Tomate');
    expect(t.synonyms, ['Paradeiser', 'Tomaten', 'Paradeis']);
  });

  test('all terms still match after switching', () {
    final t = paradeiser.withPreferredName('Tomate');
    final m = IngredientMatcher([t.candidate]);
    for (final term in ['Paradeiser', 'Tomaten', 'Tomate', 'Paradeis']) {
      expect(m.match(term).id, 'paradeiser', reason: term);
    }
  });

  test('same name or empty is a no-op', () {
    expect(paradeiser.withPreferredName('paradeiser'), same(paradeiser));
    expect(paradeiser.withPreferredName(' '), same(paradeiser));
  });
}
