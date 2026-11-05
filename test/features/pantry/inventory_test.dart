import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/pantry/data/pantry_repository.dart';
import 'package:recipes/features/pantry/domain/inventory.dart';
import 'package:recipes/features/pantry/domain/pantry_item.dart';

import '../../helpers/fakes.dart';

void main() {
  test('only real differences become increments', () {
    const start = {
      'a': PantryItem(ingredientId: 'a', amount: 500),
      'b': PantryItem(ingredientId: 'b', amount: 2),
    };
    expect(inventoryDeltas({'a': 300, 'b': 2}, start), {'a': -200});
    expect(inventoryDeltas({'x': 1}, start), isEmpty);
  });

  testWidgets('count the pantry: confirm, correct, empty', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final pantry = PantryRepository(db, hid);
    await pantry.changeAmount('mehl-glatt', 1000);
    await pantry.changeAmount('schlagobers', 250);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorrat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Inventur'));
    await tester.pumpAndSettle();

    // Sorted by place, then name: Mehl glatt, Schlagobers.
    expect(find.text('Mehl glatt'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '400');
    await tester.tap(find.text('Stimmt – weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Schlagobers'), findsOneWidget);
    await tester.tap(find.text('Ist leer'));
    await tester.pumpAndSettle();
    expect(find.text('2 von 2 geprüft, 2 geändert.'), findsOneWidget);
    await tester.tap(find.text('2 Änderungen übernehmen').last);
    await tester.pumpAndSettle();

    final h = db.collection('households').doc(hid).collection('pantry');
    expect((await h.doc('mehl-glatt').get()).data()!['amount'], 400);
    expect((await h.doc('schlagobers').get()).data()!['amount'], 0);
  });
}
