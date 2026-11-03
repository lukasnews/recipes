import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/core/units/units.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';
import 'package:recipes/features/shopping/domain/pantry_transfer.dart';
import 'package:recipes/features/shopping/domain/shopping_item.dart';

void main() {
  const milk = Ingredient(
    id: 'milch',
    name: 'Milch',
    baseUnit: BaseUnit.ml,
    aisle: Aisle.dairy,
  );
  const eggs = Ingredient(
    id: 'ei',
    name: 'Ei',
    synonyms: ['Eier'],
    aisle: Aisle.dairy,
  );
  const butter = Ingredient(
    id: 'butter',
    name: 'Butter',
    baseUnit: BaseUnit.g,
    aisle: Aisle.dairy,
    conversions: {'Pkg.': 250},
  );
  const peas = Ingredient(
    id: 'erbsen',
    name: 'Erbsen',
    baseUnit: BaseUnit.g,
    aisle: Aisle.frozen,
  );
  final byId = {
    for (final i in [milk, eggs, butter, peas]) i.id: i,
  };
  final matcher = IngredientMatcher(byId.values.map((i) => i.candidate));

  ShoppingItem item(
    String id,
    String text, {
    String? ing,
    double? amount,
    String? unit,
    bool checked = true,
  }) => ShoppingItem(
    id: id,
    text: text,
    ingredientId: ing,
    amount: amount,
    unit: unit,
    checked: checked,
  );

  test('prefills amounts, units and locations', () {
    final lines = planTransfer(
      [
        item('1', 'Milch', ing: 'milch', amount: 1, unit: 'l'),
        item('2', 'Eier', ing: 'ei'),
        item('3', 'Butter', ing: 'butter', amount: 1, unit: 'Stk.'),
        item('4', 'Erbsen'), // added as free text, matched now
        item('5', 'Spülmittel'),
        item('6', 'Brot', checked: false),
      ],
      byId,
      matcher,
    );

    expect(lines, hasLength(5));
    expect(lines[0].baseAmount, 1000);
    expect(lines[0].location, StorageLocation.fridge);
    // Eggs without amount: 1 piece.
    expect(lines[1].amount, 1);
    expect(lines[1].baseAmount, 1);
    // Unknown unit falls back to the base unit for the user to fix.
    expect(lines[2].unit, 'g');
    expect(lines[3].ingredient?.id, 'erbsen');
    expect(lines[3].location, StorageLocation.freezer);
    expect(lines[3].baseAmount, isNull); // no amount yet
    expect(lines[4].ingredient, isNull);
  });

  test('ingredient specific units convert', () {
    final line = planTransfer(
      [item('1', 'Butter', ing: 'butter', amount: 2, unit: 'Pkg.')],
      byId,
      matcher,
    ).single;
    expect(line.baseAmount, 500);
  });
}
