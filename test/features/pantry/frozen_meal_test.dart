import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/pantry/data/frozen_meal_repository.dart';
import 'package:recipes/features/pantry/domain/frozen_meal.dart';

import '../../helpers/fakes.dart';

void main() {
  test('portions change with increments, last one removes the entry', () async {
    final db = FakeFirebaseFirestore();
    final repo = FrozenMealRepository(db, 'h1');
    await repo.add(title: 'Gulasch', portions: 2, recipeId: 'r1');
    var meal = (await repo.watchAll().first).single;
    expect(meal.portions, 2);
    expect(meal.recipeId, 'r1');

    await repo.changePortions(meal, -1);
    meal = (await repo.watchAll().first).single;
    expect(meal.portions, 1);

    await repo.changePortions(meal, -1);
    expect(await repo.watchAll().first, isEmpty);
  });

  test('old meals are flagged after three months', () {
    final now = DateTime(2026, 11, 3);
    FrozenMeal frozen(DateTime d) =>
        FrozenMeal(id: 'x', title: 'X', portions: 1, frozenOn: d);
    expect(frozen(DateTime(2026, 10, 2)).isOld(now), isFalse);
    expect(frozen(DateTime(2026, 7, 2)).isOld(now), isTrue);
  });

  testWidgets('freezer tab: add a meal and take a portion out', (tester) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Vorrat'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gerichte'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Keine Gerichte im Tiefkühler'), findsOneWidget);

    await tester.tap(find.text('Gericht einfrieren'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Gericht'),
      'Gulasch',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Portionen'), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Gulasch'), findsOneWidget);
    expect(find.textContaining('3 Portionen'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 Portionen'), findsOneWidget);
    final docs = await db.collection('households/$hid/frozenMeals').get();
    expect(docs.docs.single.data()['portions'], 2);
  });
}
