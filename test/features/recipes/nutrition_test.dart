import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('estimate nutrition; editing the recipe drops it', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    const recipe = Recipe(
      id: 'k',
      title: 'Kaiserschmarrn',
      servings: 2,
      ingredients: [RecipeIngredient(rawText: '125 g Mehl glatt')],
    );
    final repo = RecipeRepository(db, hid);
    await repo.save(recipe, isNew: true);
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

    await tester.tap(find.text('Nährwerte schätzen (KI)'));
    await tester.pumpAndSettle();
    expect(extractor.lastNutritionText, contains('125 g Mehl glatt'));
    expect(extractor.lastNutritionText, contains('Portionen: 2'));
    expect(find.textContaining('ca. 520 kcal'), findsOneWidget);

    await repo.save(recipe, isNew: false);
    await tester.pumpAndSettle();
    expect(find.text('Nährwerte schätzen (KI)'), findsOneWidget);
  });
}
