import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/household/data/member_repository.dart';
import 'package:recipes/features/household/domain/allergen.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/recipes/domain/allergen_check.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

void main() {
  const flour = Ingredient(
    id: 'mehl',
    name: 'Mehl',
    allergens: {Allergen.gluten},
  );
  const topfen = Ingredient(
    id: 'topfen',
    name: 'Topfen',
    allergens: {Allergen.milk},
  );
  const sugar = Ingredient(id: 'zucker', name: 'Zucker');
  final byId = {
    for (final i in [flour, topfen, sugar]) i.id: i,
  };
  const recipe = Recipe(
    id: 'r',
    title: 'Topfenstrudel',
    ingredients: [
      RecipeIngredient(rawText: 'Mehl', ingredientId: 'mehl'),
      RecipeIngredient(rawText: 'Topfen', ingredientId: 'topfen'),
      RecipeIngredient(rawText: 'Zucker', ingredientId: 'zucker'),
      RecipeIngredient(rawText: 'Liebe'),
    ],
  );

  test('recipe allergens are the union of its ingredients', () {
    expect(recipeAllergens(recipe, byId), {Allergen.gluten, Allergen.milk});
  });

  test('only members with matching allergies are affected', () {
    const anna = HouseholdMember(
      uid: 'a',
      displayName: 'Anna',
      allergens: {Allergen.milk},
    );
    const ben = HouseholdMember(
      uid: 'b',
      displayName: 'Ben',
      allergens: {Allergen.nuts},
    );
    const cleo = HouseholdMember(uid: 'c', displayName: 'Cleo');
    final affected = affectedMembers(recipeAllergens(recipe, byId), [
      anna,
      ben,
      cleo,
    ]);
    expect(affected.map((e) => e.$1.displayName), ['Anna']);
    expect(affected.single.$2, {Allergen.milk});
  });

  test('ingredient allergens survive a Firestore round trip', () {
    final back = Ingredient.fromMap('topfen', topfen.toMap());
    expect(back.allergens, {Allergen.milk});
  });

  test('members store their own allergies', () async {
    final db = FakeFirebaseFirestore();
    final repo = MemberRepository(db, 'h1');
    await repo.ensure('a', 'Anna');
    await repo.setAllergens('a', {Allergen.milk, Allergen.gluten});
    final m = (await repo.watchAll().first).single;
    expect(m.displayName, 'Anna');
    expect(m.allergens, {Allergen.milk, Allergen.gluten});
  });

  test(
    'seed backfill adds allergens once, skips deleted ingredients',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('households/h1').set({
        'memberIds': ['a'],
      });
      await db.doc('households/h1/ingredients/topfen').set({'name': 'Topfen'});
      final repo = HouseholdRepository(db);
      await repo.backfillSeed('h1', [topfen, flour]);
      final t = await db.doc('households/h1/ingredients/topfen').get();
      expect(t.data()!['allergens'], ['milk']);
      expect(
        (await db.doc('households/h1/ingredients/mehl').get()).exists,
        isFalse,
      );
      expect(
        (await db.doc('households/h1').get()).data()!['seedVersion'],
        HouseholdRepository.seedVersion,
      );
    },
  );
}
