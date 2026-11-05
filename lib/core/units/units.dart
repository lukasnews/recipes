/// Unit handling: canonical unit keys, generic conversions and formatting.
library;

import 'dart:math' as math;

/// Base unit every ingredient amount is stored in.
enum BaseUnit {
  g,
  ml,
  pcs;

  static BaseUnit parse(String? value) =>
      BaseUnit.values.firstWhere((u) => u.name == value, orElse: () => pcs);
}

/// A known unit with an optional generic conversion to a base unit.
class UnitDef {
  const UnitDef(this.key, {this.base, this.factor});

  /// Canonical key as stored in recipes and `ingredient.conversions`.
  final String key;

  /// Base unit this unit converts to without ingredient knowledge.
  final BaseUnit? base;

  /// Factor to [base].
  final double? factor;
}

abstract final class Units {
  static const List<UnitDef> all = [
    UnitDef('g', base: BaseUnit.g, factor: 1),
    UnitDef('kg', base: BaseUnit.g, factor: 1000),
    UnitDef('mg', base: BaseUnit.g, factor: 0.001),
    UnitDef('dag', base: BaseUnit.g, factor: 10),
    UnitDef('ml', base: BaseUnit.ml, factor: 1),
    UnitDef('l', base: BaseUnit.ml, factor: 1000),
    UnitDef('dl', base: BaseUnit.ml, factor: 100),
    UnitDef('cl', base: BaseUnit.ml, factor: 10),
    UnitDef('EL', base: BaseUnit.ml, factor: 15),
    UnitDef('TL', base: BaseUnit.ml, factor: 5),
    UnitDef('Prise', base: BaseUnit.g, factor: 0.5),
    UnitDef('Msp.', base: BaseUnit.g, factor: 0.5),
    UnitDef('Stk.', base: BaseUnit.pcs, factor: 1),
    // Ingredient specific only (need ingredient.conversions):
    UnitDef('Pkg.'),
    UnitDef('Becher'),
    UnitDef('Dose'),
    UnitDef('Bund'),
    UnitDef('Zehe'),
    UnitDef('Scheibe'),
    UnitDef('Würfel'),
    UnitDef('Tasse'),
    UnitDef('Glas'),
    UnitDef('Blatt'),
    UnitDef('Zweig'),
    UnitDef('Handvoll'),
    UnitDef('Schuss'),
    UnitDef('Spritzer'),
    UnitDef('Kopf'),
    UnitDef('Stange'),
    UnitDef('Tafel'),
    UnitDef('Flasche'),
    UnitDef('Knolle'),
  ];

  static final Map<String, UnitDef> _byKey = {for (final u in all) u.key: u};

  static const Map<String, String> _aliases = {
    'g': 'g',
    'gr': 'g',
    'gramm': 'g',
    'kg': 'kg',
    'kilo': 'kg',
    'kilogramm': 'kg',
    'mg': 'mg',
    'dag': 'dag',
    'dkg': 'dag',
    'deka': 'dag',
    'dekagramm': 'dag',
    'ml': 'ml',
    'milliliter': 'ml',
    'l': 'l',
    'ltr': 'l',
    'liter': 'l',
    'dl': 'dl',
    'deziliter': 'dl',
    'cl': 'cl',
    'zentiliter': 'cl',
    'el': 'EL',
    'essl': 'EL',
    'esslöffel': 'EL',
    'eßlöffel': 'EL',
    'tl': 'TL',
    'teel': 'TL',
    'teelöffel': 'TL',
    'prise': 'Prise',
    'prisen': 'Prise',
    'pr': 'Prise',
    'msp': 'Msp.',
    'messerspitze': 'Msp.',
    'messerspitzen': 'Msp.',
    'stk': 'Stk.',
    'st': 'Stk.',
    'stück': 'Stk.',
    'stueck': 'Stk.',
    'pkg': 'Pkg.',
    'pkt': 'Pkg.',
    'pck': 'Pkg.',
    'packung': 'Pkg.',
    'packungen': 'Pkg.',
    'päckchen': 'Pkg.',
    'packerl': 'Pkg.',
    'pkgs': 'Pkg.',
    'sackerl': 'Pkg.',
    'beutel': 'Pkg.',
    'becher': 'Becher',
    'dose': 'Dose',
    'dosen': 'Dose',
    'ds': 'Dose',
    'bund': 'Bund',
    'bd': 'Bund',
    'zehe': 'Zehe',
    'zehen': 'Zehe',
    'scheibe': 'Scheibe',
    'scheiben': 'Scheibe',
    'würfel': 'Würfel',
    'tasse': 'Tasse',
    'tassen': 'Tasse',
    'glas': 'Glas',
    'gläser': 'Glas',
    'blatt': 'Blatt',
    'blätter': 'Blatt',
    'zweig': 'Zweig',
    'zweige': 'Zweig',
    'zweiglein': 'Zweig',
    'handvoll': 'Handvoll',
    'hand voll': 'Handvoll',
    'schuss': 'Schuss',
    'spritzer': 'Spritzer',
    'kopf': 'Kopf',
    'köpfe': 'Kopf',
    'stange': 'Stange',
    'stangen': 'Stange',
    'tafel': 'Tafel',
    'tafeln': 'Tafel',
    'flasche': 'Flasche',
    'flaschen': 'Flasche',
    'knolle': 'Knolle',
    'knollen': 'Knolle',
  };

