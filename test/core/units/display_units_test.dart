import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/core/units/display_units.dart';

void main() {
  String show(double a, String? u, UnitDisplay m) => displayQuantity(a, u, m);

  test('original keeps everything', () {
    expect(show(25, 'dag', UnitDisplay.original), '25 dag');
    expect(show(250, 'g', UnitDisplay.original), '250 g');
  });

  test('metric: g and ml, kg and l from 1000', () {
    expect(show(25, 'dag', UnitDisplay.metric), '250 g');
    expect(show(0.5, 'kg', UnitDisplay.metric), '500 g');
    expect(show(150, 'dag', UnitDisplay.metric), '1,5 kg');
    expect(show(0.125, 'l', UnitDisplay.metric), '125 ml');
    expect(show(2, 'dl', UnitDisplay.metric), '200 ml');
    expect(show(1500, 'ml', UnitDisplay.metric), '1,5 l');
  });

  test('austrian: dag between 10 g and 1 kg', () {
    expect(show(250, 'g', UnitDisplay.austrian), '25 dag');
    expect(show(125, 'g', UnitDisplay.austrian), '12,5 dag');
    expect(show(5, 'g', UnitDisplay.austrian), '5 g');
    expect(show(1200, 'g', UnitDisplay.austrian), '1,2 kg');
    expect(show(0.25, 'kg', UnitDisplay.austrian), '25 dag');
    expect(show(250, 'ml', UnitDisplay.austrian), '250 ml');
  });

  test('non-convertible units stay', () {
    for (final m in UnitDisplay.values) {
      expect(show(2, 'EL', m), '2 EL');
      expect(show(0.5, 'TL', m), '½ TL');
      expect(show(1, 'Pkg.', m), '1 Pkg.');
      expect(show(3, null, m), '3');
    }
  });
}
