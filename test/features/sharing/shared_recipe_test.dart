import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/recipes/data/recipe_repository.dart';
import 'package:recipes/features/recipes/domain/recipe.dart';
import 'package:recipes/features/sharing/data/shared_recipe_repository.dart';
import 'package:recipes/features/sharing/domain/shared_recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  group('codes', () {
    test('8 unambiguous characters', () {
      final code = newShareCode(Random(1));
      expect(code, hasLength(8));
      expect(code, isNot(matches(RegExp('[01OIL]'))));
      expect(formatShareCode('K7MQX4PA'), 'K7MQ-X4PA');
    });
    test('parse what people type or paste', () {
      expect(parseShareCode('k7mq-x4pa'), 'K7MQX4PA');
      expect(parseShareCode(' K7MQ X4PA '), 'K7MQX4PA');
      expect(
        parseShareCode('https://lukasnews.github.io/recipes/r/?c=K7MQX4PA'),
        'K7MQX4PA',
      );
      expect(parseShareCode('K7MQ'), isNull);
      expect(parseShareCode('K7MQX4P0'), isNull);
    });
    test('recognise links to sent recipes', () {
      expect(
        sharedRecipeCode(
          Uri.parse('https://lukasnews.github.io/recipes/r/?c=K7MQX4PA'),
        ),
        'K7MQX4PA',
      );
      expect(
        sharedRecipeCode(Uri.parse('https://example.com/?c=K7MQX4PA')),
        isNull,
      );
    });
  });

  test('copy of a recipe survives the round trip; expiry', () async {
    const recipe = Recipe(
      id: 'k',
      title: 'Kaiserschmarrn',
      servings: 2,
      ingredients: [RecipeIngredient(rawText: '125 g Mehl glatt')],
      steps: [RecipeStep('Alles verrühren.')],
    );
    final now = DateTime(2026, 11, 5);
    final shared = SharedRecipe.fromRecipe(
      recipe,
      code: 'K7MQX4PA',
      uid: 'u1',
      senderName: 'Lukas',
      message: ' Probieren! ',
      validity: ShareValidity.week,
      now: now,
    );
    final db = FakeFirebaseFirestore();
    final repo = SharedRecipeRepository(db);
    await repo.send(shared);
    final back = (await repo.fetch('K7MQX4PA'))!;
    expect(back.title, 'Kaiserschmarrn');
    expect(back.message, 'Probieren!');
    expect(back.ingredientLines, ['125 g Mehl glatt']);
    expect(back.steps, ['Alles verrühren.']);
    expect(back.expiresAt, DateTime(2026, 11, 12));
    expect(back.isExpired(DateTime(2026, 11, 13)), isTrue);
    expect(await repo.fetch('AAAABBBB'), isNull);
    final draft = back.toDraft(notes: 'Von Lukas');
    expect(draft.ingredientLines, ['125 g Mehl glatt']);
    expect(draft.notes, 'Von Lukas');
  });

  test('expired sends are cleaned up with their photos', () async {
    final db = FakeFirebaseFirestore();
    final repo = SharedRecipeRepository(db);
    final now = DateTime(2026, 11, 5);
    await repo.send(
      SharedRecipe(
        code: 'OLD23456',
        title: 'Alt',
        createdBy: 'u1',
        photoPath: 'shared/u1/OLD23456.jpg',
        createdAt: now,
        expiresAt: now.subtract(const Duration(days: 1)),
      ),
    );
    await repo.send(
      SharedRecipe(
        code: 'NEW23456',
        title: 'Neu',
        createdBy: 'u1',
        createdAt: now,
      ),
    );
    expect(await repo.deleteExpired('u1', now), ['shared/u1/OLD23456.jpg']);
    expect(await repo.fetch('OLD23456'), isNull);
    expect(await repo.fetch('NEW23456'), isNotNull);
  });

  testWidgets('send from the recipe, receive by link, take it over', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    final hid = await seedHousehold(db);
    await RecipeRepository(db, hid).save(
      const Recipe(
        id: 'k',
        title: 'Kaiserschmarrn',
        servings: 2,
        ingredients: [RecipeIngredient(rawText: '125 g Mehl glatt')],
        steps: [RecipeStep('Alles verrühren.')],
      ),
      isNew: true,
    );
    final sharer = FakeSharer();
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        sharer: sharer,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaiserschmarrn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Weitere Aktionen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('An anderen Haushalt senden'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unbedingt probieren!');
    await tester.tap(find.text('Link teilen'));
    await tester.pumpAndSettle();

    final sent = await db.collection('sharedRecipes').get();
    expect(sent.docs, hasLength(1));
    final code = sent.docs.single.id;
    expect(sent.docs.single['senderName'], 'Lukas');
    expect(sent.docs.single['expiresAt'], isNull);
    expect(sharer.texts.single, contains('Lukas hat dir ein Rezept geschickt'));
    expect(sharer.texts.single, contains('„Unbedingt probieren!“'));
    expect(sharer.texts.single, contains('/recipes/r/?c=$code'));

    // The receiver opens the link (baco://recipe?c=…).
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('baco://recipe?c=$code');
    await tester.pumpAndSettle();
    expect(find.text('Von Lukas'), findsOneWidget);
    expect(find.text('„Unbedingt probieren!“'), findsOneWidget);
    await tester.tap(find.text('In meine Rezepte übernehmen'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiserschmarrn'), findsWidgets);
    expect(
      find.textContaining('Von Lukas: „Unbedingt probieren!“'),
      findsOneWidget,
    );
  });

  testWidgets('unknown code shows a hint', (tester) async {
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/shared/AAAABBBB');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('AAAA-BBBB gibt es kein Rezept'),
      findsOneWidget,
    );
  });
}
