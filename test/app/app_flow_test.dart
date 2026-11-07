import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('signed out shows login, email login leads to setup', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final auth = FakeAuthRepository();
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Mit Google anmelden'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-Mail'),
      'a@b.at',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passwort'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Anmelden'));
    await tester.pumpAndSettle();

    expect(find.text('Neuen Haushalt anlegen'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Name des Haushalts'),
      'Zuhause',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Anlegen'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    // New households start with example recipes.
    expect(find.text('Kaiserschmarrn'), findsOneWidget);
  });

  testWidgets('ready household: tabs, settings with invite code', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final code =
        (await db.collection('households').doc(hid).get()).data()!['inviteCode']
            as String;
    final auth = FakeAuthRepository(
      const AuthUser(uid: 'u1', displayName: 'Lukas'),
    );
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    for (final (tab, text) in [
      // Not 'Heute': on weekends today is below the fold of the test view.
      ('Wochenplan', 'Woche ab'),
      ('Einkauf', 'Die Einkaufsliste ist leer'),
      ('Vorrat', 'Der Vorrat ist leer'),
      ('Rezepte', 'Alle'),
    ]) {
      await tester.tap(find.descendant(of: nav, matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(find.textContaining(text), findsWidgets, reason: tab);
    }

    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haushalt'));
    await tester.pumpAndSettle();
    expect(find.text(code), findsOneWidget);
    expect(find.text('Zuhause'), findsOneWidget);
  });

  testWidgets('create recipe: Sahne is linked to Schlagobers', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(testApp(db: db, auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Titel'),
      'Kaiserschmarrn',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Zutaten'),
      '250 ml Sahne\n200 g Mehl\n1 Prise Safran',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('→ 250 ml Schlagobers'), findsOneWidget);
    expect(find.textContaining('wird neu angelegt'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await tester.pumpAndSettle();

    final recipes = await db.collection('households/$hid/recipes').get();
    final data = recipes.docs.single.data();
    expect(data['title'], 'Kaiserschmarrn');
    expect(data['ingredientIds'], containsAll(['schlagobers', 'mehl-glatt']));
    final ings = await db.collection('households/$hid/ingredients').get();
    expect(ings.docs.map((d) => d.data()['name']), contains('Safran'));
    expect(find.text('Kaiserschmarrn'), findsWidgets);
  });

  testWidgets('import from photo opens the review screen', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    final photos = FakePhotoRepository();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: auth,
        photos: photos,
        importService: fakeImportService(
          aiResult: const RecipeDraft(
            title: 'Marillenknödel',
            servings: 4,
            ingredientLines: ['250 g Topfen', '100 ml Sahne'],
            steps: ['Teig machen.'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus Foto oder Screenshot'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aus Foto erkannt'), findsOneWidget);
    expect(find.text('Marillenknödel'), findsOneWidget);
    expect(find.textContaining('→ 100 ml Schlagobers'), findsOneWidget);
    expect(
      find.text('Ausgangsbild auch als Rezeptfoto speichern'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ausgangsbild auch als Rezeptfoto speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(photos.uploaded, ['/tmp/rezept.jpg']);
  });

  testWidgets('two recipes on one photo: choose, then review one by one', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final auth = FakeAuthRepository(const AuthUser(uid: 'u1'));
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: auth,
        importService: fakeImportService(
          aiResults: const [
            RecipeDraft(
              title: 'Vanillekipferl',
              ingredientLines: ['280 g Mehl'],
            ),
            RecipeDraft(title: 'Linzer Augen', ingredientLines: ['200 g Mehl']),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus Foto oder Screenshot'));
    await tester.pumpAndSettle();

    expect(find.text('2 Rezepte erkannt'), findsOneWidget);
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();

    expect(find.text('Rezept 1 von 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Rezept 2 von 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    final recipes = await db.collection('households/$hid/recipes').get();
    expect(
      recipes.docs.map((d) => d.data()['title']),
      containsAll(['Vanillekipferl', 'Linzer Augen']),
    );
  });
}
