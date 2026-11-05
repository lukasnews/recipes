import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/mealplan/data/meal_plan_repository.dart';
import 'package:recipes/features/mealplan/domain/meal_plan_day.dart';
import 'package:recipes/features/pantry/domain/frozen_meal.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/shopping/presentation/widget_sync.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('home screen widget shows today and open items; tap opens '
      'the shopping list', (tester) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(
      db,
      hid,
    ).save(const Recipe(id: 'k', title: 'Kaiserschmarrn'), isNew: true);
    await MealPlanRepository(db, hid).add(dayKey(DateTime.now()), 'k');
    final shop = db.collection('households').doc(hid).collection('shopping');
    await shop.add({
      'text': 'Sahne',
      'ingredientId': 'schlagobers',
      'amount': 250,
      'unit': 'ml',
      'aisle': 'dairy',
      'checked': false,
    });
    await shop.add({
      'text': 'Semmeln',
      'amount': 6,
      'unit': 'Stk.',
      'aisle': 'bread',
      'checked': false,
    });
    await shop.add({'text': 'Kaffee', 'aisle': 'drinks', 'checked': true});
    final widget = FakeHomeScreenWidget();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        homeWidget: widget,
      ),
    );
    await tester.pumpAndSettle();

    final last = widget.updates.last;
    expect(last.title, 'Einkauf (2)');
    expect(last.today, 'Heute: Kaiserschmarrn');
    // Linked item shows the ingredient's current name; bread before dairy.
    expect(last.items, '• 6 Semmeln\n• 250 ml Schlagobers');
    final today = dayKey(DateTime.now());
    expect(last.plan.length, 14);
    expect(last.plan[today], 'Kaiserschmarrn');
    expect(last.plan.values.skip(1), everyElement(''));

    widget.clickController.add(Uri.parse('baco://mealplan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Woche ab'), findsOneWidget);

    widget.clickController.add(Uri.parse('baco://shopping'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Schlagobers'), findsWidgets);
    expect(find.textContaining('Was brauchst du?'), findsOneWidget);
  });

  testWidgets('a baco:// link from Android opens the tab, not an error', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(NavigationBar)))
        .go('baco://shopping/');
    await tester.pumpAndSettle();
    expect(find.textContaining('Was brauchst du?'), findsOneWidget);
  });

  test('plan days: recipes and frozen dishes per day, empty days blank', () {
    final from = DateTime(2026, 12, 31);
    final days = planWidgetDays(
      {
        '2026-12-31': const MealPlanDay(recipeIds: ['g'], frozenMealIds: ['f']),
        '2027-01-02': const MealPlanDay(recipeIds: ['x', 'g']),
      },
      {'g': const Recipe(id: 'g', title: 'Gulasch')},
      {
        'f': FrozenMeal(
          id: 'f',
          title: 'Krautfleckerl',
          portions: 2,
          frozenOn: from,
        ),
      },
      from,
      days: 3,
    );
    expect(days, {
      '2026-12-31': 'Gulasch, Krautfleckerl',
      '2027-01-01': '',
      '2027-01-02': 'Gulasch',
    });
  });
}
