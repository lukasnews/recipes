import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('camera: several pages become one recipe import', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    final extractor = FakeExtractor(const [
      RecipeDraft(
        title: 'Sachertorte',
        ingredientLines: ['140 g Butter'],
        steps: ['Backen.'],
      ),
    ]);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        importService: fakeImportService(extractor: extractor),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezept fotografieren'));
    await tester.pumpAndSettle();

    expect(find.text('1 Seite fotografiert'), findsOneWidget);
    await tester.tap(find.text('Weitere Seite'));
    await tester.pumpAndSettle();
    expect(find.text('2 Seiten fotografiert'), findsOneWidget);
    await tester.tap(find.text('Fertig – Rezept lesen'));
    await tester.pumpAndSettle();

    expect(extractor.lastImageCount, 2);
    expect(find.text('Sachertorte'), findsOneWidget);
  });
}
