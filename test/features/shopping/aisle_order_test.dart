import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';
import 'package:recipes/features/shopping/domain/aisle_order.dart';

import '../../helpers/fakes.dart';

void main() {
  test('own order first, unknown names dropped, missing appended', () {
    final order = aisleOrder(['bread', 'nonsense', 'dairy', 'bread']);
    expect(order.take(2), [Aisle.bread, Aisle.dairy]);
    expect(order, hasLength(Aisle.values.length));
    expect(aisleOrder(null), Aisle.values);
  });

  testWidgets('shopping list follows the person\'s order', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final shop = db.collection('households').doc(hid).collection('shopping');
    await shop.add({
      'text': 'Paradeiser',
      'aisle': 'produce',
      'checked': false,
    });
    await shop.add({'text': 'Semmeln', 'aisle': 'bread', 'checked': false});
    await db.collection('users').doc('u1').update({
      'aisleOrder': ['bread', 'produce'],
    });
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einkauf'));
    await tester.pumpAndSettle();

    final bread = tester.getTopLeft(find.text('Semmeln')).dy;
    final produce = tester.getTopLeft(find.text('Paradeiser')).dy;
    expect(bread, lessThan(produce));
  });
}
