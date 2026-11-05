import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/recipe_draft.dart';

/// Recipe photos read later by the AI (taken without connection). Once
/// read, [drafts] wait for the review screen.
class PendingImport {
  const PendingImport({
    required this.id,
    required this.imagePaths,
    this.drafts,
  });

  factory PendingImport.fromJson(Map<String, dynamic> m) => PendingImport(
    id: m['id'] as String,
    imagePaths: [...(m['imagePaths'] as List).cast<String>()],
    drafts: (m['drafts'] as List?)
        ?.cast<Map<String, dynamic>>()
        .map(RecipeDraftJson.fromJson)
        .toList(),
  );

  final String id;
  final List<String> imagePaths;
  final List<RecipeDraft>? drafts;

  bool get isReady => drafts != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePaths': imagePaths,
    if (drafts != null) 'drafts': [for (final d in drafts!) d.toJson()],
  };
}

/// Keeps the queue and its photos on the phone.
abstract class ImportQueueStore {
  Future<List<PendingImport>> load();
  Future<void> save(List<PendingImport> items);

  /// Copies [file] into storage the app owns; returns the copy's path.
  Future<String> keep(String file);
}

class FileImportQueueStore implements ImportQueueStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/pending_imports').create(recursive: true);
  }

  Future<File> _index() async => File('${(await _dir()).path}/queue.json');

  @override
  Future<List<PendingImport>> load() async {
    final f = await _index();
    var items = const <PendingImport>[];
    if (f.existsSync()) {
      try {
        items = [
          for (final m in (jsonDecode(
            await f.readAsString(),
          ) as List).cast<Map<String, dynamic>>())
            PendingImport.fromJson(m),
        ];
      } on FormatException {
        items = const [];
      }
    }
    await _removeOrphans(items);
    return items;
  }

  /// Photos of reviewed imports: deleted once nothing refers to them any
  /// more (a while later, so a photo saved with the recipe is copied first).
  Future<void> _removeOrphans(List<PendingImport> items) async {
    final used = {for (final i in items) ...i.imagePaths};
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    await for (final e in (await _dir()).list()) {
      if (e is! File || !e.path.endsWith('.jpg') || used.contains(e.path)) {
        continue;
      }
      if ((await e.lastModified()).isBefore(cutoff)) await e.delete();
    }
  }

  @override
  Future<void> save(List<PendingImport> items) async {
    final f = await _index();
    await f.writeAsString(jsonEncode([for (final i in items) i.toJson()]));
  }

  @override
  Future<String> keep(String file) async {
    final dir = await _dir();
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    return (await File(file).copy('${dir.path}/$name')).path;
  }
}

/// Reads queued photos once there is a connection: on start, when the app
/// returns and with growing pauses after failures.
class ImportQueue extends Notifier<List<PendingImport>> {
  ImportQueue({required this.store, required this.reader});

  final ImportQueueStore Function(Ref ref) store;

  /// Throws when offline (retry later); otherwise returns the drafts.
  final Future<List<RecipeDraft>> Function(Ref ref, List<String> paths) reader;

  Timer? _retry;
  Future<void>? _run;
  var _failures = 0;
  late Future<void> _loaded;

  @override
  List<PendingImport> build() {
    ref.onDispose(() => _retry?.cancel());
    _loaded = _load();
    return const [];
  }

  Future<void> _load() async {
    final items = await store(ref).load();
    if (!ref.mounted) return;
    state = [...items, ...state.where((s) => !items.any((i) => i.id == s.id))];
    unawaited(process());
  }

  Future<void> _save() => store(ref).save(state);

  /// Queues photos taken without connection.
  Future<void> enqueue(List<String> imagePaths) async {
    await _loaded;
    final s = store(ref);
    final copies = [for (final p in imagePaths) await s.keep(p)];
    if (!ref.mounted) return;
    state = [
      ...state,
      PendingImport(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        imagePaths: copies,
      ),
    ];
    await _save();
    _failures = 0;
    unawaited(process());
  }

  Future<void> process() => _run ??= _process().whenComplete(() => _run = null);

  Future<void> _process() async {
    await _loaded;
    _retry?.cancel();
    while (ref.mounted) {
      final next = state.where((i) => !i.isReady).firstOrNull;
      if (next == null) return;
      try {
        final drafts = await reader(ref, next.imagePaths);
        if (!ref.mounted) return;
        state = [
          for (final i in state)
            i.id == next.id
                ? PendingImport(
                    id: i.id,
                    imagePaths: i.imagePaths,
                    drafts: drafts,
                  )
                : i,
        ];
        await _save();
        _failures = 0;
      } on Object {
        if (!ref.mounted) return;
        _failures++;
        final wait = Duration(seconds: min(600, 15 << min(_failures, 6)));
        _retry = Timer(wait, () => unawaited(process()));
        return;
      }
    }
  }

  /// The drafts of [id] went through the review screen: drop it. Its
  /// photos are cleaned up on a later start (see the store).
  Future<void> done(String id) async {
    await _loaded;
    if (!state.any((i) => i.id == id)) return;
    state = state.where((i) => i.id != id).toList();
    await _save();
  }
}
