import '../../../core/firebase/map_utils.dart';
import '../../../core/matching/ingredient_matcher.dart';
import '../../../core/units/units.dart';
import '../../household/domain/allergen.dart';

/// Supermarket section, used to group the shopping list.
enum Aisle {
  produce,
  bread,
  dairy,
  meat,
  baking,
  dry,
  spices,
  frozen,
  drinks,
  other;

  static Aisle parse(String? v) =>
      Aisle.values.firstWhere((a) => a.name == v, orElse: () => other);
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    this.synonyms = const [],
    this.aisle = Aisle.other,
    this.baseUnit = BaseUnit.pcs,
    this.conversions = const {},
    this.alwaysAvailable = false,
    this.allergens = const {},
    this.density,
    this.pieceGrams,
    this.packSizes = const [],
  });

  factory Ingredient.fromMap(String id, Map<String, dynamic> m) => Ingredient(
    id: id,
    name: m.str('name'),
    synonyms: m.strings('synonyms'),
    aisle: Aisle.parse(m.strOrNull('aisle')),
    baseUnit: BaseUnit.parse(m.strOrNull('baseUnit')),
    conversions: {
      for (final e
          in ((m['conversions'] as Map<dynamic, dynamic>?) ?? const {}).entries)
        if (e.value is num) '${e.key}': (e.value as num).toDouble(),
    },
    alwaysAvailable: m.flag('alwaysAvailable'),
    allergens: Allergen.parseAll(m.strings('allergens')),
    density: m.dbl('density'),
    pieceGrams: m.dbl('pieceGrams'),
    packSizes: [
      for (final v in (m['packSizes'] as List<dynamic>?) ?? const [])
        if (v is num && v > 0) v.toDouble(),
    ],
  );

  final String id;
  final String name;
  final List<String> synonyms;
  final Aisle aisle;
  final BaseUnit baseUnit;

  /// Unit key -> factor to [baseUnit].
  final Map<String, double> conversions;
  final bool alwaysAvailable;

  /// EU allergens, e.g. gluten for flour, milk for Topfen.
  final Set<Allergen> allergens;

  /// Grams per millilitre (Wasser 1, Öl 0.92, Mehl 0.55): g ↔ ml without
  /// asking.
  final double? density;

  /// Average grams per piece (Banane 120): kg ↔ Stk. without asking.
  final double? pieceGrams;

  /// Pack sizes bought so far, in [baseUnit], oldest first (learned on the
  /// way into the pantry or from a barcode; editable).
  final List<double> packSizes;

  Map<String, dynamic> toMap() => {
    'name': name,
    'synonyms': synonyms,
    'aisle': aisle.name,
    'baseUnit': baseUnit.name,
    'conversions': conversions,
    'alwaysAvailable': alwaysAvailable,
    'allergens': [for (final a in allergens) a.name]..sort(),
    'density': ?density,
    'pieceGrams': ?pieceGrams,
    if (packSizes.isNotEmpty) 'packSizes': packSizes,
  };

  MatchCandidate get candidate =>
      MatchCandidate(id: id, name: name, synonyms: synonyms);

  /// Amount in [baseUnit], or null if the unit can't be converted.
  double? toBase(double amount, String? unit) =>
      Units.toBase(amount, unit, baseUnit, conversions, density, pieceGrams);

  Ingredient copyWith({
    String? name,
    List<String>? synonyms,
    Aisle? aisle,
    BaseUnit? baseUnit,
    Map<String, double>? conversions,
    bool? alwaysAvailable,
    Set<Allergen>? allergens,
    double? Function()? density,
    double? Function()? pieceGrams,
    List<double>? packSizes,
  }) => Ingredient(
    id: id,
    name: name ?? this.name,
    synonyms: synonyms ?? this.synonyms,
    aisle: aisle ?? this.aisle,
    baseUnit: baseUnit ?? this.baseUnit,
    conversions: conversions ?? this.conversions,
    alwaysAvailable: alwaysAvailable ?? this.alwaysAvailable,
    allergens: allergens ?? this.allergens,
    density: density == null ? this.density : density(),
    pieceGrams: pieceGrams == null ? this.pieceGrams : pieceGrams(),
    packSizes: packSizes ?? this.packSizes,
  );

  /// Shows [preferred] (one of the synonyms) as the name; the old name becomes
  /// a synonym, so matching still finds every term.
  Ingredient withPreferredName(String preferred) {
    final p = preferred.trim();
    if (p.isEmpty || p.toLowerCase() == name.toLowerCase()) return this;
    final others = [
      name,
      ...synonyms.where((s) => s.trim().toLowerCase() != p.toLowerCase()),
    ];
    return copyWith(name: p, synonyms: others);
  }

  /// Units offered when entering an amount for this ingredient.
  List<String> get unitChoices => {
    ...switch (baseUnit) {
      BaseUnit.g => const ['g', 'kg', 'dag'],
      BaseUnit.ml => const ['ml', 'l', 'dl'],
      BaseUnit.pcs => const ['Stk.'],
    },
    ...conversions.keys,
  }.toList();
}
