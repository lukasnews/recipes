import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('AI tags on request: tick, save, filter the list', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final repo = RecipeRepository(db, hid);
    await repo.save(
      const Recipe(id: 'k', title: 'Kaiserschmarrn', tags: ['Klassiker']),
      isNew: true,
    );
    await repo.save(const Recipe(id: 'g', title: 'Gulasch'), isNew: true);
    final extractor = FakeExtractor(const []);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        extractor: extractor,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaiserschmarrn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags vorschlagen (KI)'));
    await tester.pumpAndSettle();
    expect(extractor.lastKnownTags, ['Klassiker']);

    // Drop "schnell", keep the rest.
    await tester.tap(find.widgetWithText(FilterChip, '#schnell'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final doc = await db.doc('households/$hid/recipes/k').get();
    expect(doc['tags'], ['Klassiker', 'vegetarisch', 'süß']);

    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Weitere Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '#vegetarisch'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiserschmarrn'), findsOneWidget);
    expect(find.text('Gulasch'), findsNothing);
  });
}
