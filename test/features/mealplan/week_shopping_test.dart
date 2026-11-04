import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/mealplan/domain/week_shopping.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

void main() {
  const flour = Ingredient(id: 'mehl', name: 'Mehl', baseUnit: BaseUnit.g);
  const eggs = Ingredient(id: 'ei', name: 'Ei');
  const salt = Ingredient(
    id: 'salz',
    name: 'Salz',
    baseUnit: BaseUnit.g,
    alwaysAvailable: true,
  );
  const parsley = Ingredient(id: 'petersilie', name: 'Petersilie');
  final byId = {
    for (final i in [flour, eggs, salt, parsley]) i.id: i,
  };

  const a = Recipe(
    id: 'a',
    title: 'A',
    ingredients: [
      RecipeIngredient(
        rawText: '',
        ingredientId: 'mehl',
        amount: 300,
        unit: 'g',
      ),
      RecipeIngredient(rawText: '', ingredientId: 'ei', amount: 2),
      RecipeIngredient(rawText: '', ingredientId: 'salz'),
    ],
  );
  const b = Recipe(
    id: 'b',
    title: 'B',
    ingredients: [
      RecipeIngredient(
        rawText: '',
        ingredientId: 'mehl',
        amount: 200,
        unit: 'g',
      ),
      RecipeIngredient(rawText: '', ingredientId: 'petersilie'),
    ],
  );

  test('sums all planned recipes and subtracts the pantry once', () {
    final needs = weekShoppingNeeds(
      [a, b, a],
      byId,
      {
        'mehl': const PantryItem(ingredientId: 'mehl', amount: 500),
        'ei': const PantryItem(ingredientId: 'ei', amount: 1),
      },
    );
    final m = {for (final n in needs) n.ingredient.id: n.missingBase};
    expect(m['mehl'], 300);
    expect(m['ei'], 3);
    expect(m.containsKey('salz'), isFalse);
    expect(m.containsKey('petersilie'), isTrue);
    expect(m['petersilie'], isNull);
  });

  test('nothing to buy when the pantry covers everything', () {
    final needs = weekShoppingNeeds(
      [b],
      byId,
      {
        'mehl': const PantryItem(ingredientId: 'mehl', amount: 1000),
        'petersilie': const PantryItem(ingredientId: 'petersilie', amount: 1),
      },
    );
    expect(needs, isEmpty);
  });
}
