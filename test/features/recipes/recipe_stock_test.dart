import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/recipes/domain/recipe_stock.dart';

void main() {
  const flour = Ingredient(
    id: 'flour',
    name: 'Mehl glatt',
    baseUnit: BaseUnit.g,
    conversions: {'EL': 10},
  );
  const eggs = Ingredient(id: 'egg', name: 'Ei');
  const milk = Ingredient(id: 'milk', name: 'Milch', baseUnit: BaseUnit.ml);
  const salt = Ingredient(
    id: 'salt',
    name: 'Salz',
    baseUnit: BaseUnit.g,
    alwaysAvailable: true,
  );
  final ingredients = {
    for (final i in [flour, eggs, milk, salt]) i.id: i,
  };

  const pancakes = Recipe(
    id: 'r1',
    title: 'Palatschinken',
    ingredients: [
      RecipeIngredient(
        rawText: '200 g Mehl',
        ingredientId: 'flour',
        amount: 200,
        unit: 'g',
      ),
      RecipeIngredient(
        rawText: '2 EL Mehl',
        ingredientId: 'flour',
        amount: 2,
        unit: 'EL',
      ),
      RecipeIngredient(rawText: '2 Eier', ingredientId: 'egg', amount: 2),
      RecipeIngredient(
        rawText: '0,5 l Milch',
        ingredientId: 'milk',
        amount: 0.5,
        unit: 'l',
      ),
      RecipeIngredient(rawText: 'Salz', ingredientId: 'salt'),
      RecipeIngredient(rawText: 'Liebe'),
    ],
  );

  test('sums lines of the same ingredient and scales', () {
    final cov = computeCoverage(pancakes, ingredients, const {}, servings: 2);
    final flourNeed = cov.needs.firstWhere((n) => n.ingredient.id == 'flour');
    expect(flourNeed.neededBase, 110); // (200 + 20) / 2
    expect(cov.total, 4); // unlinked line ignored
  });

  test('status per ingredient and ratio', () {
    final pantry = {
      'flour': const PantryItem(ingredientId: 'flour', amount: 1000),
      'egg': const PantryItem(ingredientId: 'egg', amount: 1),
    };
    final cov = computeCoverage(pancakes, ingredients, pantry);
    final byId = {for (final n in cov.needs) n.ingredient.id: n};
    expect(byId['flour']!.status, StockStatus.available);
    expect(byId['egg']!.status, StockStatus.partial);
    expect(byId['egg']!.missingBase, 1);
    expect(byId['milk']!.status, StockStatus.missing);
    expect(byId['salt']!.status, StockStatus.available);
    expect(cov.coveredCount, 2);
    expect(cov.ratio, 0.5);
  });

  test('rankByCoverage sorts by ratio then missing count', () {
    const a = Recipe(
      id: 'a',
      title: 'A',
      ingredients: [
        RecipeIngredient(
          rawText: 'x',
          ingredientId: 'milk',
          amount: 1,
          unit: 'l',
        ),
      ],
    );
    const b = Recipe(
      id: 'b',
      title: 'B',
      ingredients: [
        RecipeIngredient(rawText: 'x', ingredientId: 'egg', amount: 1),
      ],
    );
    const c = Recipe(
      id: 'c',
      title: 'C',
      ingredients: [
        RecipeIngredient(
          rawText: 'x',
          ingredientId: 'milk',
          amount: 1,
          unit: 'l',
        ),
        RecipeIngredient(
          rawText: 'y',
          ingredientId: 'flour',
          amount: 1,
          unit: 'kg',
        ),
      ],
    );
    final pantry = {'egg': const PantryItem(ingredientId: 'egg', amount: 6)};
    final ranked = rankByCoverage([
      for (final r in [a, b, c]) computeCoverage(r, ingredients, pantry),
    ]);
    expect(ranked.map((r) => r.recipe.id), ['b', 'a', 'c']);
  });

  test('plannedDeductions skips always-available and unknown amounts', () {
    final d = plannedDeductions(pancakes, ingredients);
    expect(
      {for (final x in d) x.ingredient.id: x.amountBase},
      {'flour': 220, 'egg': 2, 'milk': 500},
    );
  });

  test('clampDeduction never goes below zero', () {
    expect(clampDeduction(200, 500), 200);
    expect(clampDeduction(200, 50), 50);
    expect(clampDeduction(200, null), 0);
    expect(clampDeduction(-5, 50), 0);
  });
}
