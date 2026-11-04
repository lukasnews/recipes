/// A packaged product found by its barcode.
class Product {
  const Product({
    required this.code,
    required this.name,
    this.brand,
    this.amount,
    this.unit,
  });

  final String code;
  final String name;
  final String? brand;

  /// Package size, e.g. 500 + "g".
  final double? amount;
  final String? unit;
}

final _quantity = RegExp(
  r'^(?:(\d+)\s*[x×]\s*)?(\d+(?:[.,]\d+)?)\s*(kg|g|mg|l|ml|cl|dl|stk\.?|stück)\b',
  caseSensitive: false,
);

/// "500 g" -> (500, g); "6 x 0,5 l" -> (3, l); "10 Stück" -> (10, Stk.).
(double, String)? parseProductQuantity(String? text) {
  if (text == null) return null;
  final m = _quantity.firstMatch(text.trim());
  if (m == null) return null;
  final count = int.tryParse(m.group(1) ?? '') ?? 1;
  final value = double.tryParse(m.group(2)!.replaceAll(',', '.'));
  if (value == null) return null;
  final raw = m.group(3)!.toLowerCase();
  final unit = raw.startsWith('st') ? 'Stk.' : raw;
  return (value * count, unit);
}