  /// Canonical key for a written unit (`"Esslöffel"` -> `"EL"`), or null.
  static String? canonical(String? raw) {
    if (raw == null) return null;
    var s = raw.trim().toLowerCase();
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.isEmpty) return null;
    return _aliases[s];
  }

  static UnitDef? byKey(String? key) => key == null ? null : _byKey[key];

  /// Factor to convert [unit] into [base], using ingredient specific
  /// [conversions] first and generic conversions second.
  /// Returns null when no conversion is known (UI must ask, never guess).
  /// Factor from [unit] to [base]. Order: the ingredient's own
  /// [conversions], the generic unit (kg → g), then the ingredient's
  /// [density] (g per ml: g ↔ ml) and [pieceGrams] (g per piece: g ↔ Stk.).
  static double? factorToBase(
    String? unit,
    BaseUnit base, [
    Map<String, double> conversions = const {},
    double? density,
    double? pieceGrams,
  ]) {
    if (unit == null || unit.isEmpty) unit = 'Stk.';
    if (unit == base.name || (unit == 'Stk.' && base == BaseUnit.pcs)) {
      return 1;
    }
    final specific = conversions[unit];
    if (specific != null) return specific;
    final def = _byKey[unit];
    final f = def?.factor;
    if (def == null || f == null) return null;
    if (def.base == base) return f;

    // One [unit] in grams / millilitres, as far as known.
    double? grams;
    double? millilitres;
    switch (def.base) {
      case BaseUnit.g:
        grams = f;
        if (density != null && density > 0) millilitres = f / density;
      case BaseUnit.ml:
        millilitres = f;
        if (density != null && density > 0) grams = f * density;
      case BaseUnit.pcs:
        if (pieceGrams != null && pieceGrams > 0) {
          grams = f * pieceGrams;
          if (density != null && density > 0) millilitres = grams / density;
        }
      case null:
        return null;
    }
    return switch (base) {
      BaseUnit.g => grams,
      BaseUnit.ml => millilitres,
      BaseUnit.pcs =>
        grams != null && pieceGrams != null && pieceGrams > 0
            ? grams / pieceGrams
            : null,
    };
  }

  /// Converts [amount] in [unit] to the ingredient's [base] unit.
  static double? toBase(
    double amount,
    String? unit,
    BaseUnit base, [
    Map<String, double> conversions = const {},
    double? density,
    double? pieceGrams,
  ]) {
    final f = factorToBase(unit, base, conversions, density, pieceGrams);
    return f == null ? null : amount * f;
  }
}

/// Scales [amount] from [fromServings] to [toServings].
double scaleAmount(double amount, int fromServings, int toServings) {
  if (fromServings <= 0) return amount;
  return amount * toServings / fromServings;
}

/// Formats a number the Austrian way: comma decimal, at most 2 decimals,
/// common fractions for small values.
String formatAmount(double value, {bool fractions = true}) {
  if (value.isNaN || value.isInfinite) return '';
  final whole = value.truncate();
  final frac = value - whole;
  const fractionSymbols = [(0.25, '¼'), (0.5, '½'), (0.75, '¾')];
  if (fractions && value < 10) {
    for (final (f, symbol) in fractionSymbols) {
      if ((frac - f).abs() < 0.01) {
        return whole == 0 ? symbol : '$whole $symbol';
      }
    }
  }
  final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  final rounded = _round(value, decimals);
  var s = rounded.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

double _round(double v, int decimals) {
  final p = math.pow(10, decimals);
  return (v * p).round() / p;
}

/// Formats an amount stored in a base unit, switching to kg / l when large.
String formatBaseAmount(double amount, BaseUnit base) {
  switch (base) {
    case BaseUnit.g when amount >= 1000:
      return '${formatAmount(amount / 1000, fractions: false)} kg';
    case BaseUnit.ml when amount >= 1000:
      return '${formatAmount(amount / 1000, fractions: false)} l';
    case BaseUnit.pcs:
      return '${formatAmount(amount)} Stk.';
    default:
      return '${formatAmount(amount)} ${base.name}';
  }
}

/// Formats an amount with an optional unit, e.g. `"200 g"`, `"½ TL"`, `"3"`.
String formatWithUnit(double? amount, String? unit) {
  final a = amount == null ? '' : formatAmount(amount);
  final u = unit ?? '';
  return [a, u].where((s) => s.isNotEmpty).join(' ');
}
