import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  testWidgets('favourite and collection filter the recipe list', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    final repo = RecipeRepository(db, hid);
    await repo.save(const Recipe(id: 'a', title: 'Gulasch'), isNew: true);
    await repo.save(const Recipe(id: 'b', title: 'Strudel'), isNew: true);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gulasch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zu Favoriten'));
    await tester.pumpAndSettle();
    final user = await db.doc('users/u1').get();
    expect(user.data()!['favoriteRecipeIds'], ['a']);

    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sammlungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neue Sammlung'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sonntag');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final doc = await db.doc('households/$hid/recipes/a').get();
    expect(doc.data()!['collections'], ['Sonntag']);
    expect(find.text('Sonntag'), findsOneWidget);

    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Favoriten'));
    await tester.pumpAndSettle();
    expect(find.text('Gulasch'), findsOneWidget);
    expect(find.text('Strudel'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Favoriten'));
    await tester.tap(find.widgetWithText(FilterChip, 'Sonntag'));
    await tester.pumpAndSettle();
    expect(find.text('Gulasch'), findsOneWidget);
    expect(find.text('Strudel'), findsNothing);
  });
}
