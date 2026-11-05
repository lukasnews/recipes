import 'pantry_item.dart';

/// Inventory: what was counted (ingredient id -> amount in base unit) as
/// increments against the stock the count started from. Increments keep
/// changes from other phones made meanwhile (never read-and-overwrite).
Map<String, double> inventoryDeltas(
  Map<String, double> counted,
  Map<String, PantryItem> startedFrom,
) => {
  for (final e in counted.entries)
    if (startedFrom[e.key] case final item?)
      if ((e.value - item.amount).abs() > 1e-9) e.key: e.value - item.amount,
};
