import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/recipes/domain/recipe_variants.dart';

import '../../helpers/fakes.dart';

void main() {
  const root = Recipe(id: 'k', title: 'Kaiserschmarrn');
  const vegan = Recipe(
    id: 'v',
    title: 'Kaiserschmarrn (vegan)',
    variantOf: 'k',
    variantName: 'vegan',
  );
  const small = Recipe(
    id: 's',
    title: 'Kaiserschmarrn (für 2)',
    variantOf: 'k',
    variantName: 'für 2',
  );
  const other = Recipe(id: 'g', title: 'Gulasch');
  const all = [root, vegan, small, other];

  test('family: original first, variants by name', () {
    expect(variantFamily(vegan, all).map((r) => r.id), ['k', 's', 'v']);
    expect(variantFamily(root, all).map((r) => r.id), ['k', 's', 'v']);
    expect(variantFamily(other, all).map((r) => r.id), ['g']);
  });

  test('variant whose original is gone stands alone', () {
    expect(variantFamily(vegan, [vegan]).map((r) => r.id), ['v']);
    expect(variantCounts([vegan]), isEmpty);
    expect(collapseVariants([vegan], (r) => r), [vegan]);
  });

  test('counts and collapse', () {
    expect(variantCounts(all), {'k': 2});
    expect(collapseVariants(all, (r) => r).map((r) => r.id), ['k', 'g']);
    // Only the variant matches the filter: it is shown.
    expect(collapseVariants([vegan, other], (r) => r).map((r) => r.id), [
      'v',
      'g',
    ]);
  });

  test('deleting the original promotes the first variant', () {
    expect(promoteOnDelete(root, all), {'s': null, 'v': 's'});
    expect(promoteOnDelete(vegan, all), isEmpty);
    expect(promoteOnDelete(other, all), isEmpty);
  });

  test('round trip keeps the variant fields', () {
    final back = Recipe.fromMap('v', vegan.toMap());
    expect(back.variantOf, 'k');
    expect(back.variantName, 'vegan');
    expect(root.toMap().containsKey('variantOf'), isFalse);
  });

  test('deleteWithVariants moves variants to the new original', () async {
    final db = FakeFirebaseFirestore();
    final repo = RecipeRepository(db, 'h');
    for (final r in all) {
      await repo.save(r, isNew: true);
    }
    await repo.deleteWithVariants('k', promoteOnDelete(root, all));
    final recipes = await repo.watchAll().first;
    final byId = {for (final r in recipes) r.id: r};
    expect(byId.containsKey('k'), isFalse);
    expect(byId['s']!.variantOf, isNull);
    expect(byId['s']!.variantName, isNull);
    expect(byId['v']!.variantOf, 's');
  });

  testWidgets('create a variant and switch between them', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final repo = RecipeRepository(db, hid);
    await repo.save(
      const Recipe(
        id: 'k',
        title: 'Kaiserschmarrn',
        ingredients: [RecipeIngredient(rawText: '4 Eier')],
        steps: [RecipeStep('Alles verrühren')],
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

    await tester.tap(find.text('Kaiserschmarrn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Variante anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'vegan');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Neue Variante'), findsOneWidget);
    expect(find.text('Kaiserschmarrn (vegan)'), findsOneWidget);
    await tester.tap(find.text('Speichern').first);
    await tester.pumpAndSettle();

    final docs = (await db.collection('households/$hid/recipes').get()).docs;
    final variant = docs.firstWhere((d) => d.id != 'k').data();
    expect(variant['variantOf'], 'k');
    expect(variant['variantName'], 'vegan');
    expect(variant['ingredients'], hasLength(1));

    // Now on the variant: chips switch to the original and back.
    expect(find.widgetWithText(ChoiceChip, 'Original'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Original'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Kaiserschmarrn'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'vegan'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, 'Kaiserschmarrn (vegan)'),
      findsOneWidget,
    );

    // Back to the original it was made from, then the list: one tile
    // with the variant count.
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiserschmarrn (vegan)'), findsNothing);
    expect(find.textContaining('1 Variante'), findsOneWidget);
  });
}
