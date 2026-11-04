import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/recipes/domain/sample_recipes.dart';

import '../../helpers/fakes.dart';

void main() {
  test('sample recipes link to seed ingredients', () {
    final seed = [
      for (final m in (jsonDecode(
        File('assets/seed/ingredients_de.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>())
        Ingredient.fromMap(m['id'] as String, m),
    ];
    final raw = (jsonDecode(
      File('assets/seed/recipes_de.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    final recipes = sampleRecipes(
      raw,
      IngredientMatcher(seed.map((i) => i.candidate)),
    );
    expect(recipes.map((r) => r.title), [
      'Kaiserschmarrn',
      'Rindsgulasch',
      'Erdäpfelsalat',
      'Vanillekipferl',
    ]);
    for (final r in recipes) {
      for (final l in r.ingredients) {
        expect(l.ingredientId, isNotNull, reason: '${r.title}: ${l.name}');
      }
      expect(r.steps, isNotEmpty);
    }
    final kaiser = recipes.first.ingredients;
    expect(kaiser.first.rawText, '125 g Mehl glatt');
    expect(kaiser[2].ingredientId, 'ei');
  });

  testWidgets('empty recipe list offers the example recipes', (tester) async {
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beispielrezepte hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiserschmarrn'), findsOneWidget);
    expect(find.text('Rindsgulasch'), findsOneWidget);
  });
}
