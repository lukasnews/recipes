import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/mealplan/domain/week_suggestion.dart';
import 'package:recipes/features/pantry/domain/frozen_meal.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/domain/cook_history.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

Recipe _r(String id, List<String> ings, {String cat = 'cooking'}) => Recipe(
  id: id,
  title: id,
  category: cat,
  ingredients: [
    for (final i in ings)
      RecipeIngredient(rawText: i, ingredientId: i, amount: 1),
  ],
);

void main() {
  const ingredients = {
    'topfen': Ingredient(id: 'topfen', name: 'Topfen'),
    'ei': Ingredient(id: 'ei', name: 'Ei'),
    'fisch': Ingredient(id: 'fisch', name: 'Fisch'),
  };
  final now = DateTime(2026, 11, 4);
  final pantry = {
    'topfen': PantryItem(
      ingredientId: 'topfen',
      amount: 5,
      expiresOn: now.add(const Duration(days: 1)),
    ),
    'ei': const PantryItem(ingredientId: 'ei', amount: 10),
  };
  final recipes = [
    _r('omelett', ['ei']),
    _r('topfenknoedel', ['topfen', 'ei']),
    _r('fischstaebchen', ['fisch']),
    _r('kipferl', ['ei'], cat: RecipeCategories.cookies),
  ];

  test('covered and expiring first, no cookies, no repeats', () {
    final s = suggestWeek(
      freeDays: ['d1', 'd2', 'd3'],
      recipes: recipes,
      ingredients: ingredients,
      pantry: pantry,
      stats: const {},
      frozen: const [],
      now: now,
    );
    expect(s.map((d) => d.title), [
      'topfenknoedel',
      'omelett',
      'fischstaebchen',
    ]);
    expect(s.map((d) => d.dayKey), ['d1', 'd2', 'd3']);
  });

  test('recently cooked goes down, planned ones are skipped', () {
    final s = suggestWeek(
      freeDays: ['d1', 'd2'],
      recipes: recipes,
      ingredients: ingredients,
      pantry: const {},
      stats: {'omelett': CookStats(1, now)},
      frozen: const [],
      now: now,
      plannedIds: {'topfenknoedel'},
    );
    expect(s.map((d) => d.title), ['fischstaebchen', 'omelett']);
  });

  test('oldest freezer dish once a week', () {
    final s = suggestWeek(
      freeDays: ['d1', 'd2', 'd3', 'd4'],
      recipes: recipes,
      ingredients: ingredients,
      pantry: pantry,
      stats: const {},
      frozen: [
        FrozenMeal(id: 'f1', title: 'Gulasch', portions: 2, frozenOn: now),
        FrozenMeal(
          id: 'f2',
          title: 'Krautfleckerl',
          portions: 1,
          frozenOn: now.subtract(const Duration(days: 60)),
        ),
      ],
      now: now,
    );
    expect(s.map((d) => d.title), [
      'topfenknoedel',
      'omelett',
      'Krautfleckerl',
      'fischstaebchen',
    ]);
  });
}
