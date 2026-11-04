import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/pantry/data/barcode_repository.dart';
import 'package:recipes/features/pantry/data/product_lookup.dart';
import 'package:recipes/features/pantry/domain/product.dart';

void main() {
  test('parseProductQuantity', () {
    expect(parseProductQuantity('500 g'), (500.0, 'g'));
    expect(parseProductQuantity('1,5 l'), (1.5, 'l'));
    expect(parseProductQuantity('6 x 0,5 L'), (3.0, 'l'));
    expect(parseProductQuantity('10 Stück'), (10.0, 'Stk.'));
    expect(parseProductQuantity('ca. eine Packung'), isNull);
  });

  test('parseOpenFoodFacts prefers the German name', () {
    final p = parseOpenFoodFacts('9001234567890', {
      'status': 1,
      'product': {
        'product_name': 'Whole milk',
        'product_name_de': 'Vollmilch',
        'brands': 'Schärdinger, Berglandmilch',
        'quantity': '1 l',
      },
    })!;
    expect(p.name, 'Vollmilch');
    expect(p.brand, 'Schärdinger');
    expect(p.amount, 1);
    expect(p.unit, 'l');
    expect(parseOpenFoodFacts('1', {'status': 0}), isNull);
  });

  test('known barcodes are remembered', () async {
    final repo = BarcodeRepository(FakeFirebaseFirestore(), 'h');
    expect(await repo.get('123'), isNull);
    await repo.save(
      '123',
      const KnownBarcode(ingredientId: 'milch', amount: 1, unit: 'l'),
    );
    final b = (await repo.get('123'))!;
    expect(b.ingredientId, 'milch');
    expect(b.amount, 1);
    expect(b.unit, 'l');
  });
}
