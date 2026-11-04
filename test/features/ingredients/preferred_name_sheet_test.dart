import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('pick preferred term from the ingredient list', (tester) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Zutaten verwalten'), 200);
    await tester.tap(find.text('Zutaten verwalten'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Schlagobers'),
        matching: find.byTooltip('Angezeigten Namen wählen'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<String>, 'Sahne'));
    await tester.pumpAndSettle();

    final doc = await db.doc('households/$hid/ingredients/schlagobers').get();
    expect(doc.data()!['name'], 'Sahne');
    expect(doc.data()!['synonyms'], ['Schlagobers']);
    expect(find.text('Wird jetzt als „Sahne“ angezeigt'), findsOneWidget);
  });
}
