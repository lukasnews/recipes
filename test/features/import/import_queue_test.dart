import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/app/providers.dart';
import 'package:recipes/features/auth/data/auth_repository.dart';
import 'package:recipes/features/import/data/import_queue.dart';
import 'package:recipes/features/import/data/recipe_import_service.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';

import '../../helpers/fakes.dart';

void main() {
  test('network errors are told apart from other AI errors', () {
    expect(
      RecipeImportService.isNetworkError(
        const SocketException('Failed host lookup'),
      ),
      isTrue,
    );
    expect(RecipeImportService.isNetworkError(Exception('quota')), isFalse);
  });

  test('pending import survives a restart and is read once online', () async {
    final store = MemoryImportQueueStore();
    var online = false;
    NotifierProvider<ImportQueue, List<PendingImport>> provider() =>
        NotifierProvider<ImportQueue, List<PendingImport>>(
          () => ImportQueue(
            store: (_) => store,
            reader: (_, paths) async {
              if (!online) throw const SocketException('offline');
              return [RecipeDraft(title: 'Sachertorte', imagePaths: paths)];
            },
          ),
        );
    final q = provider();
    final c1 = ProviderContainer();
    c1.read(q);
    await c1.read(q.notifier).enqueue(['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(c1.read(q).single.isReady, isFalse);
    c1.dispose();

    online = true;
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(q);
    await c2.read(q.notifier).process();
    final item = c2.read(q).single;
    expect(item.drafts!.single.title, 'Sachertorte');
    expect(store.items.single.isReady, isTrue);

    await c2.read(q.notifier).done(item.id);
    expect(c2.read(q), isEmpty);
  });

  testWidgets('offline photo: read later, review once the AI read it', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await seedHousehold(db);
    final extractor = FakeExtractor(const [], fail: true)
      ..failWith = () => const SocketException('Failed host lookup');
    await tester.pumpWidget(
      testApp(
        db: db,
        auth: FakeAuthRepository(const AuthUser(uid: 'u1')),
        importService: fakeImportService(
          extractor: extractor,
          ocrText: 'Sachertorte\n140 g Butter',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neues Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezept fotografieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fertig – Rezept lesen'));
    await tester.pumpAndSettle();

    // OCR result without AI: offer to read it later instead.
    await tester.tap(find.text('Später mit KI lesen'));
    await tester.pumpAndSettle();
    expect(find.text('1 Foto-Import wartet auf Internet'), findsOneWidget);

    // Back online: the queue reads the photo.
    extractor
      ..fail = false
      ..results = const [RecipeDraft(title: 'Sachertorte')];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    await tester.runAsync(
      () => container.read(importQueueProvider.notifier).process(),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 Rezept aus Fotos gelesen'), findsOneWidget);

    await tester.tap(find.text('Jetzt prüfen'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Sachertorte'), findsOneWidget);
  });
}
