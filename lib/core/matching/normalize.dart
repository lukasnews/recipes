/// Text normalization for ingredient names.
library;

/// Words that describe preparation or state, not the ingredient itself.
const _descriptors = {
  'weich',
  'gehackt',
  'gerieben',
  'frisch',
  'kalt',
  'warm',
  'lauwarm',
  'zimmerwarm',
  'geschmolz',
  'zerlass',
  'fein',
  'grob',
  'klein',
  'gross',
  'mittelgross',
  'reif',
  'gewuerfelt',
  'gewurfelt',
  'geschnitt',
  'geschalt',
  'geschaelt',
  'gestrich',
  'gehauft',
  'gehaeuft',
  'bio',
  'ca',
  'etwa',
  'etwas',
  'evtl',
  'eventuell',
  'optional',
  'nach',
  'belieb',
  'geschmack',
  'zum',
  'fur',
  'fuer',
  'die',
  'der',
  'das',
  'den',
  'dem',
  'ein',
  'eine',
  'einer',
  'einen',
  'und',
  'oder',
  'mit',
  'tk',
  'tiefgekuhlt',
  'tiefgekuhl',
  'abgerieb',
  'unbehandelt',
  'unbehandel',
  'ganz',
  'halbiert',
  'geviertelt',
  'gekocht',
  'roh',
  'zerdruckt',
  'gepresst',
  'gesiebt',
  'flussig',
  'gestr',
  'geh',
  'kl',
  'gr',
  'mittl',
};

/// Folds umlauts to their base vowel so plural umlauts match
/// (`Äpfel` -> `apfel`), lowercases and removes punctuation.
String foldText(String input) {
  final s = input
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp('ae(?=[^aeiou])'), 'a')
      .replaceAll(RegExp('oe(?=[^aeiou])'), 'o')
      .replaceAll(RegExp('ue(?=[^aeiou])'), 'u');
  return s
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Very small German stemmer: strips common plural / inflection endings.
String stem(String word) {
  var w = word;
  for (var i = 0; i < 2; i++) {
    final before = w;
    // No 'er': it would turn Kräuter into Kraut.
    for (final ending in const ['en', 'es', 'em', 'n', 'e', 's']) {
      if (w.endsWith(ending) && w.length - ending.length >= 3) {
        w = w.substring(0, w.length - ending.length);
        break;
      }
    }
    if (w == before) break;
  }
  return w;
}

/// Order independent key: folded, stemmed tokens without descriptors.
/// `"Mehl, glatt"` and `"glattes Mehl"` give the same key.
String normalizeKey(String input, {bool stripDescriptors = true}) {
  final tokens = <String>[];
  for (final t in foldText(input).split(' ')) {
    if (t.isEmpty) continue;
    final s = stem(t);
    if (stripDescriptors &&
        (_descriptors.contains(t) ||
            _descriptors.contains(s) ||
            (t.endsWith('er') &&
                _descriptors.contains(stem(t.substring(0, t.length - 2)))))) {
      continue;
    }
    tokens.add(s);
  }
  tokens.sort();
  return tokens.join(' ');
}

/// Levenshtein based similarity between 0 and 1.
double similarity(String a, String b) {
  if (a == b) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (i) => i);
  var cur = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    cur[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  final dist = prev[n];
  return 1 - dist / (m > n ? m : n);
}
