import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/categories.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  const soup = Recipe(id: 's', title: 'Frittatensuppe', category: 'Suppen');
  const bread = Recipe(id: 'b', title: 'Brot', category: 'Brot');

  test('household order first, then built-ins, then the rest A–Z', () {
    expect(allCategories(recipes: [soup, bread]), [
      ...RecipeCategories.builtIn,
      'Brot',
      'Suppen',
    ]);
    expect(
      allCategories(
        order: ['Suppen', RecipeCategories.cake, 'Grillen'],
        recipes: [soup, bread],
      ),
      [
        'Suppen',
        RecipeCategories.cake,
        'Grillen',
        RecipeCategories.cooking,
        RecipeCategories.cookies,
        RecipeCategories.drinks,
        'Brot',
      ],
    );
  });

  test('cooking can not be hidden', () {
    expect(
      visibleCategories(
        [RecipeCategories.cooking, RecipeCategories.cookies, 'Suppen'],
        {RecipeCategories.cooking, RecipeCategories.cookies},
      ),
      [RecipeCategories.cooking, 'Suppen'],
    );
  });

  testWidgets('manage categories: add, rename, hide, delete', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(soup, isNew: true);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategorien'));
    await tester.pumpAndSettle();

    // Add an empty one.
    await tester.tap(find.text('Neue Kategorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Grillen');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Grillen'), findsOneWidget);
    var household = (await db.doc('households/$hid').get()).data()!;
    expect(household['categoryOrder'], contains('Grillen'));

    // A name that exists (also as a built-in label) is refused.
    await tester.tap(find.text('Neue Kategorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kekse');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('„kekse“ gibt es schon.'), findsOneWidget);

    // Rename moves the recipes along.
    await tester.tap(find.text('Suppen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Suppen & Eintöpfe');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    var recipe = (await db.doc('households/$hid/recipes/s').get()).data()!;
    expect(recipe['category'], 'Suppen & Eintöpfe');

    // Hide cookies.
    await tester.tap(find.byTooltip('Ausblenden').at(1)); // 0 = cake
    await tester.pumpAndSettle();
    household = (await db.doc('households/$hid').get()).data()!;
    expect(household['hiddenCategories'], [RecipeCategories.cookies]);

    // Delete the renamed one: the recipe goes to "Kochen".
    await tester.tap(find.byTooltip('Löschen').first); // before Grillen
    await tester.pumpAndSettle();
    expect(find.textContaining('1 Rezept kommt zu „Kochen“'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    recipe = (await db.doc('households/$hid/recipes/s').get()).data()!;
    expect(recipe['category'], RecipeCategories.cooking);

    // Recipe list: own empty category shown, hidden one not.
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Grillen'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Kekse'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Suppen & Eintöpfe'), findsNothing);
  });
}
