import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/pantry/data/frozen_meal_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('plan a freezer dish, cookies are not offered, take a portion', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final recipes = RecipeRepository(db, hid);
    await recipes.save(const Recipe(id: 'g', title: 'Gulasch'), isNew: true);
    await recipes.save(
      const Recipe(
        id: 'k',
        title: 'Vanillekipferl',
        category: RecipeCategories.cookies,
      ),
      isNew: true,
    );
    await FrozenMealRepository(
      db,
      hid,
    ).add(title: 'Krautfleckerl', portions: 2);

    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wochenplan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rezept einplanen').first);
    await tester.pumpAndSettle();
    expect(find.text('Aus dem Tiefkühler'), findsOneWidget);
    expect(find.text('Gulasch'), findsOneWidget);
    expect(find.text('Vanillekipferl'), findsNothing);
    await tester.tap(find.text('Krautfleckerl'));
    await tester.pumpAndSettle();

    expect(find.text('Krautfleckerl'), findsOneWidget);
    await tester.tap(find.text('Krautfleckerl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portion entnehmen'));
    await tester.pumpAndSettle();
    expect(find.text('1 Portion'), findsOneWidget);
  });

  testWidgets('suggest the week fills free days after a preview', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final recipes = RecipeRepository(db, hid);
    await recipes.save(const Recipe(id: 'g', title: 'Gulasch'), isNew: true);
    await recipes.save(const Recipe(id: 's', title: 'Schnitzel'), isNew: true);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wochenplan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Woche vorschlagen'));
    await tester.pumpAndSettle();
    expect(find.text('Gulasch'), findsOneWidget);
    expect(find.text('Schnitzel'), findsOneWidget);
    await tester.tap(find.text('Einplanen'));
    await tester.pumpAndSettle();
    final plan = await db
        .collection('households')
        .doc(hid)
        .collection('mealplan')
        .get();
    expect(plan.docs.expand((d) => d.data()['recipeIds'] as List).toSet(), {
      'g',
      's',
    });
  });
}
