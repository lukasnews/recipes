import 'units.dart';

/// How amounts are shown; a per-person preference.
enum UnitDisplay {
  /// As written in the recipe.
  original,

  /// g / ml, switching to kg / l from 1000.
  metric,

  /// Austrian: dag for 10 g – < 1 kg, kg above; liquids in ml / l.
  austrian;

  static UnitDisplay parse(String? v) =>
      UnitDisplay.values.firstWhere((u) => u.name == v, orElse: () => original);
}

const _massToG = {'mg': 0.001, 'g': 1.0, 'dag': 10.0, 'kg': 1000.0};
const _volumeToMl = {'ml': 1.0, 'cl': 10.0, 'dl': 100.0, 'l': 1000.0};

/// Converts an amount for display. Only plain mass and volume units are
/// converted; EL, TL, Prise, Stk., Pkg. and the like stay as they are.
(double, String?) convertForDisplay(
  double amount,
  String? unit,
  UnitDisplay mode,
) {
  if (mode == UnitDisplay.original || unit == null) return (amount, unit);

  final g = _massToG[unit];
  if (g != null) {
    final grams = amount * g;
    if (grams >= 1000) return (grams / 1000, 'kg');
    if (mode == UnitDisplay.austrian && grams >= 10) return (grams / 10, 'dag');
    return (grams, 'g');
  }
  final ml = _volumeToMl[unit];
  if (ml != null) {
    final millis = amount * ml;
    if (millis >= 1000) return (millis / 1000, 'l');
    return (millis, 'ml');
  }
  return (amount, unit);
}

/// Display text like "25 dag" or "½ TL".
String displayQuantity(double? amount, String? unit, UnitDisplay mode) {
  if (amount == null) return formatWithUnit(null, unit);
  final (a, u) = convertForDisplay(amount, unit, mode);
  if (mode != UnitDisplay.original && (u == 'kg' || u == 'l')) {
    // "1,5 kg" reads better than "1 ½ kg" for converted amounts.
    return '${formatAmount(a, fractions: false)} $u';
  }
  return formatWithUnit(a, u);
}
