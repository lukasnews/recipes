import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import 'shopping_item.dart';

/// How many packs of which size cover a need, e.g. 300 g nuts with packs of
/// 100/250/500 g -> 1 × 500 g; 1.2 l milk with ½ l and 1 l -> 2 × 1 l.
typedef PackPick = ({int count, double size});

/// Most pack sizes remembered per ingredient; the oldest is dropped.
const maxPackSizes = 6;

/// The smallest pack that covers [need] (base unit), otherwise as many of the
/// largest pack as needed. Null without sizes or need.
PackPick? pickPack(double? need, List<double> sizes) {
  if (need == null || need <= 0 || sizes.isEmpty) return null;
  final sorted = [...sizes]..sort();
  for (final s in sorted) {
    if (s >= need - 1e-9) return (count: 1, size: s);
  }
  final largest = sorted.last;
  return (count: (need / largest - 1e-9).ceil(), size: largest);
}

/// [sizes] with [bought] (base unit) added, or null if nothing changes:
/// a known size isn't new, nor a whole multiple of the [suggested] pack
/// (3 × 250 g = 750 g). Other multiples are real sizes (100 g and 500 g).
List<double>? learnPackSize(
  List<double> sizes,
  double bought, {
  double? suggested,
}) {
  if (bought <= 0) return null;
  if (sizes.any((s) => (s - bought).abs() < 1e-6)) return null;
  if (suggested != null && suggested > 0) {
    final ratio = bought / suggested;
    if (ratio >= 1 - 1e-6 && (ratio - ratio.round()).abs() < 0.01) {
      return null;
    }
  }
  final next = [...sizes, bought];
  return next.length > maxPackSizes
      ? next.sublist(next.length - maxPackSizes)
      : next;
}

/// A pack amount in a readable unit: 1000 ml -> (1, "l"), 250 g -> (250, "g").
(double, String) packAmount(double base, BaseUnit unit) => switch (unit) {
  BaseUnit.g when base >= 1000 => (base / 1000, 'kg'),
  BaseUnit.ml when base >= 1000 => (base / 1000, 'l'),
  BaseUnit.g => (base, 'g'),
  BaseUnit.ml => (base, 'ml'),
  BaseUnit.pcs => (base, 'Stk.'),
};

/// "1 Pkg. (500 g)" / "2 × 1 l" for the shopping list.
String packHint(PackPick pick, BaseUnit unit, String packLabel) {
  final size = formatBaseAmount(pick.size, unit);
  return pick.count == 1 ? '$packLabel ($size)' : '${pick.count} × $size';
}

/// Pack hint for an open shopping item, or null when no pack size is known
/// or the need is exactly one pack anyway.
String? shoppingPackHint(ShoppingItem item, Ingredient? ing, String packLabel) {
  final a = item.amount;
  if (ing == null || a == null || item.checked) return null;
  final unit = item.unit == 'Stk.' && ing.baseUnit == BaseUnit.pcs
      ? null
      : item.unit;
  final need = ing.toBase(a, unit);
  final pick = pickPack(need, ing.packSizes);
  if (pick == null || need == null) return null;
  if (pick.count == 1 && (pick.size - need).abs() < 1e-6) return null;
  return packHint(pick, ing.baseUnit, packLabel);
}
