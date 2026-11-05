import '../../../core/matching/ingredient_matcher.dart';
import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../pantry/domain/pantry_item.dart';
import 'pack_sizes.dart';
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
    this.prefillBase,
    this.suggestedPack,
  });

  /// The pack size the suggestion was built from, if any.
  final double? suggestedPack;

  /// What was suggested (base unit); a different amount on confirm is a new
  /// pack size worth remembering.
  final double? prefillBase;

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
    return ing.toBase(a, _unitForBase(ing, unit));
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
        PackPick? pick;
        if (ing != null) {
          // Keep the list's unit ("5 kg" bananas counted in pieces): a
          // missing conversion is asked once on confirm, never guessed.
          if (unit == null || amount == null) unit = ing.unitChoices.first;
          // "Eier" without amount: one piece is the obvious guess for pcs,
          // anything else the user fills in.
          if (amount == null && ing.baseUnit == BaseUnit.pcs) amount = 1;
          // Known pack sizes: suggest whole packs ("125 g" -> 1 × 200 g).
          final need = amount == null
              ? null
              : ing.toBase(amount, _unitForBase(ing, unit));
          pick = pickPack(need, ing.packSizes);
          if (pick != null) {
            (amount, unit) = packAmount(pick.count * pick.size, ing.baseUnit);
          }
        }
        return TransferLine(
          item: item,
          ingredient: ing,
          amount: amount,
          unit: unit,
          suggestedPack: pick?.size,
          prefillBase: ing == null || amount == null
              ? null
              : ing.toBase(amount, _unitForBase(ing, unit)),
          location: ing == null
              ? StorageLocation.pantry
              : defaultLocation(ing.aisle),
        );
      }(),
  ];
}

String? _unitForBase(Ingredient ing, String? unit) =>
    unit == 'Stk.' && ing.baseUnit == BaseUnit.pcs ? null : unit;

/// Pack sizes to remember after confirming [line] with [base] (base unit),
/// or null if nothing new: only amounts the user changed are learned, so
/// loose goods taken as suggested don't pile up sizes.
List<double>? learnedPackSizes(TransferLine line, double base) {
  final ing = line.ingredient;
  if (ing == null) return null;
  final prefill = line.prefillBase;
  if (prefill != null && (prefill - base).abs() < 1e-6) return null;
  return learnPackSize(ing.packSizes, base, suggested: line.suggestedPack);
}

/// Unit choices for a transfer line: the ingredient's own units, the
/// list's unit and the common ones; missing conversions are asked once.
List<String> transferUnits(Ingredient ing, String? current) =>
    {...ing.unitChoices, ?current, 'g', 'kg', 'ml', 'l', 'Stk.'}.toList();
