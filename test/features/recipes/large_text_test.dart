import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('recipe editor lays out with 200 % system font', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer anlegen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Vorbereitung (Min.)'), findsOneWidget);
  });

  testWidgets('recipe list lays out with 200 % system font', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'a',
        title: 'Rindsgulasch mit Semmelknödel',
        rating: 5,
        prepMinutes: 30,
        cookMinutes: 120,
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
    expect(tester.takeException(), isNull);
    expect(find.text('Rindsgulasch mit Semmelknödel'), findsOneWidget);
  });

  testWidgets('all category chips visible with 200 % font', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(id: 'a', title: 'Suppe', category: 'Suppen'),
      isNew: true,
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in ['Kochen', 'Kekse', 'Getränke', 'Suppen']) {
      expect(
        find.widgetWithText(ChoiceChip, label).hitTestable(),
        findsOneWidget,
        reason: label,
      );
    }
  });
}
