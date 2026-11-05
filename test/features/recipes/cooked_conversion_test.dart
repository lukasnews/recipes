import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/pantry/data/pantry_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/recipes/domain/recipe_stock.dart';

import '../../helpers/fakes.dart';

void main() {
  test('unconvertibleUnits finds g for an ingredient kept in ml', () {
    const cream = Ingredient(
      id: 'schlagobers',
      name: 'Schlagobers',
      baseUnit: BaseUnit.ml,
    );
    const recipe = Recipe(
      id: 'r',
      title: 'Torte',
      ingredients: [
        RecipeIngredient(
          rawText: '50 g Schlag',
          ingredientId: 'schlagobers',
          amount: 50,
          unit: 'g',
        ),
        RecipeIngredient(
          rawText: '100 ml Schlag',
          ingredientId: 'schlagobers',
          amount: 100,
          unit: 'ml',
        ),
      ],
    );
    expect(unconvertibleUnits(recipe, {'schlagobers': cream}), {
      'schlagobers': {'g'},
    });
  });

  testWidgets('cooked: asks once for g → ml, then deducts 50 ml', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final ings = db.collection('households').doc(hid).collection('ingredients');
    await ings.doc('schlagobers').update({'baseUnit': 'ml'});
    await PantryRepository(db, hid).changeAmount('schlagobers', 250);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'r',
        title: 'Malakofftorte',
        ingredients: [
          RecipeIngredient(
            rawText: '50 g Schlag',
            ingredientId: 'schlagobers',
            amount: 50,
            unit: 'g',
          ),
        ],
      ),
      isNew: true,
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malakofftorte'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Gekocht'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Gekocht'));
    await tester.pumpAndSettle();

    expect(find.text('Wie viel ml sind 1 g Schlagobers?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // ignore: avoid_print
    print(
      'TEXTS ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | ')}',
    );
    // ignore: avoid_print
    print(
      'FIELDS ${tester.widgetList<TextField>(find.byType(TextField)).map((t) => t.controller?.text).join(' | ')}',
    );
    // The cooked dialog now plans 50 ml.
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '50',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Abziehen'));
    await tester.pumpAndSettle();

    final pantry = await db
        .collection('households')
        .doc(hid)
        .collection('pantry')
        .doc('schlagobers')
        .get();
    expect(pantry.data()!['amount'], 200);
    final cream = (await ings.doc('schlagobers').get()).data()!;
    expect((cream['conversions'] as Map)['g'], 1);
  });

  test('seed list: common liquids and pieces need no question', () {
    final seed = [
      for (final m in (jsonDecode(
        File('assets/seed/ingredients_de.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>())
        Ingredient.fromMap(m['id'] as String, m),
    ];
    Ingredient by(String id) => seed.firstWhere((i) => i.id == id);
    expect(by('schlagobers').toBase(50, 'g'), 50);
    expect(by('oel').toBase(100, 'g')!.round(), 109);
    // Own conversion (1 EL = 20 g) wins over the density.
    expect(by('honig').toBase(1, 'EL'), 20);
    expect(by('honig').toBase(100, 'ml')!.round(), 142);
    expect(by('banane').toBase(1.2, 'kg'), 10);
    expect(by('ei').toBase(120, 'g'), 2);
  });

  test('backfill v3 adds missing synonyms and conversions only', () async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final h = db.collection('households').doc(hid);
    await h.update({'seedVersion': 2});
    await h.collection('ingredients').doc('schlagobers').update({
      'name': 'Sahne', // preferred term changed by the household
      'synonyms': ['Schlagobers'],
      'baseUnit': 'ml',
      'conversions': {'Becher': 200},
    });
    const seed = [
      Ingredient(
        id: 'schlagobers',
        name: 'Schlagobers',
        synonyms: ['Sahne', 'Schlag'],
        baseUnit: BaseUnit.ml,
        conversions: {'Becher': 250, 'g': 1},
      ),
    ];
    await HouseholdRepository(db).backfillSeed(hid, seed);
    final cream = (await h.collection('ingredients').doc('schlagobers').get())
        .data()!;
    expect(cream['name'], 'Sahne');
    expect(cream['synonyms'], ['Schlagobers', 'Schlag']);
    expect(cream['conversions'], {'Becher': 200, 'g': 1});
    expect((await h.get()).data()!['seedVersion'], 5);
  });
}
