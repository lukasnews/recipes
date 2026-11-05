import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/baking_pan.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  test('area ratio between tins', () {
    const big = BakingPan.round(26);
    expect(big.factorFor(const BakingPan.round(26)), 1);
    expect(big.factorFor(const BakingPan.round(20)), closeTo(0.592, 0.001));
    expect(
      const BakingPan.rect(20, 30).factorFor(const BakingPan.rect(30, 40)),
      2,
    );
    expect(BakingPan.fromMap({'d': 26}), big);
    expect(BakingPan.fromMap({'w': 20, 'l': 30}), const BakingPan.rect(20, 30));
    expect(BakingPan.fromMap({'d': 0}), isNull);
  });

  testWidgets('convert a cake to my tin in the recipe detail', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 't',
        title: 'Topfentorte',
        category: RecipeCategories.cake,
        pan: BakingPan.round(26),
        ingredients: [
          RecipeIngredient(
            rawText: '1000 g Topfen',
            amount: 1000,
            unit: 'g',
            name: 'Topfen',
          ),
        ],
      ),
      isNew: true,
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topfentorte'));
    await tester.pumpAndSettle();
    expect(find.text('Backform im Rezept: Ø 26 cm'), findsOneWidget);
    expect(find.textContaining('1000 g'), findsOneWidget);

    await tester.tap(find.text('Andere Form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20');
    await tester.tap(find.text('Umrechnen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Umgerechnet für Ø 20 cm'), findsOneWidget);
    expect(find.textContaining('592 g'), findsOneWidget);

    await tester.tap(find.byTooltip('Wie im Rezept'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1000 g'), findsOneWidget);
  });
}
