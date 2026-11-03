import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/app/app.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: RecipesApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on recipes tab with category chips', (tester) async {
    await pumpApp(tester);

    expect(find.text('Noch keine Rezepte'), findsOneWidget);
    for (final label in ['Alle', 'Kochen', 'Kuchen', 'Kekse']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
  });

  testWidgets('bottom navigation switches between all four tabs', (
    tester,
  ) async {
    await pumpApp(tester);

    final nav = find.byType(NavigationBar);
    const tabs = {
      'Wochenplan': 'Noch nichts geplant',
      'Einkauf': 'Die Einkaufsliste ist leer',
      'Vorrat': 'Der Vorrat ist leer',
      'Rezepte': 'Noch keine Rezepte',
    };
    for (final MapEntry(key: tab, value: emptyText) in tabs.entries) {
      await tester.tap(find.descendant(of: nav, matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(find.text(emptyText), findsOneWidget, reason: tab);
    }
  });

  testWidgets('profile button opens settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Profil und Einstellungen'));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
