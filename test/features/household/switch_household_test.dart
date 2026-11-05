import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  test('creating a second household makes it the active one', () async {
    final db = FakeFirebaseFirestore();
    final first = await seedHousehold(db);
    final second = await HouseholdRepository(db)
        .createHousehold(uid: 'u1', name: 'Ferienhaus', seed: testSeed);
    final user = (await db.collection('users').doc('u1').get()).data()!;
    expect(user['householdIds'], [first, second]);
    expect(user['activeHouseholdId'], second);
  });

  testWidgets('switch household in settings shows its recipes', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final home = await seedHousehold(db);
    final cabin = await HouseholdRepository(db)
        .createHousehold(uid: 'u1', name: 'Ferienhaus', seed: testSeed);
    await RecipeRepository(
      db,
      home,
    ).save(const Recipe(id: 'a', title: 'Kaiserschmarrn'), isNew: true);
    await RecipeRepository(
      db,
      cabin,
    ).save(const Recipe(id: 'b', title: 'Kasnocken'), isNew: true);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Kasnocken'), findsOneWidget);
    expect(find.text('Kaiserschmarrn'), findsNothing);

    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haushalt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haushalt wechseln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zuhause'));
    await tester.pumpAndSettle();

    expect(find.text('Kaiserschmarrn'), findsOneWidget);
    expect(find.text('Kasnocken'), findsNothing);
  });
}
