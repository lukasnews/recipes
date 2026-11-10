import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/recipes/domain/step_text.dart';

void main() {
  test('pasted ChatGPT steps: numbers, wrapped lines, extra section', () {
    const text = '''
1. 450 ml Milch in einem Topf langsam erhitzen.
2. Schokolade klein hacken und in der warmen Milch schmelzen lassen.
3. Kakao, Zucker und Salz einrühren.
4. Speisestärke mit 2 EL kalter Milch glatt rühren.
5. Unter ständigem Rühren in die heiße
Schokolade geben.
6. Noch 1-2 Minuten leicht köcheln lassen, bis sie schön cremig wird.
Zum Verfeinern:
Schlagobers als Topping
• Mini-Marshmallows
Mein Tipp: Nimm 70 g Vollmilchschokolade.
''';
    final r = cleanStepText(text);
    expect(r.steps, [
      '450 ml Milch in einem Topf langsam erhitzen.',
      'Schokolade klein hacken und in der warmen Milch schmelzen lassen.',
      'Kakao, Zucker und Salz einrühren.',
      'Speisestärke mit 2 EL kalter Milch glatt rühren.',
      'Unter ständigem Rühren in die heiße Schokolade geben.',
      'Noch 1-2 Minuten leicht köcheln lassen, bis sie schön cremig wird.',
    ]);
    expect(
      r.extraNotes,
      'Zum Verfeinern:\nSchlagobers als Topping\n• Mini-Marshmallows\n'
      'Mein Tipp: Nimm 70 g Vollmilchschokolade.',
    );
  });

  test('one step per line stays as it is', () {
    final r = cleanStepText(
      'Eier trennen.\n- Dotter mit Zucker schaumig rühren\nMehl unterheben',
    );
    expect(r.steps, [
      'Eier trennen.',
      'Dotter mit Zucker schaumig rühren',
      'Mehl unterheben',
    ]);
    expect(r.extraNotes, isEmpty);
  });

  test('unnumbered sentence broken across lines is joined', () {
    final r = cleanStepText(
      'Die Milch in die heiße\nschokolade geben.\nRühren.',
    );
    expect(r.steps, ['Die Milch in die heiße schokolade geben.', 'Rühren.']);
  });

  test('a lone "2 Eier verquirlen" is not numbering', () {
    final r = cleanStepText('2 Eier verquirlen.\nMehl dazu.');
    expect(r.steps, ['2 Eier verquirlen.', 'Mehl dazu.']);
  });

  test('"Schritt 1:" prefix', () {
    final r = cleanStepText('Schritt 1: Ofen vorheizen.\nSchritt 2: Backen.');
    expect(r.steps, ['Ofen vorheizen.', 'Backen.']);
  });
}
