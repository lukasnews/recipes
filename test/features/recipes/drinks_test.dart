import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  test('drink temperature only for drinks; old custom category maps', () {
    const cocoa = Recipe(
      id: 'c',
      title: 'Kakao',
      category: RecipeCategories.drinks,
      drinkTemp: DrinkTemp.hot,
    );
    expect(Recipe.fromMap('c', cocoa.toMap()).drinkTemp, DrinkTemp.hot);
    expect(
      const Recipe(
        id: 'x',
        title: 'x',
        drinkTemp: DrinkTemp.hot,
      ).toMap()['drinkTemp'],
      isNull,
    );
    expect(
      Recipe.fromMap('o', {'title': 'Eistee', 'category': 'Getränke'}).category,
      RecipeCategories.drinks,
    );
  });

  testWidgets('drinks chip with hot / cold below it', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final repo = RecipeRepository(db, hid);
    await repo.save(
      const Recipe(
        id: 'k',
        title: 'Heiße Schokolade',
        category: RecipeCategories.drinks,
        drinkTemp: DrinkTemp.hot,
      ),
      isNew: true,
    );
    await repo.save(
      const Recipe(
        id: 'e',
        title: 'Eistee',
        category: RecipeCategories.drinks,
        drinkTemp: DrinkTemp.cold,
      ),
      isNew: true,
    );
    await repo.save(const Recipe(id: 'g', title: 'Gulasch'), isNew: true);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Getränke'));
    await tester.pumpAndSettle();
    expect(find.text('Gulasch'), findsNothing);
    expect(find.text('Eistee'), findsOneWidget);
    expect(find.text('Getränke · Heiß'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Kalt'));
    await tester.pumpAndSettle();
    expect(find.text('Eistee'), findsOneWidget);
    expect(find.text('Heiße Schokolade'), findsNothing);

    // Editor: switch the cold drink to hot.
    await tester.tap(find.text('Eistee'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Heiß').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();
    final doc = await db.doc('households/$hid/recipes/e').get();
    expect(doc.data()!['drinkTemp'], DrinkTemp.hot);
  });
}
