import '../../../core/matching/ingredient_matcher.dart';
import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../pantry/domain/pantry_item.dart';
import 'shopping_item.dart';

/// One checked shopping item on its way into the pantry. The user can
/// change everything before confirming.
class TransferLine {
  TransferLine({
    required this.item,
    this.ingredient,
    this.amount,
    this.unit,
    this.location = StorageLocation.pantry,
  });

  final ShoppingItem item;
  Ingredient? ingredient;
  double? amount;
  String? unit;
  StorageLocation location;

  /// Amount in the ingredient's base unit; null if unknown or no conversion.
  double? get baseAmount {
    final ing = ingredient;
    final a = amount;
    if (ing == null || a == null || a <= 0) return null;
    return ing.toBase(
      a,
      unit == 'Stk.' && ing.baseUnit == BaseUnit.pcs ? null : unit,
    );
  }
}

StorageLocation defaultLocation(Aisle aisle) => switch (aisle) {
  Aisle.dairy || Aisle.meat => StorageLocation.fridge,
  Aisle.frozen => StorageLocation.freezer,
  _ => StorageLocation.pantry,
};

/// Prefills transfer lines for all checked items. Items that were added as
/// free text get a certain match now if the ingredient exists meanwhile.
List<TransferLine> planTransfer(
  List<ShoppingItem> items,
  Map<String, Ingredient> ingredients,
  IngredientMatcher matcher,
) {
  return [
    for (final item in items.where((i) => i.checked))
      () {
        var ing = ingredients[item.ingredientId];
        if (ing == null) {
          final m = matcher.match(item.text);
          if (m.isMatch && !m.isUncertain) ing = ingredients[m.id];
        }
        var amount = item.amount;
        var unit = item.unit;
        if (ing != null) {
          // Keep the list's unit ("5 kg" bananas counted in pieces): a
          // missing conversion is asked once on confirm, never guessed.
          if (unit == null || amount == null) unit = ing.unitChoices.first;
          // "Eier" without amount: one piece is the obvious guess for pcs,
          // anything else the user fills in.
          if (amount == null && ing.baseUnit == BaseUnit.pcs) amount = 1;
        }
        return TransferLine(
          item: item,
          ingredient: ing,
          amount: amount,
          unit: unit,
          location: ing == null
              ? StorageLocation.pantry
              : defaultLocation(ing.aisle),
        );
      }(),
  ];
}

/// Unit choices for a transfer line: the ingredient's own units, the
/// list's unit and the common ones; missing conversions are asked once.
List<String> transferUnits(Ingredient ing, String? current) =>
    {...ing.unitChoices, ?current, 'g', 'kg', 'ml', 'l', 'Stk.'}.toList();
