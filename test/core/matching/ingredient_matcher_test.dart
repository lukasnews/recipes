import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/core/matching/normalize.dart';

void main() {
  final matcher = IngredientMatcher(const [
    MatchCandidate(
      id: 'schlagobers',
      name: 'Schlagobers',
      synonyms: ['Sahne', 'Schlagsahne', 'Obers'],
    ),
    MatchCandidate(
      id: 'mehl-glatt',
      name: 'Mehl glatt',
      synonyms: ['Weizenmehl'],
    ),
    MatchCandidate(id: 'topfen', name: 'Topfen', synonyms: ['Quark']),
    MatchCandidate(id: 'erdapfel', name: 'Erdäpfel', synonyms: ['Kartoffeln']),
    MatchCandidate(id: 'ei', name: 'Ei', synonyms: ['Eier']),
    MatchCandidate(id: 'zwiebel', name: 'Zwiebel'),
    MatchCandidate(id: 'tomate', name: 'Paradeiser', synonyms: ['Tomaten']),
    MatchCandidate(id: 'butter', name: 'Butter'),
  ]);

  test('similar: offers existing ingredients before creating duplicates', () {
    expect(matcher.similar('Schlagsahne').first, 'schlagobers');
    expect(matcher.similar('Sahne flüssig'), contains('schlagobers'));
    expect(matcher.similar('Topfn'), contains('topfen'));
    expect(matcher.similar('Zucchini'), isEmpty);
  });

  test('exact name, case insensitive', () {
    final r = matcher.match('schlagobers');
    expect(r.kind, MatchKind.exact);
    expect(r.id, 'schlagobers');
  });

  test('synonym: Sahne is Schlagobers', () {
    expect(matcher.match('Sahne').id, 'schlagobers');
    expect(matcher.match('Sahne').kind, MatchKind.synonym);
    expect(matcher.match('Quark').id, 'topfen');
    expect(matcher.match('Kartoffeln').id, 'erdapfel');
  });

  test('normalized: plural, umlaut, word order, descriptors', () {
    for (final (input, id) in [
      ('glattes Mehl', 'mehl-glatt'),
      ('Mehl, glatt', 'mehl-glatt'),
      ('Erdapfel', 'erdapfel'),
      ('Erdaepfel', 'erdapfel'),
      ('Kartoffel', 'erdapfel'),
      ('Tomate', 'tomate'),
      ('Zwiebeln', 'zwiebel'),
      ('weiche Butter', 'butter'),
      ('kalte Schlagsahne', 'schlagobers'),
      ('frische Eier', 'ei'),
    ]) {
      final r = matcher.match(input);
      expect(r.id, id, reason: input);
      expect(r.isUncertain, isFalse, reason: input);
    }
  });

  test('fuzzy suggestion is marked uncertain', () {
    final r = matcher.match('Schlagober');
    expect(r.id, 'schlagobers');
    final typo = matcher.match('Zwiebl');
    expect(typo.id, 'zwiebel');
    expect(typo.isUncertain, isTrue);
    final red = matcher.match('rote Zwiebel');
    expect(red.id, 'zwiebel');
    expect(red.isUncertain, isTrue);
  });

  test('unknown name gives no match', () {
    expect(matcher.match('Safran').isMatch, isFalse);
    expect(matcher.match('').isMatch, isFalse);
  });

  test('findDuplicates spots the same product under two entries', () {
    final dups = IngredientMatcher.findDuplicates(const [
      MatchCandidate(id: 'a', name: 'Schlagobers'),
      MatchCandidate(id: 'b', name: 'Sahne', synonyms: ['Schlagobers']),
      MatchCandidate(id: 'c', name: 'Butter'),
      MatchCandidate(id: 'd', name: 'Zwiebeln'),
      MatchCandidate(id: 'e', name: 'Zwiebel'),
    ]);
    final pairs = dups.map((d) => {d.$1, d.$2}).toList();
    expect(
      pairs,
      containsAll([
        {'a', 'b'},
        {'d', 'e'},
      ]),
    );
    expect(pairs.any((p) => p.contains('c')), isFalse);
  });

  test('normalizeKey', () {
    expect(normalizeKey('Glattes Mehl'), normalizeKey('Mehl glatt'));
    expect(normalizeKey('Äpfel'), normalizeKey('Apfel'));
    expect(normalizeKey('Nüsse'), normalizeKey('Nuss'));
  });
}
