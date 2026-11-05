import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/pantry/data/pantry_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('hold minus: take out 5 pieces at once; hold plus: add', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final h = db.collection('households').doc(hid);
    await h.collection('ingredients').doc('banane').set({
      'name': 'Banane',
      'aisle': 'produce',
      'baseUnit': 'pcs',
      'pieceGrams': 120,
    });
    await PantryRepository(db, hid).changeAmount('banane', 12);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorrat'));
    await tester.pumpAndSettle();

    Future<num> stock() async =>
        (await h.collection('pantry').doc('banane').get()).data()!['amount']
            as num;

    await tester.longPress(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('Banane entnehmen'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Entnehmen'));
    await tester.pumpAndSettle();
    expect(await stock(), 7);

    // Add 600 g: 5 pieces at 120 g each.
    await tester.longPress(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '600');
    await tester.tap(find.text('Stk.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(await stock(), 12);

    // A short tap still moves one step.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(await stock(), 11);
  });
}
