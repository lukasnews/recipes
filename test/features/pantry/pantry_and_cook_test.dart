import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/pantry/data/pantry_repository.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

void main() {
  test('pantry changes use increments and keep location', () async {
    final db = FakeFirebaseFirestore();
    final pantry = PantryRepository(db, 'h1');
    await pantry.changeAmount('mehl', 1000, location: StorageLocation.pantry);
    await pantry.changeAmount('mehl', -250);
    await pantry.update('mehl', minAmount: () => 500);
    final item = (await pantry.watchAll().first)['mehl']!;
    expect(item.amount, 750);
    expect(item.location, StorageLocation.pantry);
    expect(item.minAmount, 500);
    expect(item.isBelowMin, isFalse);
  });

  test('cook deducts and undo books back', () async {
    final db = FakeFirebaseFirestore();
    final pantry = PantryRepository(db, 'h1');
    final recipes = RecipeRepository(db, 'h1');
    await pantry.changeAmount('mehl', 1000);
    await pantry.changeAmount('ei', 6);

    Future<void>? commit;
    final logId = recipes.cook(
      recipe: const Recipe(id: 'r1', title: 'Palatschinken'),
      servings: 4,
      deductions: {'mehl': 220, 'ei': 2},
      onCommit: (f) => commit = f,
    );
    await commit;
    var items = await pantry.watchAll().first;
    expect(items['mehl']!.amount, 780);
    expect(items['ei']!.amount, 4);
    final log = (await db.doc('households/h1/cookLog/$logId').get()).data()!;
    expect(log['undone'], false);
    expect(log['deductions'], hasLength(2));

    await recipes.undoCook(logId, {'mehl': 220, 'ei': 2});
    items = await pantry.watchAll().first;
    expect(items['mehl']!.amount, 1000);
    expect(items['ei']!.amount, 6);
    expect(
      (await db.doc('households/h1/cookLog/$logId').get()).data()!['undone'],
      true,
    );
  });
}
