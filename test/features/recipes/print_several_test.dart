import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/menus/data/menu_repository.dart';
import 'package:recipes/features/menus/domain/menu.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<(FakeFirebaseFirestore, String)> setUp() async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final repo = RecipeRepository(db, hid);
    for (final (id, title) in [
      ('a', 'Apfelstrudel'),
      ('g', 'Gulasch'),
      ('k', 'Kaiserschmarrn'),
    ]) {
      await repo.save(
        Recipe(
          id: id,
          title: title,
          ingredients: const [RecipeIngredient(rawText: '1 Ei')],
          steps: const [RecipeStep('Kochen.')],
        ),
        isNew: true,
      );
    }
    return (db, hid);
  }

  testWidgets('long press, choose more, print them in one PDF', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (db, _) = await setUp();
    final printer = FakeRecipePrinter();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        printer: printer,
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Gulasch'));
    await tester.pumpAndSettle();
    expect(find.text('1 ausgewählt'), findsOneWidget);
    await tester.tap(find.text('Apfelstrudel'));
    await tester.pumpAndSettle();
    expect(find.text('2 ausgewählt'), findsOneWidget);
    // While choosing, a tap selects instead of opening the recipe.
    expect(find.byTooltip('Neues Rezept'), findsNothing);

    await tester.tap(find.byTooltip('Drucken / als PDF speichern'));
    await tester.pumpAndSettle();
    expect(printer.printed, ['2 Rezepte']);
    expect(ascii.decode(printer.lastPdf!.sublist(0, 5)), '%PDF-');

    await tester.tap(find.byTooltip('Als PDF teilen'));
    await tester.pumpAndSettle();
    expect(printer.shared, ['2 Rezepte.pdf']);

    await tester.tap(find.byTooltip('Auswahl beenden'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Neues Rezept'), findsOneWidget);
  });

  testWidgets('print a menu', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (db, hid) = await setUp();
    await MenuRepository(db, hid).save(
      const Menu(
        id: 'm',
        title: 'Sonntag',
        courses: [
          MenuCourse('a', Course.dessert),
          MenuCourse('g', Course.main),
        ],
      ),
      isNew: true,
    );
    final printer = FakeRecipePrinter();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        printer: printer,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menüs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonntag'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menü drucken'));
    await tester.pumpAndSettle();
    expect(printer.printed, ['Sonntag']);
  });
}
