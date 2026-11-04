import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// A recipe photo waiting for its upload. [file] is a copy in the app's
/// own storage, so it survives restarts.
class PendingUpload {
  const PendingUpload({
    required this.id,
    required this.householdId,
    required this.recipeId,
    required this.file,
  });

  factory PendingUpload.fromMap(Map<String, dynamic> m) => PendingUpload(
    id: m['id'] as String,
    householdId: m['householdId'] as String,
    recipeId: m['recipeId'] as String,
    file: m['file'] as String,
  );

  final String id;
  final String householdId;
  final String recipeId;
  final String file;

  Map<String, dynamic> toMap() => {
    'id': id,
    'householdId': householdId,
    'recipeId': recipeId,
    'file': file,
  };
}

/// Keeps the queue and its files on the phone.
abstract class PendingUploadStore {
  Future<List<PendingUpload>> load();
  Future<void> save(List<PendingUpload> items);

  /// Copies [file] into storage the app owns; returns the copy's path.
  Future<String> keep(String file);
  Future<void> discard(String file);
}

class FilePendingUploadStore implements PendingUploadStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/pending_uploads').create(recursive: true);
  }

  Future<File> _index() async => File('${(await _dir()).path}/queue.json');

  @override
  Future<List<PendingUpload>> load() async {
    final f = await _index();
    if (!f.existsSync()) return const [];
    try {
      return [
        for (final m in (jsonDecode(
          await f.readAsString(),
        ) as List<dynamic>).cast<Map<String, dynamic>>())
          PendingUpload.fromMap(m),
      ].where((p) => File(p.file).existsSync()).toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<PendingUpload> items) async {
    final f = await _index();
    await f.writeAsString(jsonEncode([for (final i in items) i.toMap()]));
  }

  @override
  Future<String> keep(String file) async {
    final dir = await _dir();
    final name = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    return (await File(file).copy('${dir.path}/$name')).path;
  }

  @override
  Future<void> discard(String file) async {
    final f = File(file);
    if (f.existsSync()) await f.delete();
  }
}

/// Uploads [file] for the recipe and returns the Storage path.
typedef PhotoUploader = Future<String> Function(
  String householdId,
  String recipeId,
  String file,
);

/// Sends queued photos one after another. A failure (usually no network)
/// stops the run and retries later: with growing pauses, on app start and
/// when the app comes back to the foreground.
class PhotoUploadQueue extends Notifier<List<PendingUpload>> {
  PhotoUploadQueue({
    required this.store,
    required this.uploader,
    required this.onUploaded,
  });

  final PendingUploadStore Function(Ref ref) store;
  final PhotoUploader Function(Ref ref) uploader;

  /// Called with (storage path, local file) after a successful upload.
  final Future<void> Function(Ref ref, String path, String file) onUploaded;

  Timer? _retry;
  Future<void>? _run;
  var _failures = 0;
  late Future<void> _loaded;

  @override
  List<PendingUpload> build() {
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

  Future<void> enqueue(String householdId, String recipeId, String file) async {
    await _loaded;
    final s = store(ref);
    final copy = await s.keep(file);
    if (!ref.mounted) return;
    state = [
      ...state,
      PendingUpload(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        householdId: householdId,
        recipeId: recipeId,
        file: copy,
      ),
    ];
    await s.save(state);
    _failures = 0;
    unawaited(process());
  }

  /// Runs the queue now (e.g. app came back to the foreground). Joins a
  /// run that is already going.
  Future<void> process() => _run ??= _process().whenComplete(() => _run = null);

  Future<void> _process() async {
    await _loaded;
    _retry?.cancel();
    while (ref.mounted && state.isNotEmpty) {
      final item = state.first;
      try {
        final path = await uploader(ref)(
          item.householdId,
          item.recipeId,
          item.file,
        );
        if (!ref.mounted) return;
        await onUploaded(ref, path, item.file);
        _failures = 0;
      } on Object catch (e) {
        if (!ref.mounted) return;
        if (!_isPermanent(e)) {
          _failures++;
          final wait = Duration(seconds: min(600, 15 << min(_failures, 6)));
          _retry = Timer(wait, () => unawaited(process()));
          return;
        }
        // Recipe deleted or no longer a member: drop the photo.
      }
      if (!ref.mounted) return;
      state = state.where((p) => p.id != item.id).toList();
      final s = store(ref);
      await s.save(state);
      await s.discard(item.file);
    }
  }

  static bool _isPermanent(Object e) =>
      e is FirebaseException &&
      const {'not-found', 'unauthorized', 'permission-denied'}.contains(e.code);
}
