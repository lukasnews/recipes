import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/display_units.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/shopping/domain/shopping_item.dart';
import 'package:recipes/features/shopping/presentation/shopping_list_screen.dart';

void main() {
  test('open items grouped by aisle in the own order', () {
    const items = [
      ShoppingItem(
        id: '1',
        text: 'Milch',
        amount: 1000,
        unit: 'ml',
        aisle: Aisle.dairy,
      ),
      ShoppingItem(
        id: '2',
        text: 'Tomaten',
        ingredientId: 'p',
        amount: 6,
        unit: 'Stk.',
        aisle: Aisle.produce,
      ),
      ShoppingItem(id: '3', text: 'Brot', aisle: Aisle.bread, checked: true),
      ShoppingItem(id: '4', text: 'Spülmittel'),
    ];
    final text = shoppingShareText(
      items,
      {
        'p': const Ingredient(
          id: 'p',
          name: 'Paradeiser',
          aisle: Aisle.produce,
        ),
      },
      title: 'Einkaufsliste',
      aisleName: (a) => a.name,
      display: UnitDisplay.metric,
      order: [Aisle.dairy, ...Aisle.values.where((a) => a != Aisle.dairy)],
    );
    expect(
      text,
      'Einkaufsliste\n\ndairy\n- 1 l Milch\n\nproduce\n- 6 Paradeiser'
      '\n\nother\n- Spülmittel',
    );
  });
}
