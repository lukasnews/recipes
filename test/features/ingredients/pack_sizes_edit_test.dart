import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('add and change pack sizes of an ingredient', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await db.doc('households/$hid/ingredients/schlagobers').update({
      'packSizes': [250],
    });
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Zutaten verwalten'), 200);
    await tester.tap(find.text('Zutaten verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schlagobers'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(ActionChip, 'Packung hinzufügen'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Packung hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '500');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InputChip, '250 Stk.'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '200');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final doc = await db.doc('households/$hid/ingredients/schlagobers').get();
    expect(doc.data()!['packSizes'], [500, 200]);
  });
}
