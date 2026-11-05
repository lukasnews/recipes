import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('print and share the recipe as PDF', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'k',
        title: 'Kaiserschmarrn',
        servings: 2,
        ingredients: [
          RecipeIngredient(
            rawText: '125 g Mehl glatt',
            amount: 125,
            unit: 'g',
            name: 'Mehl glatt',
          ),
        ],
        steps: [RecipeStep('Alles verrühren – süß und flaumig.')],
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
    await tester.tap(find.text('Kaiserschmarrn'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drucken / als PDF speichern'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();
    expect(printer.printed, ['Kaiserschmarrn']);
    expect(ascii.decode(printer.lastPdf!.sublist(0, 5)), '%PDF-');

    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Als PDF teilen'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();
    expect(printer.shared, ['Kaiserschmarrn.pdf']);
  });
}
