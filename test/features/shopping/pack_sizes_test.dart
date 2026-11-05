import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/shopping/domain/pack_sizes.dart';
import 'package:recipes/features/shopping/domain/pantry_transfer.dart';
import 'package:recipes/features/shopping/domain/shopping_item.dart';

void main() {
  group('pickPack', () {
    const nuts = <double>[250, 100, 500];
    test('smallest pack that covers the need', () {
      expect(pickPack(80, nuts), (count: 1, size: 100.0));
      expect(pickPack(300, nuts), (count: 1, size: 500.0));
      expect(pickPack(250, nuts), (count: 1, size: 250.0));
    });
    test('several of the largest when none is enough', () {
      expect(pickPack(1200, [500, 1000]), (count: 2, size: 1000.0));
      expect(pickPack(2000, [1000]), (count: 2, size: 1000.0));
    });
    test('nothing without sizes or need', () {
      expect(pickPack(100, []), isNull);
      expect(pickPack(null, nuts), isNull);
    });
  });

  group('learnPackSize', () {
    test('adds new sizes, keeps the newest six', () {
      expect(learnPackSize([], 200), [200]);
      expect(learnPackSize([100, 250], 500), [100, 250, 500]);
      expect(learnPackSize([1, 2.5, 4.5, 6.5, 8.5, 10.5], 12.5), [
        2.5,
        4.5,
        6.5,
        8.5,
        10.5,
        12.5,
      ]);
    });
    test('known sizes and whole multiples are not new', () {
      expect(learnPackSize([250], 250), isNull);
      expect(learnPackSize([250], 750, suggested: 250), isNull);
      expect(learnPackSize([100], 500), [100, 500]);
      expect(learnPackSize([250], 125), [250, 125]);
      expect(learnPackSize([250], 0), isNull);
    });
  });

  const nuts = Ingredient(
    id: 'n',
    name: 'Walnüsse',
    baseUnit: BaseUnit.g,
    packSizes: [200],
  );
  const milk = Ingredient(
    id: 'm',
    name: 'Milch',
    baseUnit: BaseUnit.ml,
    aisle: Aisle.dairy,
    packSizes: [500, 1000],
  );
  final byId = {nuts.id: nuts, milk.id: milk};
  final matcher = IngredientMatcher(byId.values.map((i) => i.candidate));

  test('shopping hint', () {
    String? hint(ShoppingItem i) =>
        shoppingPackHint(i, byId[i.ingredientId], '1 Pkg.');
    expect(
      hint(
        const ShoppingItem(
          id: '1',
          text: 'Walnüsse',
          ingredientId: 'n',
          amount: 125,
          unit: 'g',
        ),
      ),
      '1 Pkg. (200 g)',
    );
    expect(
      hint(
        const ShoppingItem(
          id: '2',
          text: 'Milch',
          ingredientId: 'm',
          amount: 1.2,
          unit: 'l',
        ),
      ),
      '2 × 1 l',
    );
    expect(
      hint(
        const ShoppingItem(
          id: '3',
          text: 'Milch',
          ingredientId: 'm',
          amount: 1,
          unit: 'l',
        ),
      ),
      isNull,
    );
  });

  test('transfer suggests whole packs and learns only changed amounts', () {
    final lines = planTransfer(
      const [
        ShoppingItem(
          id: '1',
          text: 'Walnüsse',
          ingredientId: 'n',
          amount: 125,
          unit: 'g',
          checked: true,
        ),
        ShoppingItem(
          id: '2',
          text: 'Milch',
          ingredientId: 'm',
          amount: 1.2,
          unit: 'l',
          checked: true,
        ),
      ],
      byId,
      matcher,
    );
    expect((lines[0].amount, lines[0].unit), (200, 'g'));
    expect((lines[1].amount, lines[1].unit), (2, 'l'));
    expect(learnedPackSizes(lines[0], 200), isNull);
    expect(learnedPackSizes(lines[0], 400), isNull);
    expect(learnedPackSizes(lines[0], 150), [200, 150]);
  });
}
