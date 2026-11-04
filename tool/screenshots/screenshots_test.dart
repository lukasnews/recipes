// Store screenshots of the real app with demo data.
// Run: flutter test tool/screenshots/screenshots_test.dart
// Output: assets/branding/screenshots/*.png (1080 x 1920).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/household/data/household_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/mealplan/data/meal_plan_repository.dart';
import 'package:recipes/features/mealplan/domain/meal_plan_day.dart';
import 'package:recipes/features/pantry/data/frozen_meal_repository.dart';
import 'package:recipes/features/pantry/data/pantry_repository.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../test/helpers/fakes.dart';

const _out = 'assets/branding/screenshots';
const _fonts = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      File('$_fonts/$f').readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

/// (amount, unit, name, note?)
typedef _Line = (double?, String?, String, String?);

void main() {
  late List<Ingredient> seed;
  late IngredientMatcher matcher;

  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Light.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    final raw = File('assets/seed/ingredients_de.json').readAsStringSync();
    seed = [
      for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
        Ingredient.fromMap(m['id'] as String, m),
    ];
    matcher = IngredientMatcher(seed.map((i) => i.candidate));
    Directory(_out).createSync(recursive: true);
  });

  Recipe recipe(
    String id,
    String title, {
    String category = RecipeCategories.cooking,
    int servings = 4,
    int? prep,
    int? cook,
    int rating = 0,
    List<String> tags = const [],
    required List<_Line> lines,
    List<String> steps = const [],
  }) => Recipe(
    id: id,
    title: title,
    category: category,
    servings: servings,
    prepMinutes: prep,
    cookMinutes: cook,
    rating: rating,
    tags: tags,
    ingredients: [
      for (final (amount, unit, name, note) in lines)
        RecipeIngredient(
          rawText: [?amount?.toString(), ?unit, name].join(' '),
          ingredientId: matcher.match(name).id,
          amount: amount,
          unit: unit,
          name: name,
          note: note,
        ),
    ],
    steps: [for (final s in steps) RecipeStep(s)],
  );

  Future<String> demoHousehold(FakeFirebaseFirestore db) async {
    final repo = HouseholdRepository(db);
    await repo.ensureUser('u1', 'Lukas');
    final hid = await repo.createHousehold(
      uid: 'u1',
      name: 'Zuhause',
      seed: seed,
    );
    await repo.setOnboardingDone('u1');
    final recipes = RecipeRepository(db, hid);
    final all = [
      recipe(
        'kaiserschmarrn',
        'Kaiserschmarrn',
        servings: 2,
        prep: 10,
        cook: 15,
        rating: 5,
        tags: ['süß', 'schnell'],
        lines: [
          (125, 'g', 'Mehl glatt', null),
          (250, 'ml', 'Milch', null),
          (4, null, 'Eier', null),
          (30, 'g', 'Kristallzucker', null),
          (40, 'g', 'Butter', null),
          (40, 'g', 'Rosinen', 'in Rum eingeweicht'),
          (null, null, 'Staubzucker', 'zum Bestreuen'),
        ],
        steps: [
          'Eier trennen. Dotter mit Milch und Mehl glatt rühren.',
          'Eiklar mit dem Zucker steif schlagen und vorsichtig unterheben.',
          'Butter in einer großen Pfanne erhitzen, Teig eingießen, Rosinen '
              'darüberstreuen und 4 Minuten backen.',
          'Wenden, mit zwei Gabeln zerreißen und noch 3 Minuten fertig '
              'backen. Mit Staubzucker bestreuen.',
        ],
      ),
      recipe(
        'gulasch',
        'Rindsgulasch',
        prep: 20,
        cook: 150,
        rating: 5,
        lines: [
          (1, 'kg', 'Rindfleisch', 'Wadschinken'),
          (4, null, 'Zwiebeln', null),
          (3, 'EL', 'Paprikapulver edelsüß', null),
          (2, 'EL', 'Tomatenmark', null),
          (1, 'TL', 'Kümmel', 'gemahlen'),
          (null, null, 'Majoran', null),
          (null, null, 'Salz', null),
        ],
        steps: [
          'Zwiebeln fein schneiden und in Öl langsam goldbraun rösten.',
          'Paprikapulver und Tomatenmark kurz mitrösten, mit Wasser löschen.',
          'Fleisch, Kümmel und Majoran dazugeben und 2½ Stunden zugedeckt '
              'schmoren.',
        ],
      ),
      recipe(
        'schnitzel',
        'Wiener Schnitzel',
        prep: 15,
        cook: 10,
        rating: 4,
        lines: [
          (600, 'g', 'Kalbsschnitzel', null),
          (100, 'g', 'Mehl glatt', null),
          (2, null, 'Eier', null),
          (150, 'g', 'Semmelbrösel', null),
          (200, 'g', 'Butterschmalz', null),
          (1, null, 'Zitrone', null),
        ],
      ),
      recipe(
        'topfenknoedel',
        'Topfenknödel',
        prep: 20,
        cook: 15,
        rating: 4,
        tags: ['süß'],
        lines: [
          (500, 'g', 'Topfen', null),
          (2, null, 'Eier', null),
          (60, 'g', 'Butter', null),
          (120, 'g', 'Semmelbrösel', null),
        ],
      ),
      recipe(
        'marillenkuchen',
        'Marillenkuchen',
        category: RecipeCategories.cake,
        prep: 25,
        cook: 40,
        rating: 5,
        lines: [
          (500, 'g', 'Marillen', null),
          (200, 'g', 'Mehl glatt', null),
          (4, null, 'Eier', null),
          (150, 'g', 'Kristallzucker', null),
          (150, 'g', 'Butter', null),
        ],
      ),
      recipe(
        'linzer',
        'Linzer Augen',
        category: RecipeCategories.cookies,
        prep: 40,
        cook: 12,
        lines: [
          (300, 'g', 'Mehl glatt', null),
          (200, 'g', 'Butter', null),
          (100, 'g', 'Staubzucker', null),
          (150, 'g', 'Ribiselmarmelade', null),
        ],
      ),
      recipe(
        'krautfleckerl',
        'Krautfleckerl',
        prep: 15,
        cook: 30,
        rating: 3,
        lines: [
          (500, 'g', 'Weißkraut', null),
          (250, 'g', 'Fleckerl', null),
          (1, null, 'Zwiebeln', null),
          (1, 'TL', 'Kümmel', null),
        ],
      ),
    ];
    for (final r in all) {
      await recipes.save(r, isNew: true);
    }

    final now = DateTime.now();
    final pantry = PantryRepository(db, hid);
    Future<void> stock(
      String id,
      double amount, [
      StorageLocation loc = StorageLocation.pantry,
      int? expiresInDays,
    ]) async {
      await pantry.changeAmount(id, amount, location: loc);
      if (expiresInDays != null) {
        await pantry.update(
          id,
          expiresOn: () => now.add(Duration(days: expiresInDays)),
        );
      }
    }

    await stock('mehl-glatt', 1500);
    await stock('milch', 1000, StorageLocation.fridge, 2);
    await stock('ei', 8, StorageLocation.fridge);
    await stock('butter', 250, StorageLocation.fridge);
    await stock('topfen', 250, StorageLocation.fridge, 1);
    await stock('kristallzucker', 1000);
    await stock('staubzucker', 500);
    await stock('rosinen', 100);
    await stock('zwiebel', 6);
    await stock('paprikapulver-edelsuess', 80);
    await stock('semmelbroesel', 400);
    await stock('marillen', 750, StorageLocation.freezer);
    await stock('erdaepfel', 2000);

    final shop = db.collection('households').doc(hid).collection('shopping');
    var t = 0;
    Future<void> item(
      String id,
      String text,
      String aisle, {
      double? amount,
      String? unit,
      bool checked = false,
    }) => shop.add({
      'ingredientId': id,
      'text': text,
      'amount': ?amount,
      'unit': ?unit,
      'aisle': aisle,
      'checked': checked,
      'addedBy': 'u1',
      'createdAt': Timestamp.fromDate(now.add(Duration(seconds: t++))),
    });
    await item('rindfleisch', 'Rindfleisch', 'meat', amount: 1000, unit: 'g');
    await item(
      'kalbsschnitzel',
      'Kalbsschnitzel',
      'meat',
      amount: 600,
      unit: 'g',
    );
    await item('schlagobers', 'Schlagobers', 'dairy', amount: 250, unit: 'ml');
    await item('paradeiser', 'Paradeiser', 'produce', amount: 6, unit: 'Stk.');
    await item('zitrone', 'Zitronen', 'produce', amount: 2, unit: 'Stk.');
    await item(
      'apfel',
      'Äpfel',
      'produce',
      amount: 1000,
      unit: 'g',
      checked: true,
    );
    await item('semmel', 'Semmeln', 'bread', amount: 6, unit: 'Stk.');
    await item(
      'kaffee',
      'Kaffee',
      'drinks',
      amount: 500,
      unit: 'g',
      checked: true,
    );

    final frozen = FrozenMealRepository(db, hid);
    await frozen.add(
      title: 'Rindsgulasch',
      portions: 3,
      recipeId: 'gulasch',
      frozenOn: now.subtract(const Duration(days: 20)),
    );
    await frozen.add(
      title: 'Krautfleckerl',
      portions: 2,
      recipeId: 'krautfleckerl',
    );

    final plan = MealPlanRepository(db, hid);
    final monday = startOfWeek(now);
    String day(int i) => dayKey(monday.add(Duration(days: i)));
    final frozenId =
        (await db
                .collection('households')
                .doc(hid)
                .collection('frozenMeals')
                .where('title', isEqualTo: 'Rindsgulasch')
                .get())
            .docs
            .single
            .id;
    await plan.add(day(0), 'krautfleckerl');
    await plan.add(day(1), 'topfenknoedel');
    await plan.add(day(2), 'kaiserschmarrn');
    await plan.add(day(3), 'schnitzel');
    await plan.addFrozen(day(4), frozenId);
    await plan.add(day(5), 'gulasch');
    await plan.add(day(6), 'marillenkuchen');

    final log = db.collection('households').doc(hid).collection('cookLog');
    for (final (rid, daysAgo) in [
      ('kaiserschmarrn', 12),
      ('kaiserschmarrn', 30),
      ('gulasch', 45),
      ('schnitzel', 8),
    ]) {
      await log.add({
        'recipeId': rid,
        'servings': 4,
        'cookedAt': Timestamp.fromDate(now.subtract(Duration(days: daysAgo))),
        'deductions': <Object>[],
        'undone': false,
      });
    }
    return hid;
  }

  testWidgets('store screenshots', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 2.625;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    debugDisableShadows = false;

    final db = FakeFirebaseFirestore();
    await tester.runAsync(() => demoHousehold(db));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: testApp(
          db: db,
          auth: FakeAuthRepository(
            const AuthUser(uid: 'u1', displayName: 'Lukas'),
          ),
          seed: seed,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.625);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> tab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    // 1. Recipes with "Mit Vorrat kochbar".
    await tester.tap(find.byTooltip('Weitere Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mit Vorrat kochbar'));
    await tester.pumpAndSettle();
    await shot('1_rezepte');

    // 2. Recipe detail.
    await tester.tap(find.text('Kaiserschmarrn'));
    await tester.pumpAndSettle();
    await shot('2_rezept');

    // 3. Cook mode with a timer.
    await tester.scrollUntilVisible(
      find.text('Kochmodus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kochmodus'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
    }
    final timer = find.byIcon(Icons.timer_outlined);
    if (timer.evaluate().isNotEmpty) {
      await tester.tap(timer.first);
      await tester.pump(const Duration(seconds: 37));
    }
    await shot('3_kochmodus');
    for (var i = 0; i < 2; i++) {
      // System back; tool/ isn't a test dir for the analyzer.
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
    }

    // 4. Meal plan.
    await tab('Wochenplan');
    await shot('4_wochenplan');

    // 5. Shopping list.
    await tab('Einkauf');
    await shot('5_einkauf');

    // 6. Pantry.
    await tab('Vorrat');
    await shot('6_vorrat');
    debugDisableShadows = true;
  });
}
