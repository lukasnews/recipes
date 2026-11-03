import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/ingredients/data/ingredient_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/shopping/data/shopping_repository.dart';

void main() {
  test('merge Sahne into Schlagobers re-links everything', () async {
    final db = FakeFirebaseFirestore();
    final ingredients = IngredientRepository(db, 'h1');
    final recipes = RecipeRepository(db, 'h1');
    final shopping = ShoppingRepository(db, 'h1', 'u1');

    const obers = Ingredient(
      id: 'obers',
      name: 'Schlagobers',
      baseUnit: BaseUnit.ml,
      aisle: Aisle.dairy,
    );
    const sahne = Ingredient(
      id: 'sahne',
      name: 'Sahne',
      synonyms: ['Schlagsahne'],
      baseUnit: BaseUnit.ml,
      conversions: {'Becher': 200},
    );
    await ingredients.save(obers);
    await ingredients.save(sahne);
    await recipes.save(
      const Recipe(
        id: 'r1',
        title: 'Torte',
        ingredients: [
          RecipeIngredient(rawText: '200 ml Sahne', ingredientId: 'sahne'),
          RecipeIngredient(rawText: 'Zucker', ingredientId: 'zucker'),
        ],
      ),
      isNew: true,
    );
    await db.doc('households/h1/pantry/obers').set({'amount': 100});
    await db.doc('households/h1/pantry/sahne').set({'amount': 250});
    await shopping.add(
      text: 'Sahne',
      current: const [],
      ingredientId: 'sahne',
      amount: 1,
      unit: 'Becher',
    );

    await ingredients.merge(
      source: sahne,
      target: obers,
      recipes: await recipes.watchAll().first,
      sourcePantry: const PantryItem(ingredientId: 'sahne', amount: 250),
      shopping: await shopping.watchAll().first,
    );

    final all = await ingredients.watchAll().first;
    expect(all.map((i) => i.id), ['obers']);
    expect(all.single.synonyms, containsAll(['Sahne', 'Schlagsahne']));
    expect(all.single.conversions['Becher'], 200);

    final r = (await recipes.watchAll().first).single;
    expect(r.ingredients.first.ingredientId, 'obers');
    expect(r.ingredientIds, containsAll(['obers', 'zucker']));
    expect(r.ingredientIds, isNot(contains('sahne')));

    expect(
      (await db.doc('households/h1/pantry/obers').get()).data()!['amount'],
      350,
    );
    expect((await db.doc('households/h1/pantry/sahne').get()).exists, isFalse);

    final item = (await shopping.watchAll().first).single;
    expect(item.ingredientId, 'obers');
    expect(item.aisle, Aisle.dairy);
  });
}
