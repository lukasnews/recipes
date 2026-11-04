import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('new ingredient similar to an existing one asks first', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorrat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In den Vorrat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Schlagsahne flüssig');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('anlegen').first);
    await tester.pumpAndSettle();

    expect(find.text('Gibt es schon?'), findsOneWidget);
    await tester.tap(find.text('Schlagobers verwenden'));
    await tester.pumpAndSettle();
    // Add sheet for the existing ingredient, no new one created.
    expect(find.text('Schlagobers'), findsWidgets);
    final ings = await db
        .collection('households')
        .doc(hid)
        .collection('ingredients')
        .get();
    expect(ings.docs.length, testSeed.length);
  });
}
