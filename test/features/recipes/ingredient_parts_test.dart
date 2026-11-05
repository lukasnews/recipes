import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/mealplan/domain/week_shopping.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/recipes/domain/recipe_stock.dart';

import '../../helpers/fakes.dart';

const ei = Ingredient(id: 'ei', name: 'Ei', pieceGrams: 60);
const eiweiss = Ingredient(
  id: 'eiweiss',
  name: 'Eiweiß',
  pieceGrams: 30,
  partOf: PartOf('ei', 1),
);
const dotter = Ingredient(
  id: 'eidotter',
  name: 'Eidotter',
  pieceGrams: 20,
  partOf: PartOf('ei', 1),
);
const zitrone = Ingredient(id: 'zitrone', name: 'Zitrone');
const saft = Ingredient(
  id: 'zitronensaft',
  name: 'Zitronensaft',
  baseUnit: BaseUnit.ml,
  conversions: {'EL': 15},
  partOf: PartOf('zitrone', 0.025),
);
final all = {
  for (final i in [ei, eiweiss, dotter, zitrone, saft]) i.id: i,
};

Map<String, PantryItem> stock(Map<String, double> m) => {
  for (final e in m.entries)
    e.key: PantryItem(ingredientId: e.key, amount: e.value),
};

void main() {
  const biskuit = Recipe(
    id: 'b',
    title: 'Biskuit',
    ingredients: [
      RecipeIngredient(rawText: '4 Eiweiß', ingredientId: 'eiweiss', amount: 4),
      RecipeIngredient(
        rawText: '4 Dotter',
        ingredientId: 'eidotter',
        amount: 4,
      ),
    ],
  );

  test('parts of one whole share it: 4 Eiweiß + 4 Dotter = 4 Eier', () {
    expect(resolveParts({'eiweiss': 4, 'eidotter': 2}, all, const {}), {
      'ei': 4,
    });
    expect(
      resolveParts({'eiweiss': 4, 'eidotter': 4, 'ei': 2}, all, const {}),
      {'ei': 6},
    );
  });

  test('own stock of a part first; pieces of the whole rounded up', () {
    expect(
      resolveParts({'zitronensaft': 30}, all, stock({'zitronensaft': 20})),
      {'zitronensaft': 20, 'zitrone': 1},
    );
    expect(resolveParts({'zitronensaft': 60}, all, const {}), {'zitrone': 2});
  });

  test('coverage: Eiweiß and Dotter covered by eggs in stock', () {
    final cov = computeCoverage(biskuit, all, stock({'ei': 4}));
    expect(cov.coveredCount, 2);
    final few = computeCoverage(biskuit, all, stock({'ei': 2}));
    expect(few.needs.every((n) => n.status == StockStatus.partial), isTrue);
  });

  test('cooking deducts eggs, buying missing adds eggs', () {
    final d = plannedDeductions(biskuit, all, pantry: stock({'ei': 10}));
    expect([for (final x in d) (x.ingredient.id, x.amountBase)], [('ei', 4.0)]);

    final buy = missingToBuy(biskuit, all, stock({'ei': 1}));
    expect(
      [for (final x in buy) (x.ingredient.id, x.missingBase)],
      [('ei', 3.0)],
    );

    const lemonade = Recipe(
      id: 'l',
      title: 'Dressing',
      servings: 2,
      ingredients: [
        RecipeIngredient(
          rawText: '2 EL Zitronensaft',
          ingredientId: 'zitronensaft',
          amount: 2,
          unit: 'EL',
        ),
      ],
    );
    final lemons = missingToBuy(lemonade, all, const {});
    expect(
      [for (final x in lemons) (x.ingredient.id, x.missingBase)],
      [('zitrone', 1.0)],
    );
  });

  test('week: each recipe shares its eggs, recipes add up', () {
    final needs = weekShoppingNeeds([biskuit, biskuit], all, stock({'ei': 2}));
    expect(
      [for (final n in needs) (n.ingredient.id, n.missingBase)],
      [('ei', 6.0)],
    );
  });

  test('backfill v5 links a self-made "Eiweiß" and adds the rest', () async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final h = db.collection('households').doc(hid);
    await h.update({'seedVersion': 4});
    final ingredients = h.collection('ingredients');
    await ingredients
        .doc('ei')
        .set(const Ingredient(id: 'ei', name: 'Ei').toMap());
    await ingredients.doc('own1').set({
      'name': 'Eiweiß',
      'synonyms': <String>[],
      'baseUnit': 'g',
      'aisle': 'other',
    });
    await HouseholdRepository(db).backfillSeed(hid, [ei, eiweiss, dotter]);
    final own = (await ingredients.doc('own1').get()).data()!;
    // Kept in grams: 1 g Eiweiß = 1/30 Ei.
    expect(own['partOf'], {'id': 'ei', 'per': 1 / 30});
    expect((await ingredients.doc('eiweiss').get()).exists, isFalse);
    final added = (await ingredients.doc('eidotter').get()).data()!;
    expect(added['partOf'], {'id': 'ei', 'per': 1.0});
  });
}
