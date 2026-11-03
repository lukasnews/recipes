import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/shopping/data/shopping_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ShoppingRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ShoppingRepository(db, 'h1', 'u1');
  });

  test('same unchecked ingredient adds up instead of duplicating', () async {
    await repo.add(
      text: 'Milch',
      current: const [],
      ingredientId: 'milch',
      amount: 500,
      unit: 'ml',
    );
    var items = await repo.watchAll().first;
    await repo.add(
      text: 'Milch',
      current: items,
      ingredientId: 'milch',
      amount: 250,
      unit: 'ml',
    );
    items = await repo.watchAll().first;
    expect(items, hasLength(1));
    expect(items.single.amount, 750);
  });

  test('checked item does not absorb new amount', () async {
    await repo.add(
      text: 'Ei',
      current: const [],
      ingredientId: 'ei',
      amount: 2,
    );
    var items = await repo.watchAll().first;
    await repo.setChecked(items.single.id, true);
    items = await repo.watchAll().first;
    await repo.add(text: 'Ei', current: items, ingredientId: 'ei', amount: 6);
    expect(await repo.watchAll().first, hasLength(2));
  });

  test('moveCheckedToPantry increments stock in base unit', () async {
    const milk = Ingredient(id: 'milch', name: 'Milch', baseUnit: BaseUnit.ml);
    const butter = Ingredient(
      id: 'butter',
      name: 'Butter',
      baseUnit: BaseUnit.g,
    );
    await db.doc('households/h1/pantry/milch').set({'amount': 200});
    await repo.add(
      text: 'Milch',
      current: const [],
      ingredientId: 'milch',
      amount: 1,
      unit: 'l',
    );
    await repo.add(
      text: 'Butter',
      current: const [],
      ingredientId: 'butter',
      amount: 1,
      unit: 'Becher', // no conversion known
    );
    var items = await repo.watchAll().first;
    for (final i in items) {
      await repo.setChecked(i.id, true);
    }
    items = await repo.watchAll().first;
    await repo.moveCheckedToPantry(items, {'milch': milk, 'butter': butter});
    final pantry = await db.doc('households/h1/pantry/milch').get();
    expect(pantry.data()!['amount'], 1200);
    final left = await repo.watchAll().first;
    expect(left.map((i) => i.text), ['Butter']);
  });
}
