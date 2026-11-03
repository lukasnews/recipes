import '../../../core/firebase/map_utils.dart';
import '../../ingredients/domain/ingredient.dart';

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    this.ingredientId,
    this.amount,
    this.unit,
    this.aisle = Aisle.other,
    this.checked = false,
    this.fromRecipeId,
    this.addedBy,
    this.createdAt,
  });

  factory ShoppingItem.fromMap(String id, Map<String, dynamic> m) =>
      ShoppingItem(
        id: id,
        text: m.str('text'),
        ingredientId: m.strOrNull('ingredientId'),
        amount: m.dbl('amount'),
        unit: m.strOrNull('unit'),
        aisle: Aisle.parse(m.strOrNull('aisle')),
        checked: m.flag('checked'),
        fromRecipeId: m.strOrNull('fromRecipeId'),
        addedBy: m.strOrNull('addedBy'),
        createdAt: m.date('createdAt'),
      );

  final String id;
  final String text;
  final String? ingredientId;
  final double? amount;
  final String? unit;
  final Aisle aisle;
  final bool checked;
  final String? fromRecipeId;
  final String? addedBy;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'text': text,
    'ingredientId': ?ingredientId,
    'amount': ?amount,
    'unit': ?unit,
    'aisle': aisle.name,
    'checked': checked,
    'fromRecipeId': ?fromRecipeId,
    'addedBy': ?addedBy,
  };
}
