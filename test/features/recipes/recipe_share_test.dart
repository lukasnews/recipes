import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/display_units.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/recipes/domain/recipe_share.dart';

import '../../helpers/fakes.dart';

const _recipe = Recipe(
  id: 'r',
  title: 'Palatschinken',
  servings: 2,
  ingredients: [
    RecipeIngredient(
      rawText: '250 g Mehl',
      name: 'Mehl',
      amount: 250,
      unit: 'g',
    ),
    RecipeIngredient(rawText: 'Salz', name: 'Salz', note: 'eine Prise'),
  ],
  steps: [RecipeStep('Verrühren.'), RecipeStep('Backen.')],
  sourceType: 'url',
  sourceUrl: 'https://example.org/p',
);

final ShareLabels _labels = (
  servings: (n) => '$n Portionen',
  ingredients: 'Zutaten',
  steps: 'Zubereitung',
);

void main() {
  test('share text scales and converts units', () {
    final text = recipeShareText(
      _recipe,
      labels: _labels,
      ingredients: const {},
      display: UnitDisplay.austrian,
      servings: 4,
    );
    expect(text, '''
Palatschinken
4 Portionen

Zutaten:
• 50 dag Mehl
• Salz, eine Prise

Zubereitung:
1. Verrühren.
2. Backen.

https://example.org/p''');
  });

  testWidgets('share button in the recipe detail', (tester) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(_recipe, isNew: true);
    final sharer = FakeSharer();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        sharer: sharer,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Palatschinken'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rezept teilen'));
    await tester.pump();
    expect(sharer.texts.single, startsWith('Palatschinken\n2 Portionen'));
  });
}
