import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('cook mode: steps, timer, then cooked dialog', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'r1',
        title: 'Kaiserschmarrn',
        steps: [
          RecipeStep('Teig rühren und 20 Minuten rasten lassen.'),
          RecipeStep('In der Pfanne goldbraun backen.'),
        ],
      ),
      isNew: true,
    );
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaiserschmarrn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kochmodus'));
    await tester.pumpAndSettle();

    expect(find.text('Schritt 1 von 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '20 Min.'));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.textContaining('Schritt 1: 20 Min. · 19:5'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Schritt 2 von 2'), findsOneWidget);
    // Timer keeps running on the next step.
    expect(find.textContaining('Schritt 1: 20 Min.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Gekocht'));
    await tester.pumpAndSettle();
    expect(find.text('Gekocht'), findsWidgets); // cooked dialog title
    expect(find.text('Reste einfrieren (Portionen)'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });
}
