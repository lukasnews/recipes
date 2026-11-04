import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/pantry/domain/product.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('scan -> Open Food Facts -> pantry, code remembered', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await db
        .collection('households')
        .doc(hid)
        .collection('ingredients')
        .doc('mehl-glatt')
        .update({'baseUnit': 'g'});
    final lookup = FakeProductLookup(
      const Product(
        code: '9001',
        name: 'Mehl glatt Type 480',
        brand: 'Fini',
        amount: 1,
        unit: 'kg',
      ),
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        barcodes: FakeBarcodeReader('9001'),
        products: lookup,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorrat'));
    await tester.pumpAndSettle();

    Future<void> scanAndAdd() async {
      await tester.tap(find.byTooltip('Barcode scannen'));
      await tester.pumpAndSettle();
      expect(find.text('Fini · Mehl glatt Type 480'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'In den Vorrat'));
      await tester.pumpAndSettle();
    }

    await scanAndAdd();
    final h = db.collection('households').doc(hid);
    expect(
      (await h.collection('pantry').doc('mehl-glatt').get()).data()!['amount'],
      1000,
    );
    expect(
      (await h.collection('barcodes').doc('9001').get())
          .data()!['ingredientId'],
      'mehl-glatt',
    );

    // Second scan uses the remembered code, no lookup.
    lookup.product = null;
    await scanAndAdd();
    expect(lookup.calls, 1);
    expect(
      (await h.collection('pantry').doc('mehl-glatt').get()).data()!['amount'],
      2000,
    );
  });
}
