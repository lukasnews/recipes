import 'package:cloud_firestore/cloud_firestore.dart';

class InvalidBackupException implements Exception {}

/// Summary shown before restoring.
class BackupInfo {
  const BackupInfo({
    required this.householdName,
    required this.exportedAt,
    required this.counts,
  });

  final String householdName;
  final DateTime? exportedAt;

  /// Collection name -> number of documents.
  final Map<String, int> counts;

  int get recipes => counts['recipes'] ?? 0;
}

/// JSON backup of one household. Members are left out: each person
/// writes only their own entry.
class BackupService {
  BackupService(this._db, this._hid);

  final FirebaseFirestore _db;
  final String _hid;

  static const format = 'baco-backup';
  static const version = 1;
  static const collections = [
    'ingredients',
    'recipes',
    'pantry',
    'shopping',
    'mealplan',
    'frozenMeals',
    'cookLog',
    'barcodes',
    'menus',
  ];

  DocumentReference<Map<String, dynamic>> get _household =>
      _db.collection('households').doc(_hid);

  /// Reads everything (from the cache when offline).
  Future<Map<String, dynamic>> export({DateTime? now}) async {
    final household = await _household.get();
    final data = <String, dynamic>{};
    for (final c in collections) {
      final snap = await _household.collection(c).get();
      data[c] = {for (final d in snap.docs) d.id: _encode(d.data())};
    }
    return {
      'format': format,
      'version': version,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'householdName': household.data()?['name'] ?? '',
      'collections': data,
    };
  }

  static BackupInfo inspect(Map<String, dynamic> json) {
    if (json['format'] != format || json['collections'] is! Map) {
      throw InvalidBackupException();
    }
    final cols = (json['collections'] as Map).cast<String, dynamic>();
    return BackupInfo(
      householdName: json['householdName'] as String? ?? '',
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? ''),
      counts: {
        for (final e in cols.entries)
          if (e.value is Map) e.key: (e.value as Map).length,
      },
    );
  }

  /// Writes the backup into this household. Documents with the same id are
  /// overwritten, others stay. Photos of another household are dropped
  /// (their storage paths aren't readable here). Doesn't wait for the
  /// server, so it works offline.
  int restore(Map<String, dynamic> json) {
    inspect(json);
    final cols = (json['collections'] as Map).cast<String, dynamic>();
    var batch = _db.batch();
    var inBatch = 0;
    var total = 0;
    for (final c in collections) {
      final docs = cols[c];
      if (docs is! Map) continue;
      for (final e in docs.entries) {
        if (e.value is! Map) continue;
        var data = _decode(e.value) as Map<String, dynamic>;
        if (c == 'recipes') data = _ownPhotosOnly(data);
        batch.set(_household.collection(c).doc(e.key as String), data);
        total++;
        // Firestore allows 500 writes per batch.
        if (++inBatch == 450) {
          _commit(batch);
          batch = _db.batch();
          inBatch = 0;
        }
      }
    }
    if (inBatch > 0) _commit(batch);
    return total;
  }

  void _commit(WriteBatch batch) {
    // Fire and forget: offline writes resolve only once synced.
    batch.commit().ignore();
  }

  Map<String, dynamic> _ownPhotosOnly(Map<String, dynamic> recipe) {
    final paths = recipe['photoPaths'];
    if (paths is! List) return recipe;
    final prefix = 'households/$_hid/';
    return {
      ...recipe,
      'photoPaths': [
        for (final p in paths)
          if (p is String && p.startsWith(prefix)) p,
      ],
    };
  }

  static const _tsKey = r'$ts';

  static Object? _encode(Object? v) => switch (v) {
    Timestamp() => {_tsKey: v.toDate().toUtc().toIso8601String()},
    DateTime() => {_tsKey: v.toUtc().toIso8601String()},
    Map() => {for (final e in v.entries) '${e.key}': _encode(e.value)},
    List() => [for (final x in v) _encode(x)],
    _ => v,
  };

  static Object? _decode(Object? v) => switch (v) {
    {_tsKey: final String iso} when v.length == 1 => switch (DateTime.tryParse(
      iso,
    )) {
      final d? => Timestamp.fromDate(d),
      null => null,
    },
    Map() => <String, dynamic>{
      for (final e in v.entries) '${e.key}': _decode(e.value),
    },
    List() => [for (final x in v) _decode(x)],
    _ => v,
  };
}
