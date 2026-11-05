import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

Future<String> _bananas(FakeFirebaseFirestore db) async {
  final hid = await seedHousehold(db);
  final h = db.collection('households').doc(hid);
  await h.collection('ingredients').doc('banane').set({
    'name': 'Banane',
    'synonyms': ['Bananen'],
    'aisle': 'produce',
    'baseUnit': 'pcs',
    'conversions': <String, double>{},
  });
  await h.collection('shopping').add({
    'text': 'Banane',
    'ingredientId': 'banane',
    'amount': 5,
    'unit': 'kg',
    'aisle': 'produce',
    'checked': true,
  });
  return hid;
}

Future<void> _openTransfer(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      db: db,
      auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Einkauf'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abgehakte in den Vorrat'));
  await tester.pumpAndSettle();
}

Future<num?> _stock(FakeFirebaseFirestore db, String hid) async =>
    (await db
                .collection('households')
                .doc(hid)
                .collection('pantry')
                .doc('banane')
                .get())
            .data()?['amount']
        as num?;

void main() {
  testWidgets('5 kg bananas kept in pieces: keeps kg, asks once', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final hid = await _bananas(db);
    await _openTransfer(tester, db);

    expect(find.text('kg'), findsOneWidget);
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.text('Wie viel Stk. sind 1 kg Banane?'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '6',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(await _stock(db, hid), 30);
    final banane = await db
        .collection('households')
        .doc(hid)
        .collection('ingredients')
        .doc('banane')
        .get();
    expect((banane.data()!['conversions'] as Map)['kg'], 6);
  });

  testWidgets('switched to Stk.: 5 pieces land in the pantry', (tester) async {
    final db = FakeFirebaseFirestore();
    final hid = await _bananas(db);
    await _openTransfer(tester, db);

    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stk.').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    expect(await _stock(db, hid), 5);
  });
}
