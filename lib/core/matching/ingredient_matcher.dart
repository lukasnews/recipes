import 'normalize.dart';

/// Minimal view of an ingredient the matcher needs.
class MatchCandidate {
  const MatchCandidate({
    required this.id,
    required this.name,
    this.synonyms = const [],
  });

  final String id;
  final String name;
  final List<String> synonyms;
}

enum MatchKind { exact, synonym, normalized, fuzzy, none }

class MatchResult {
  const MatchResult(this.kind, {this.id, this.score = 0});

  static const none = MatchResult(MatchKind.none);

  final MatchKind kind;
  final String? id;
  final double score;

  /// A fuzzy match is only a suggestion and must be confirmed by the user.
  bool get isUncertain => kind == MatchKind.fuzzy;
  bool get isMatch => id != null;

  @override
  String toString() => 'MatchResult($kind, $id, ${score.toStringAsFixed(2)})';
}

/// Maps ingredient names from recipes to ingredient ids.
///
/// Order: 1. exact name, 2. synonym, 3. normalized, 4. fuzzy (uncertain),
/// 5. no match (caller creates a new ingredient).
class IngredientMatcher {
  IngredientMatcher(Iterable<MatchCandidate> candidates) {
    for (final c in candidates) {
      _exact.putIfAbsent(c.name.trim().toLowerCase(), () => c.id);
      for (final s in c.synonyms) {
        _synonym.putIfAbsent(s.trim().toLowerCase(), () => c.id);
      }
      for (final label in [c.name, ...c.synonyms]) {
        final key = normalizeKey(label);
        if (key.isEmpty) continue;
        _normalized.putIfAbsent(key, () => c.id);
        _keys.add((key, c.id));
      }
    }
  }

  static const fuzzyThreshold = 0.78;

  final _exact = <String, String>{};
  final _synonym = <String, String>{};
  final _normalized = <String, String>{};
  final _keys = <(String, String)>[];

  MatchResult match(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return MatchResult.none;
    final exact = _exact[lower];
    if (exact != null) return MatchResult(MatchKind.exact, id: exact, score: 1);
    final syn = _synonym[lower];
    if (syn != null) return MatchResult(MatchKind.synonym, id: syn, score: 1);
    final key = normalizeKey(name);
    if (key.isEmpty) return MatchResult.none;
    final norm = _normalized[key];
    if (norm != null) {
      return MatchResult(MatchKind.normalized, id: norm, score: 1);
    }
    return _bestFuzzy(key);
  }

  MatchResult _bestFuzzy(String key) {
    String? bestId;
    var best = 0.0;
    final tokens = key.split(' ').toSet();
    for (final (k, id) in _keys) {
      var score = similarity(key, k);
      // "rote Zwiebel" vs "Zwiebel": all tokens of one side in the other.
      final other = k.split(' ').toSet();
      if (score < 0.8 &&
          (other.containsAll(tokens) || tokens.containsAll(other))) {
        score = 0.8;
      }
      if (score > best) {
        best = score;
        bestId = id;
      }
    }
    if (bestId != null && best >= fuzzyThreshold) {
      return MatchResult(MatchKind.fuzzy, id: bestId, score: best);
    }
    return MatchResult.none;
  }

  /// Pairs of candidates that are probably the same product.
  static List<(String, String, double)> findDuplicates(
    List<MatchCandidate> candidates, {
    double threshold = 0.86,
  }) {
    final keys = [
      for (final c in candidates)
        {
          for (final l in [c.name, ...c.synonyms])
            normalizeKey(l, stripDescriptors: false),
        }..remove(''),
    ];
    final result = <(String, String, double)>[];
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        var best = 0.0;
        for (final a in keys[i]) {
          for (final b in keys[j]) {
            final longer = a.length > b.length ? a.length : b.length;
            if ((a.length - b.length).abs() > longer * (1 - threshold)) {
              continue;
            }
            final s = similarity(a, b);
            if (s > best) best = s;
          }
        }
        if (best >= threshold) {
          result.add((candidates[i].id, candidates[j].id, best));
        }
      }
    }
    result.sort((a, b) => b.$3.compareTo(a.$3));
    return result;
  }
}
