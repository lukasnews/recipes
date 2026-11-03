import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/matching/ingredient_matcher.dart';
import 'package:recipes/features/ingredients/domain/ingredient.dart';

void main() {
  final list =
      (jsonDecode(File('assets/seed/ingredients_de.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((m) => Ingredient.fromMap(m['id'] as String, m))
          .toList();
  final matcher = IngredientMatcher(list.map((i) => i.candidate));

  test('seed has about 300 unique ingredients', () {
    expect(list.length, greaterThanOrEqualTo(300));
    expect(list.map((i) => i.id).toSet().length, list.length);
  });

  test('seed has no obvious duplicates', () {
    final dups = IngredientMatcher.findDuplicates(
      list.map((i) => i.candidate).toList(),
    );
    expect(dups, isEmpty, reason: dups.take(10).toString());
  });

  test('Austrian and German terms resolve to the same ingredient', () {
    for (final (a, b) in [
      ('Topfen', 'Quark'),
      ('Schlagobers', 'Sahne'),
      ('Paradeiser', 'Tomaten'),
      ('Erdäpfel', 'Kartoffeln'),
      ('Karfiol', 'Blumenkohl'),
      ('Marillen', 'Aprikosen'),
      ('Faschiertes', 'Hackfleisch'),
      ('Staubzucker', 'Puderzucker'),
      ('Germ', 'Hefe'),
      ('Kren', 'Meerrettich'),
    ]) {
      final ra = matcher.match(a);
      final rb = matcher.match(b);
      expect(ra.id, isNotNull, reason: a);
      expect(ra.id, rb.id, reason: '$a / $b');
    }
  });

  test('typical recipe words find the right entry', () {
    for (final (input, id) in [
      ('Mehl', 'mehl-glatt'),
      ('glattes Mehl', 'mehl-glatt'),
      ('Zucker', 'kristallzucker'),
      ('Eier', 'ei'),
      ('Zwiebeln', 'zwiebel'),
      ('Butter', 'butter'),
      ('weiche Butter', 'butter'),
      ('Schlagsahne', 'schlagobers'),
      ('Salz', 'salz'),
      ('Knoblauchzehen', 'knoblauch'),
      ('Paprika rot', 'paprika-rot'),
      ('Milch', 'milch'),
    ]) {
      expect(matcher.match(input).id, id, reason: input);
    }
  });

  test('always available basics are flagged', () {
    final always = list.where((i) => i.alwaysAvailable).map((i) => i.id);
    expect(always, containsAll(['salz', 'pfeffer', 'wasser', 'oel']));
  });

  test('common allergens are tagged', () {
    final byId = {for (final i in list) i.id: i};
    expect(byId['mehl-glatt']!.allergens.map((a) => a.name), ['gluten']);
    expect(byId['topfen']!.allergens.map((a) => a.name), ['milk']);
    expect(byId['ei']!.allergens.map((a) => a.name), ['eggs']);
    expect(byId['kokosmilch']!.allergens, isEmpty);
  });
}
