import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/import/data/recipe_import_service.dart';
import 'package:recipes/features/shopping/data/shopping_repository.dart';
import 'package:recipes/features/shopping/domain/shopping_scan.dart';

import '../../helpers/fakes.dart';

void main() {
  group('shoppingLinesFromText', () {
    test('bullets, headings, commas and duplicates', () {
      const text = '''
Einkaufsliste:
- 1,5 l Milch
• Eier, Brot
☐ Topfen
2) Butter
butter
500
''';
      expect(shoppingLinesFromText(text), [
        '1,5 l Milch',
        'Eier',
        'Brot',
        'Topfen',
        'Butter',
      ]);
    });

    test('AI lines keep commas inside an item', () {
      expect(dedupeLines([' Mehl, glatt ', '', 'mehl, glatt', 'Zucker']), [
        'Mehl, glatt',
        'Zucker',
      ]);
    });
  });

  group('readShoppingList', () {
    test('AI first', () async {
      final scan = await fakeImportService(extractor: FakeExtractor(const []))
          .readShoppingList(['/tmp/zettel.jpg']);
      expect(scan.lines, ['500 g Mehl', '2 Zitronen', 'Spülmittel']);
      expect(scan.offline, isFalse);
    });

    test('OCR when the AI fails', () async {
      final scan = await fakeImportService(ocrText: 'Milch\nEier, Brot')
          .readShoppingList(['/tmp/zettel.jpg']);
      expect(scan.lines, ['Milch', 'Eier', 'Brot']);
      expect(scan.offline, isTrue);
      expect(scan.aiError, isNotNull);
    });
  });

  testWidgets('photo → review → onto the list, merged with open items', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final repo = ShoppingRepository(db, hid, 'u1');
    await repo.add(
      text: 'Mehl glatt',
      current: const [],
      ingredientId: 'mehl-glatt',
      amount: 1000,
      unit: 'g',
    );
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        importService: fakeImportService(extractor: FakeExtractor(const [])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einkauf'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Einkaufszettel fotografieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zettel fotografieren'));
    await tester.pumpAndSettle();

    expect(find.text('Erkannte Einträge'), findsOneWidget);
    expect(find.text('Schon auf der Liste – Menge wird dazugezählt'), findsOne);
    // Leave out the lemons.
    await tester.tap(find.widgetWithText(CheckboxListTile, '2 Zitronen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 Einträge hinzufügen'));
    await tester.pumpAndSettle();

    final docs = (await db.collection('households/$hid/shopping').get()).docs
        .map((d) => d.data())
        .toList();
    expect(docs, hasLength(2));
    final mehl = docs.firstWhere((d) => d['ingredientId'] == 'mehl-glatt');
    expect(mehl['amount'], 1500);
    expect(docs.any((d) => d['text'] == 'Spülmittel'), isTrue);
    expect(docs.any((d) => '${d['text']}'.contains('Zitrone')), isFalse);
  });
}
