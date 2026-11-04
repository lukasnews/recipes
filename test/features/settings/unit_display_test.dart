import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/display_units.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('switching to dag converts amounts in recipes', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'r1',
        title: 'Topfenknödel',
        ingredients: [
          RecipeIngredient(
            rawText: '250 g Mehl glatt',
            ingredientId: 'mehl-glatt',
            amount: 250,
            unit: 'g',
          ),
        ],
      ),
      isNew: true,
    );
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dekagramm (österreichisch)'));
    await tester.pumpAndSettle();
    final user = (await db.doc('users/u1').get()).data()!;
    expect(user['unitDisplay'], UnitDisplay.austrian.name);

    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topfenknödel'));
    await tester.pumpAndSettle();
    expect(find.text('25 dag Mehl glatt'), findsOneWidget);
  });
}
