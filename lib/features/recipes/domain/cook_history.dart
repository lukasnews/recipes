import '../../../core/firebase/map_utils.dart';

class CookLogEntry {
  const CookLogEntry({
    required this.id,
    required this.recipeId,
    required this.cookedAt,
    this.undone = false,
  });

  factory CookLogEntry.fromMap(String id, Map<String, dynamic> m) =>
      CookLogEntry(
        id: id,
        recipeId: m.str('recipeId'),
        // Pending server timestamps are null locally: treat as now.
        cookedAt: m.date('cookedAt') ?? DateTime.now(),
        undone: m.flag('undone'),
      );

  final String id;
  final String recipeId;
  final DateTime cookedAt;
  final bool undone;
}

class CookStats {
  const CookStats(this.count, this.lastCooked);

  final int count;
  final DateTime lastCooked;
}

/// How often and when each recipe was last cooked (undone entries ignored).
Map<String, CookStats> cookStats(Iterable<CookLogEntry> log) {
  final result = <String, CookStats>{};
  for (final e in log) {
    if (e.undone) continue;
    final prev = result[e.recipeId];
    result[e.recipeId] = CookStats(
      (prev?.count ?? 0) + 1,
      prev == null || e.cookedAt.isAfter(prev.lastCooked)
          ? e.cookedAt
          : prev.lastCooked,
    );
  }
  return result;
}

/// Recipe ids ordered for "lange nicht gekocht": cooked before, oldest last
/// cook first; never-cooked recipes come after.
List<String> longNotCooked(
  Iterable<String> recipeIds,
  Map<String, CookStats> stats,
) {
  final cooked = recipeIds.where(stats.containsKey).toList()
    ..sort((a, b) => stats[a]!.lastCooked.compareTo(stats[b]!.lastCooked));
  return [...cooked, ...recipeIds.where((id) => !stats.containsKey(id))];
}

/// Whole days between two dates, ignoring the time of day.
int daysBetween(DateTime from, DateTime to) => DateTime(
  to.year,
  to.month,
  to.day,
).difference(DateTime(from.year, from.month, from.day)).inDays;
