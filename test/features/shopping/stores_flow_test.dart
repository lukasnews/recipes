import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('usual shop, this time elsewhere, list by shop, only Hofer', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final h = db.collection('households').doc(hid);
    await h.collection('shopping').doc('a').set({
      'text': 'Mehl glatt',
      'ingredientId': 'mehl-glatt',
      'aisle': 'baking',
      'checked': false,
    });
    await h.collection('shopping').doc('b').set({
      'text': 'Schlagobers',
      'ingredientId': 'schlagobers',
      'aisle': 'dairy',
      'checked': false,
    });
    await h.collection('shopping').doc('c').set({
      'text': 'Spülmittel',
      'aisle': 'other',
      'checked': false,
    });
    final urls = FakeUrlOpener();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        urlOpener: urls,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einkauf'));
    await tester.pumpAndSettle();

    // Mehl: usually at Hofer.
    await tester.longPress(find.text('Mehl glatt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Hofer'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(
      (await h.collection('ingredients').doc('mehl-glatt').get())['stores'],
      ['Hofer'],
    );

    // Schlagobers: this time at Billa (offer).
    await tester.longPress(find.text('Schlagobers'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RadioListTile<String?>, 'Billa'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect((await h.collection('shopping').doc('b').get())['store'], 'Billa');

    // List by shop: Hofer, Billa, then "Egal wo".
    await tester.tap(find.byTooltip('Nach Geschäft'));
    await tester.pumpAndSettle();
    final hofer = tester.getTopLeft(find.text('Hofer')).dy;
    final billa = tester.getTopLeft(find.text('Billa')).dy;
    final anywhere = tester.getTopLeft(find.text('Egal wo')).dy;
    expect(hofer < billa && billa < anywhere, isTrue);

    // In the Hofer shop: Mehl and Spülmittel, not the Billa offer.
    await tester.tap(find.widgetWithText(FilterChip, 'Nur Hofer'));
    await tester.pumpAndSettle();
    expect(find.text('Mehl glatt'), findsOneWidget);
    expect(find.text('Spülmittel'), findsOneWidget);
    expect(find.text('Schlagobers'), findsNothing);

    // Flyer of the shop and an offer search for an item.
    await tester.tap(find.widgetWithText(ActionChip, 'Flugblatt'));
    await tester.pumpAndSettle();
    expect(urls.opened.last.host, 'www.hofer.at');
    await tester.longPress(find.text('Mehl glatt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktionen suchen'));
    await tester.pumpAndSettle();
    expect(
      urls.opened.last.toString(),
      'https://www.wogibtswas.at/ta/mehl-glatt',
    );
  });
}
