import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/units.dart';

void main() {
  group('Units.canonical', () {
    test('maps aliases', () {
      expect(Units.canonical('Esslöffel'), 'EL');
      expect(Units.canonical('el'), 'EL');
      expect(Units.canonical('TL.'), 'TL');
      expect(Units.canonical('dag'), 'dag');
      expect(Units.canonical('Pkg.'), 'Pkg.');
      expect(Units.canonical('Packung'), 'Pkg.');
      expect(Units.canonical('Stück'), 'Stk.');
      expect(Units.canonical('Mehl'), isNull);
    });
  });

  group('Units.toBase', () {
    test('generic conversions', () {
      expect(Units.toBase(1.5, 'kg', BaseUnit.g), 1500);
      expect(Units.toBase(25, 'dag', BaseUnit.g), 250);
      expect(Units.toBase(0.5, 'l', BaseUnit.ml), 500);
      expect(Units.toBase(2, 'EL', BaseUnit.ml), 30);
      expect(Units.toBase(1, 'TL', BaseUnit.ml), 5);
      expect(Units.toBase(3, null, BaseUnit.pcs), 3);
    });

    test('ingredient conversions win and fill gaps', () {
      const flour = {'EL': 10.0, 'Pkg.': 1000.0};
      expect(Units.toBase(2, 'EL', BaseUnit.g, flour), 20);
      expect(Units.toBase(1, 'Pkg.', BaseUnit.g, flour), 1000);
    });

    test('unknown conversion returns null instead of guessing', () {
      expect(Units.toBase(2, 'EL', BaseUnit.g), isNull);
      expect(Units.toBase(1, 'Becher', BaseUnit.ml), isNull);
      expect(Units.toBase(100, 'g', BaseUnit.pcs), isNull);
      expect(Units.toBase(2, null, BaseUnit.g), isNull);
    });
  });

  test('scaleAmount', () {
    expect(scaleAmount(200, 4, 2), 100);
    expect(scaleAmount(3, 4, 6), 4.5);
    expect(scaleAmount(3, 0, 6), 3);
  });

  group('formatAmount', () {
    test('uses comma and fractions', () {
      expect(formatAmount(0.5), '½');
      expect(formatAmount(1.5), '1 ½');
      expect(formatAmount(0.25), '¼');
      expect(formatAmount(2), '2');
      expect(formatAmount(1.2), '1,2');
      expect(formatAmount(12.25), '12,3');
      expect(formatAmount(333.33), '333');
    });

    test('formatBaseAmount switches to kg and l', () {
      expect(formatBaseAmount(1500, BaseUnit.g), '1,5 kg');
      expect(formatBaseAmount(250, BaseUnit.g), '250 g');
      expect(formatBaseAmount(2000, BaseUnit.ml), '2 l');
      expect(formatBaseAmount(3, BaseUnit.pcs), '3 Stk.');
    });
  });
}
