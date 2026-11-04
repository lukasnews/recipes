import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/recipes/data/photo_upload_queue.dart';

import '../../helpers/fakes.dart';

void main() {
  late MemoryPendingUploadStore store;
  late List<String> uploaded;
  late List<String> cached;
  Object? failWith;

  NotifierProvider<PhotoUploadQueue, List<PendingUpload>> queueProvider() =>
      NotifierProvider<PhotoUploadQueue, List<PendingUpload>>(
        () => PhotoUploadQueue(
          store: (_) => store,
          uploader: (_) => (hid, rid, file) async {
            if (failWith != null) throw failWith!;
            uploaded.add('$hid/$rid/$file');
            return 'households/$hid/recipes/$rid/1.jpg';
          },
          onUploaded: (_, path, file) async => cached.add(path),
        ),
      );

  setUp(() {
    store = MemoryPendingUploadStore();
    uploaded = [];
    cached = [];
    failWith = null;
  });

  test('uploads and empties the queue', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final q = queueProvider();
    c.read(q);
    await c.read(q.notifier).enqueue('h', 'r', '/tmp/a.jpg');
    await c.read(q.notifier).process();
    expect(uploaded, ['h/r//tmp/a.jpg']);
    expect(cached, ['households/h/recipes/r/1.jpg']);
    expect(c.read(q), isEmpty);
    expect(store.items, isEmpty);
  });

  test('offline: keeps the photo, survives a restart, uploads later', () async {
    failWith = Exception('offline');
    final c1 = ProviderContainer();
    final q = queueProvider();
    c1.read(q);
    await c1.read(q.notifier).enqueue('h', 'r', '/tmp/a.jpg');
    expect(c1.read(q), hasLength(1));
    expect(store.items, hasLength(1));
    c1.dispose();

    // App restart, network back.
    failWith = null;
    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    c2.read(q);
    await c2.read(q.notifier).process();
    expect(uploaded, ['h/r//tmp/a.jpg']);
    expect(c2.read(q), isEmpty);
  });

  test('recipe gone: photo is dropped instead of retried forever', () async {
    failWith = FirebaseException(plugin: 'storage', code: 'not-found');
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final q = queueProvider();
    c.read(q);
    await c.read(q.notifier).enqueue('h', 'r', '/tmp/a.jpg');
    await c.read(q.notifier).process();
    expect(c.read(q), isEmpty);
  });
}
