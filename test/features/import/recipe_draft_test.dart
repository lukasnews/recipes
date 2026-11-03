import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';

void main() {
  group('draftFromAiJson', () {
    test('valid answer becomes ingredient lines and steps', () {
      final d = draftFromAiJson('''
```json
{"title": "Topfenknödel", "servings": 4, "prepMinutes": 20,
 "ingredients": [
   {"amount": 250, "unit": "g", "name": "Topfen"},
   {"amount": 0.5, "unit": "Teelöffel", "name": "Salz"},
   {"amount": "2", "name": "Eier", "note": "Größe M"},
   {"name": "Butter", "note": "zum Anbraten"}
 ],
 "steps": ["Alles verrühren.", "  ", "Knödel formen."]}
```''');
      expect(d.title, 'Topfenknödel');
      expect(d.servings, 4);
      expect(d.prepMinutes, 20);
      expect(d.cookMinutes, isNull);
      expect(d.ingredientLines, [
        '250 g Topfen',
        '1/2 TL Salz',
        '2 Eier, Größe M',
        'Butter, zum Anbraten',
      ]);
      expect(d.steps, ['Alles verrühren.', 'Knödel formen.']);
    });

    test('invalid answers throw', () {
      for (final bad in [
        'kein json',
        '[]',
        '{"title": "", "ingredients": [], "steps": []}',
        '{"title": "X", "steps": []}',
        '{"title": "X", "ingredients": [{"amount": 1}], "steps": []}',
      ]) {
        expect(
          () => draftFromAiJson(bad),
          throwsA(isA<InvalidDraftException>()),
          reason: bad,
        );
      }
    });
  });

  group('draftFromOcrText', () {
    test('with headers', () {
      final d = draftFromOcrText('''
Kaiserschmarrn
für 4 Portionen
Zutaten
250 ml Milch
4 Eier
Für den Teig:
150 g Mehl glatt
1 Prise Salz
Zubereitung
1. Eier trennen und Dotter mit Milch
verrühren.
2. Eiklar steif schlagen und unterheben.
''');
      expect(d.title, 'Kaiserschmarrn');
      expect(d.servings, 4);
      expect(d.ingredientLines, [
        '250 ml Milch',
        '4 Eier',
        '150 g Mehl glatt',
        '1 Prise Salz',
      ]);
      expect(d.steps, [
        'Eier trennen und Dotter mit Milch verrühren.',
        'Eiklar steif schlagen und unterheben.',
      ]);
    });

    test('without headers: amounts make the ingredient block', () {
      final d = draftFromOcrText('''
Schnelle Palatschinken
200 g Mehl
2 Eier
300 ml Milch
Alle Zutaten zu einem glatten Teig verrühren und kurz rasten lassen.
In einer Pfanne dünn ausbacken.
''');
      expect(d.title, 'Schnelle Palatschinken');
      expect(d.ingredientLines, ['200 g Mehl', '2 Eier', '300 ml Milch']);
      expect(d.steps, hasLength(2));
    });

    test('empty text gives an empty draft', () {
      final d = draftFromOcrText('  \n ');
      expect(d.title, '');
      expect(d.ingredientLines, isEmpty);
    });
  });
}
