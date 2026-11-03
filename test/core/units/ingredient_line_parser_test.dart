import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/ingredient_line_parser.dart';

void main() {
  void expectLine(
    String line, {
    double? amount,
    String? unit,
    required String name,
    String? note,
  }) {
    final p = parseIngredientLine(line);
    expect(p.amount, amount, reason: line);
    expect(p.unit, unit, reason: line);
    expect(p.name, name, reason: line);
    expect(p.note, note, reason: line);
    expect(p.rawText, line.trim());
  }

  test('amount, unit and name', () {
    expectLine('200 g Mehl glatt', amount: 200, unit: 'g', name: 'Mehl glatt');
    expectLine('200g Zucker', amount: 200, unit: 'g', name: 'Zucker');
    expectLine('1,5 l Milch', amount: 1.5, unit: 'l', name: 'Milch');
    expectLine('2 EL Öl', amount: 2, unit: 'EL', name: 'Öl');
    expectLine(
      '1 Pkg. Vanillezucker',
      amount: 1,
      unit: 'Pkg.',
      name: 'Vanillezucker',
    );
    expectLine('25 dag Topfen', amount: 25, unit: 'dag', name: 'Topfen');
  });

  test('fractions and ranges', () {
    expectLine('½ TL Salz', amount: 0.5, unit: 'TL', name: 'Salz');
    expectLine('1/2 TL Zimt', amount: 0.5, unit: 'TL', name: 'Zimt');
    expectLine('1 1/2 Tassen Reis', amount: 1.5, unit: 'Tasse', name: 'Reis');
    expectLine('1½ kg Erdäpfel', amount: 1.5, unit: 'kg', name: 'Erdäpfel');
    expectLine('2-3 Eier', amount: 3, name: 'Eier');
    expectLine(
      'ca. 100 ml Schlagobers',
      amount: 100,
      unit: 'ml',
      name: 'Schlagobers',
    );
  });

  test('notes from parentheses and commas', () {
    expectLine('3 Eier (Größe M)', amount: 3, name: 'Eier', note: 'Größe M');
    expectLine(
      '250 g Butter, weich',
      amount: 250,
      unit: 'g',
      name: 'Butter',
      note: 'weich',
    );
    expectLine(
      '- 1 Zwiebel, fein gehackt',
      amount: 1,
      name: 'Zwiebel',
      note: 'fein gehackt',
    );
  });

  test('no amount', () {
    expectLine('Salz und Pfeffer', name: 'Salz und Pfeffer');
    expectLine('etwas Petersilie', name: 'etwas Petersilie');
  });

  test('name that starts like a unit is kept', () {
    expectLine('2 Gläser Gurken', amount: 2, unit: 'Glas', name: 'Gurken');
    expectLine('1 Liter Wasser', amount: 1, unit: 'l', name: 'Wasser');
    expectLine(
      '4 Blätter Gelatine',
      amount: 4,
      unit: 'Blatt',
      name: 'Gelatine',
    );
  });
}
