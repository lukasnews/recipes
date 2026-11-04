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

  Expiry expiry(DateTime now) => expiryOf(expiresOn, now);
}

enum Expiry { none, soon, expired }

/// Items expiring within this many days count as "bald ablaufend".
const expirySoonDays = 3;

Expiry expiryOf(DateTime? expiresOn, DateTime now) {
  if (expiresOn == null) return Expiry.none;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(expiresOn.year, expiresOn.month, expiresOn.day);
  final days = day.difference(today).inDays;
  if (days < 0) return Expiry.expired;
  if (days <= expirySoonDays) return Expiry.soon;
  return Expiry.none;
}

/// Ingredient ids in stock that expire soon or already expired.
Set<String> expiringIds(Map<String, PantryItem> pantry, DateTime now) => {
  for (final p in pantry.values)
    if (p.amount > 0 && p.expiry(now) != Expiry.none) p.ingredientId,
};
