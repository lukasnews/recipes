import '../../ingredients/domain/ingredient.dart';
import '../../pantry/domain/pantry_item.dart';
import 'recipe.dart';

/// Factor that makes a line needing [needed] use exactly [have]
/// (same unit): 300 g of 400 g → 0.75. Null if either is not positive.
double? factorForAvailable(double needed, double have) =>
    needed > 0 && have > 0 ? have / needed : null;

/// Pantry stock of [line]'s ingredient in the line's own unit (200 g
/// Topfen in stock, line in "g" → 200). Null if nothing is in stock or the
/// unit can't be converted.
double? stockInLineUnit(
  RecipeIngredient line,
  Ingredient? ingredient,
  PantryItem? stock,
) {
  if (ingredient == null || stock == null || stock.amount <= 0) return null;
  final perUnit = ingredient.toBase(1, line.unit);
  if (perUnit == null || perUnit <= 0) return null;
  return stock.amount / perUnit;
}
