import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/amount_scaling.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  test('factor for the available amount', () {
    expect(factorForAvailable(400, 300), 0.75);
    expect(factorForAvailable(0, 300), isNull);
    expect(factorForAvailable(400, 0), isNull);
  });

  test('stock in the unit of the line', () {
    const milch = Ingredient(id: 'milch', name: 'Milch', baseUnit: BaseUnit.ml);
    const stock = PantryItem(ingredientId: 'milch', amount: 750);
    expect(
      stockInLineUnit(
        const RecipeIngredient(rawText: '1 l Milch', amount: 1, unit: 'l'),
        milch,
        stock,
      ),
      0.75,
    );
    expect(
      stockInLineUnit(
        const RecipeIngredient(rawText: '2 Becher Milch', unit: 'Becher'),
        milch,
        stock,
      ),
      isNull,
    );
    expect(
      stockInLineUnit(
        const RecipeIngredient(rawText: '1 l Milch', unit: 'l'),
        milch,
        null,
      ),
      isNull,
    );
  });

  Future<(FakeFirebaseFirestore, String)> setUpRecipe() async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'k',
        title: 'Topfenknödel',
        ingredients: [
          RecipeIngredient(
            rawText: '400 g Mehl',
            ingredientId: 'mehl-glatt',
            amount: 400,
            unit: 'g',
            name: 'Mehl',
          ),
          RecipeIngredient(
            rawText: '200 ml Schlagobers',
            ingredientId: 'schlagobers',
            amount: 200,
            unit: 'ml',
            name: 'Schlagobers',
          ),
        ],
      ),
      isNew: true,
    );
    // The test seed has piece-based ingredients.
    await db.doc('households/$hid/ingredients/mehl-glatt').update({
      'baseUnit': 'g',
    });
    await db.doc('households/$hid/ingredients/schlagobers').update({
      'baseUnit': 'ml',
    });
    await db.doc('households/$hid/pantry/mehl-glatt').set({
      'amount': 300,
      'location': 'pantry',
    });
    return (db, hid);
  }

  testWidgets('convert the recipe to the flour in stock', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (db, _) = await setUpRecipe();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topfenknödel'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('400 g Mehl glatt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nach vorhandener Menge umrechnen'));
    await tester.pumpAndSettle();
    // Prefilled with the stock.
    expect(find.text('300'), findsOneWidget);
    await tester.tap(find.text('Umrechnen'));
    await tester.pumpAndSettle();

    expect(find.text('Umgerechnet auf 300 g Mehl glatt'), findsOneWidget);
    expect(find.text('ergibt ca. 3 Portionen'), findsOneWidget);
    expect(find.text('300 g Mehl glatt'), findsOneWidget);
    expect(find.text('150 ml Schlagobers'), findsOneWidget);

    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('400 g Mehl glatt'), findsOneWidget);
  });

  testWidgets('AI substitutes for a missing ingredient', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (db, _) = await setUpRecipe();
    final extractor = FakeExtractor(const []);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        extractor: extractor,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topfenknödel'));
    await tester.pumpAndSettle();

    // Flour is short and Schlagobers missing: both offer the swap icon.
    await tester.tap(find.byTooltip('Ersatz vorschlagen (KI)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ersatz vorschlagen (KI)').last);
    await tester.pumpAndSettle();

    expect(find.text('Statt 200 ml Schlagobers'), findsOneWidget);
    expect(find.text('150 ml Milch + 1 EL Zitronensaft'), findsOneWidget);
    expect(find.textContaining('Im Vorrat'), findsOneWidget);
    expect(extractor.lastSubstituteText, contains('200 ml Schlagobers'));
    expect(extractor.lastSubstitutePantry, ['Mehl glatt']);
  });
}
