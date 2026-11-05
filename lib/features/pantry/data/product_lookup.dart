import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/product.dart';

/// Finds a product by barcode. Needs a connection.
abstract class ProductLookup {
  Future<Product?> lookup(String code);
}

/// Open Food Facts (free, no key). Identifies with a generic app name only.
class OpenFoodFactsLookup implements ProductLookup {
  OpenFoodFactsLookup({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const userAgent = 'BaCo/1.0 (Android; household recipe app)';

  @override
  Future<Product?> lookup(String code) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code.json',
      {
        'fields':
            'product_name,product_name_de,generic_name_de,brands,quantity,'
            'product_quantity,product_quantity_unit',
      },
    );
    final res = await _client
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', uri);
    }
    return parseOpenFoodFacts(
      code,
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}

Product? parseOpenFoodFacts(String code, Map<String, dynamic> json) {
  if (json['status'] != 1) return null;
  final p = (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};
  String? s(String k) {
    final v = (p[k] as String?)?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  final name =
      s('product_name_de') ?? s('product_name') ?? s('generic_name_de');
  if (name == null) return null;
  // "quantity" is free text; product_quantity(+_unit) is the parsed number.
  final pq = p['product_quantity'];
  final q =
      parseProductQuantity(s('quantity')) ??
      parseProductQuantity(
        pq == null ? null : '$pq ${s('product_quantity_unit') ?? 'g'}',
      ) ??
      parseProductQuantity(name);
  return Product(
    code: code,
    name: name,
    brand: s('brands')?.split(',').first.trim(),
    amount: q?.$1,
    unit: q?.$2,
  );
}
