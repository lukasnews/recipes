import '../../ingredients/domain/ingredient.dart';
import 'shopping_item.dart';

/// Where [item] can be bought: its fixed shop for this purchase, else the
/// ingredient's usual shops (empty = anywhere).
List<String> itemStores(ShoppingItem item, Ingredient? ingredient) =>
    item.store != null ? [item.store!] : (ingredient?.stores ?? const []);

/// "Nur Hofer": items you can get there, plus those that don't care.
bool availableAt(ShoppingItem item, Ingredient? ingredient, String? store) {
  if (store == null) return true;
  final at = itemStores(item, ingredient);
  return at.isEmpty || at.contains(store);
}

/// Shopping list by shop: each item under its first shop in the
/// household's order (null section = "Egal wo", last), within a section by
/// aisle in [aisleOrder]. Shops no longer in the list come after the known
/// ones, alphabetically.
List<(String?, List<ShoppingItem>)> groupByStore(
  List<ShoppingItem> items,
  Map<String, Ingredient> ingredients,
  List<String> stores,
  List<Aisle> aisleOrder,
) {
  int rank(String s) {
    final i = stores.indexOf(s);
    return i < 0 ? stores.length : i;
  }

  final groups = <String?, List<ShoppingItem>>{};
  for (final item in items) {
    final at = [...itemStores(item, ingredients[item.ingredientId])]
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.compareTo(b);
      });
    groups.putIfAbsent(at.firstOrNull, () => []).add(item);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.compareTo(b);
    });
  return [
    for (final k in keys)
      (
        k,
        groups[k]!..sort(
          (a, b) => aisleOrder
              .indexOf(a.aisle)
              .compareTo(aisleOrder.indexOf(b.aisle)),
        ),
      ),
  ];
}
