import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/import/data/link_importer.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';
import 'package:recipes/features/import/domain/web_recipe.dart';

import '../../helpers/fakes.dart';

void main() {
  const caption =
      'Beste heiße Schokolade 🍫 Zutaten: 500 ml Milch, 100 g Schokolade, '
      '1 EL Kakao. Milch erhitzen, Schokolade schmelzen. #rezept';

  MockClient tiktok({String text = caption}) => MockClient((req) async {
    final u = req.url;
    if (u.host == 'vm.tiktok.com') {
      return http.Response(
        '',
        301,
        headers: {'location': 'https://www.tiktok.com/@koch/video/123?is=1'},
      );
    }
    if (u.path == '/oembed') {
      expect(
        u.queryParameters['url'],
        'https://www.tiktok.com/@koch/video/123?is=1',
      );
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'title': text,
            'author_name': 'Koch Kurt',
            'thumbnail_url': 'https://p16.tiktokcdn.com/cover.jpg',
          }),
        ),
        200,
      );
    }
    if (u.host.endsWith('tiktokcdn.com')) {
      return http.Response.bytes([1, 2, 3], 200);
    }
    return http.Response('', 200);
  });

  test('TikTok: caption via oEmbed to the AI, cover as photo', () async {
    final extractor = FakeExtractor([
      const RecipeDraft(
        title: 'Heiße Schokolade',
        ingredientLines: ['500 ml Milch'],
        steps: ['Milch erhitzen.'],
      ),
    ]);
    final drafts = await LinkImporter(
      extractor: extractor,
      client: tiktok(),
      saveImage: (_) async => '/tmp/cover.jpg',
    ).import(Uri.parse('https://vm.tiktok.com/ZMabc/'));
    expect(extractor.lastText, contains('500 ml Milch'));
    expect(extractor.lastText, contains('Koch Kurt'));
    expect(drafts.single.imagePaths, ['/tmp/cover.jpg']);
    expect(
      drafts.single.sourceUrl,
      'https://www.tiktok.com/@koch/video/123?is=1',
    );
    expect(drafts.single.notes, contains('TikTok: Koch Kurt'));
  });

  test('TikTok without recipe in the caption', () async {
    expect(
      LinkImporter(
        extractor: FakeExtractor(const []),
        client: tiktok(text: 'So lecker 😍 #foodtok'),
      ).import(Uri.parse('https://vm.tiktok.com/ZMabc/')),
      throwsA(isA<NoRecipeInCaptionException>()),
    );
    expect(
      LinkImporter(
        extractor: FakeExtractor(const [RecipeDraft(title: 'x')]),
        client: tiktok(),
      ).import(Uri.parse('https://vm.tiktok.com/ZMabc/')),
      throwsA(isA<NoRecipeInCaptionException>()),
    );
  });

  test('shared text: recipe itself vs. link with a few words', () {
    expect(isRecipeText('Schau mal: https://vm.tiktok.com/ZMabc/'), isFalse);
    expect(
      isRecipeText(
        'Zutaten:\n500 ml Milch\n100 g Schokolade\n1 EL Kakao\n\n'
        'Zubereitung:\n1. Milch erhitzen.\n2. Schokolade darin schmelzen.\n'
        '3. Kakao einrühren und servieren.',
      ),
      isTrue,
    );
  });

  testWidgets('"+" → "Text einfügen" prefills from the clipboard', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'Zutaten:\n500 ml Milch\nZubereitung:\nMilch erhitzen.'}
          : null,
    );
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    final extractor = FakeExtractor([
      const RecipeDraft(
        title: 'Heiße Milch',
        ingredientLines: ['500 ml Milch'],
        steps: ['Milch erhitzen.'],
      ),
    ]);
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        extractor: extractor,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text einfügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezept lesen'));
    await tester.pumpAndSettle();

    expect(extractor.lastText, contains('500 ml Milch'));
    expect(find.text('Heiße Milch'), findsWidgets);
  });
}
