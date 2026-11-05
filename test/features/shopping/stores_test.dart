import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/shopping/domain/shopping_item.dart';
import 'package:recipes/features/shopping/domain/stores.dart';

void main() {
  const ingredients = {
    'milch': Ingredient(id: 'milch', name: 'Milch', stores: ['Spar', 'Hofer']),
    'semmel': Ingredient(id: 'semmel', name: 'Semmel', stores: ['Hofer']),
    'zitrone': Ingredient(id: 'zitrone', name: 'Zitrone'),
  };
  const milch = ShoppingItem(
    id: '1',
    text: 'Milch',
    ingredientId: 'milch',
    aisle: Aisle.dairy,
  );
  const semmel = ShoppingItem(
    id: '2',
    text: 'Semmel',
    ingredientId: 'semmel',
    aisle: Aisle.bread,
  );
  const zitrone = ShoppingItem(
    id: '3',
    text: 'Zitrone',
    ingredientId: 'zitrone',
  );
  const offer = ShoppingItem(
    id: '4',
    text: 'Kaffee',
    store: 'Billa',
    aisle: Aisle.drinks,
  );
  const stores = ['Hofer', 'Billa', 'Spar'];

  test('grouped under the first shop in household order, anywhere last', () {
    final groups = groupByStore(
      [zitrone, milch, offer, semmel],
      ingredients,
      stores,
      Aisle.values,
    );
    expect(
      [
        for (final (s, items) in groups)
          '$s: ${items.map((i) => i.id).join(',')}',
      ],
      ['Hofer: 2,1', 'Billa: 4', 'null: 3'],
    );
  });

  test('"Nur Spar" shows what Spar has and what does not care', () {
    bool at(ShoppingItem i) =>
        availableAt(i, ingredients[i.ingredientId], 'Spar');
    expect([milch, semmel, zitrone, offer].where(at).map((i) => i.id), [
      '1',
      '3',
    ]);
    expect(availableAt(semmel, ingredients['semmel'], null), isTrue);
  });

  test('a fixed shop for this purchase wins over the usual ones', () {
    const milchOffer = ShoppingItem(
      id: '5',
      text: 'Milch',
      ingredientId: 'milch',
      store: 'Billa',
    );
    expect(itemStores(milchOffer, ingredients['milch']), ['Billa']);
    expect(availableAt(milchOffer, ingredients['milch'], 'Hofer'), isFalse);
  });
}
