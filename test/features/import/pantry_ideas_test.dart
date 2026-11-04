import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';
import 'package:recipes/features/pantry/data/pantry_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('ideas from the pantry go through the review screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await PantryRepository(db, hid).changeAmount('schlagobers', 250);
    await db
        .collection('households')
        .doc(hid)
        .collection('members')
        .doc('u1')
        .set({
          'displayName': 'Lukas',
          'allergens': ['nuts'],
        });
    final extractor = FakeExtractor(const [
      RecipeDraft(
        title: 'Obersnockerl',
        servings: 4,
        ingredientLines: ['250 ml Schlagobers'],
        steps: ['Obers schlagen.'],
      ),
      RecipeDraft(title: 'Rahmsuppe', ingredientLines: ['200 ml Sahne']),
    ]);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        extractor: extractor,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ideen aus dem Vorrat'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'süß',
    );
    await tester.tap(find.text('Ideen holen'));
    await tester.pumpAndSettle();

    expect(extractor.lastPantry, ['Schlagobers (250 Stk.)']);
    expect(extractor.lastWish, 'süß');
    expect(extractor.lastAvoid, isNotEmpty);

    // Two ideas: pick, then review the first one.
    expect(find.text('Obersnockerl'), findsOneWidget);
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.text('Rezept 1 von 2'), findsOneWidget);
    expect(find.text('Obersnockerl'), findsWidgets);
  });
}
