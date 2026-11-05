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

  group('density and weight per piece', () {
    test('g <-> ml via density, own conversion wins', () {
      // 50 g Schlag for cream kept in ml (density 1.0).
      expect(Units.toBase(50, 'g', BaseUnit.ml, const {}, 1.0), 50);
      // 1 kg oil = ~1087 ml.
      expect(Units.toBase(1, 'kg', BaseUnit.ml, const {}, 0.92)!.round(), 1087);
      // 2 EL honey in g.
      expect(
        Units.toBase(2, 'EL', BaseUnit.g, const {}, 1.42),
        closeTo(42.6, 0.01),
      );
      // An own conversion beats the density.
      expect(Units.toBase(1, 'EL', BaseUnit.g, const {'EL': 10}, 0.55), 10);
      // No density: still unknown.
      expect(Units.toBase(50, 'g', BaseUnit.ml), isNull);
    });

    test('kg <-> Stk. via weight per piece', () {
      // 5 kg bananas at 120 g each.
      expect(
        Units.toBase(5, 'kg', BaseUnit.pcs, const {}, null, 120),
        closeTo(41.67, 0.01),
      );
      // 3 Erdäpfel in g.
      expect(Units.toBase(3, 'Stk.', BaseUnit.g, const {}, null, 100), 300);
      expect(Units.toBase(3, null, BaseUnit.g, const {}, null, 100), 300);
      expect(Units.toBase(1, 'kg', BaseUnit.pcs), isNull);
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
