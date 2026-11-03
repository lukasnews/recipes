import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
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

  test('transferToPantry adds stock with location and removes items', () async {
    await db.doc('households/h1/pantry/milch').set({'amount': 200});
    await repo.add(text: 'Milch', current: const [], ingredientId: 'milch');
    final items = await repo.watchAll().first;
    await repo.transferToPantry(
      stock: {'milch': (1000, StorageLocation.fridge)},
      removeItemIds: items.map((i) => i.id),
    );
    final pantry = (await db.doc('households/h1/pantry/milch').get()).data()!;
    expect(pantry['amount'], 1200);
    expect(pantry['location'], 'fridge');
    expect(await repo.watchAll().first, isEmpty);
  });
}
