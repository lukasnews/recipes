import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/menus/data/menu_repository.dart';
import 'package:recipes/features/menus/domain/menu.dart';
import 'package:recipes/features/menus/domain/menu_plan.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  const soup = Recipe(id: 's', title: 'Frittatensuppe', cookMinutes: 20);
  const goulash = Recipe(
    id: 'g',
    title: 'Gulasch',
    prepMinutes: 20,
    cookMinutes: 90,
  );
  const strudel = Recipe(
    id: 'a',
    title: 'Apfelstrudel',
    prepMinutes: 30,
    cookMinutes: 40,
  );
  const salad = Recipe(id: 'x', title: 'Salat');
  final recipes = {
    for (final r in [soup, goulash, strudel, salad]) r.id: r,
  };
  const menu = Menu(
    id: 'm',
    title: 'Geburtstag',
    servings: 8,
    date: '2026-11-14',
    serveAt: '19:00',
    courses: [
      MenuCourse('a', Course.dessert),
      MenuCourse('g', Course.main),
      MenuCourse('x', Course.side),
      MenuCourse('s', Course.starter),
    ],
  );

  test('round trip and serving order', () {
    final back = Menu.fromMap('m', menu.toMap());
    expect(back.servings, 8);
    expect(back.date, '2026-11-14');
    expect(back.serveAt, '19:00');
    expect(back.ordered.map((c) => c.recipeId), ['s', 'g', 'x', 'a']);
    expect(Course.parse('nonsense'), Course.other);
  });

  test('serve time on the menu date', () {
    expect(menuServeTime(menu, DateTime(2026)), DateTime(2026, 11, 14, 19));
    expect(
      menuServeTime(menu.copyWith(date: () => null), DateTime(2026, 1, 2)),
      DateTime(2026, 1, 2, 19),
    );
    expect(
      menuServeTime(menu.copyWith(serveAt: () => null), DateTime(2026)),
      isNull,
    );
  });

  test('timeline counts back from the serving time per course', () {
    final t = menuTimeline(menu, recipes, DateTime(2026, 11, 14, 19));
    String fmt(DateTime d) =>
        '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    expect(
      [for (final s in t.steps) '${fmt(s.at)} ${s.recipe.id} ${s.kind.name}'],
      [
        '17:40 g prepare', // main ready 19:30: 90 min cooking, 20 before
        '18:00 g cook',
        '18:40 s cook',
        '19:00 s serve',
        '19:05 a prepare', // dessert ready 20:15: 40 min baking, 30 before
        '19:30 g serve',
        '19:30 x serve',
        '19:35 a cook',
        '20:15 a serve',
      ],
    );
    expect(t.untimed.map((r) => r.id), ['x']);
  });

  test('shopping scales every course to the guests', () {
    const mehl = Ingredient(id: 'mehl', name: 'Mehl', baseUnit: BaseUnit.g);
    const r = Recipe(
      id: 'r',
      title: 'Nockerl',
      ingredients: [
        RecipeIngredient(
          rawText: '200 g Mehl',
          ingredientId: 'mehl',
          amount: 200,
          unit: 'g',
        ),
      ],
    );
    final needs = menuShoppingNeeds(
      const Menu(
        id: 'm',
        title: 'x',
        servings: 6,
        courses: [MenuCourse('r', Course.main)],
      ),
      {'r': r},
      {'mehl': mehl},
      {'mehl': const PantryItem(ingredientId: 'mehl', amount: 100)},
    );
    expect(needs.single.missingBase, 200); // 300 g for 6, 100 g in stock
  });

  testWidgets('create a menu, add a course, see the timetable', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(goulash, isNew: true);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menüs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noch keine Menüs'), findsOneWidget);
    await tester.tap(find.text('Neues Menü'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Geburtstag');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gang hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hauptspeise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gulasch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    final docs = (await db.collection('households/$hid/menus').get()).docs;
    final id = docs.single.id;
    expect(docs.single.data()['courses'], [
      {'recipeId': 'g', 'course': 'main'},
    ]);
    expect(docs.single.data()['servings'], 5);
    expect(find.textContaining('Uhrzeit festlegen, dann'), findsOneWidget);

    await MenuRepository(db, hid).save(
      Menu.fromMap(id, docs.single.data()).copyWith(serveAt: () => '19:00'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Essen um 19:00'), findsOneWidget);
    expect(find.text('Gulasch vorbereiten'), findsOneWidget);
    expect(find.text('17:40'), findsOneWidget);
    expect(find.text('Gulasch servieren'), findsOneWidget);
  });
}
