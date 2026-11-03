import '../../../core/firebase/map_utils.dart';

enum StorageLocation {
  fridge,
  pantry,
  freezer;

  static StorageLocation parse(String? v) => StorageLocation.values.firstWhere(
    (l) => l.name == v,
    orElse: () => pantry,
  );
}

/// Stock of one ingredient. Document id = ingredient id.
class PantryItem {
  const PantryItem({
    required this.ingredientId,
    required this.amount,
    this.location = StorageLocation.pantry,
    this.minAmount,
    this.expiresOn,
  });

  factory PantryItem.fromMap(String id, Map<String, dynamic> m) => PantryItem(
    ingredientId: id,
    amount: m.dbl('amount') ?? 0,
    location: StorageLocation.parse(m.strOrNull('location')),
    minAmount: m.dbl('minAmount'),
    expiresOn: m.date('expiresOn'),
  );

  final String ingredientId;

  /// Always in the ingredient's base unit.
  final double amount;
  final StorageLocation location;
  final double? minAmount;
  final DateTime? expiresOn;

  bool get isBelowMin => minAmount != null && amount < minAmount!;
}
