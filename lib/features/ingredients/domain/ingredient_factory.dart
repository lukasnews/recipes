import '../../../core/units/units.dart';
import 'ingredient.dart';

/// Base unit guess for a new ingredient from the unit it was first used with.
BaseUnit guessBaseUnit(String? unit) {
  final def = Units.byKey(unit);
  return def?.base ?? BaseUnit.pcs;
}

/// Creates a new ingredient from a free text name (rule 5 of matching).
Ingredient newIngredient(String id, String name, {String? unit}) {
  final trimmed = name.trim();
  final display = trimmed.isEmpty
      ? trimmed
      : trimmed[0].toUpperCase() + trimmed.substring(1);
  return Ingredient(id: id, name: display, baseUnit: guessBaseUnit(unit));
}
