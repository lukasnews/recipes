import '../../../core/firebase/map_utils.dart';
import '../../../core/matching/ingredient_matcher.dart';
import '../../../core/units/units.dart';

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
  );

  final String id;
  final String name;
  final List<String> synonyms;
  final Aisle aisle;
  final BaseUnit baseUnit;

  /// Unit key -> factor to [baseUnit].
  final Map<String, double> conversions;
  final bool alwaysAvailable;

  Map<String, dynamic> toMap() => {
    'name': name,
    'synonyms': synonyms,
    'aisle': aisle.name,
    'baseUnit': baseUnit.name,
    'conversions': conversions,
    'alwaysAvailable': alwaysAvailable,
  };

  MatchCandidate get candidate =>
      MatchCandidate(id: id, name: name, synonyms: synonyms);

  /// Amount in [baseUnit], or null if the unit can't be converted.
  double? toBase(double amount, String? unit) =>
      Units.toBase(amount, unit, baseUnit, conversions);

  Ingredient copyWith({
    String? name,
    List<String>? synonyms,
    Aisle? aisle,
    BaseUnit? baseUnit,
    Map<String, double>? conversions,
    bool? alwaysAvailable,
  }) => Ingredient(
    id: id,
    name: name ?? this.name,
    synonyms: synonyms ?? this.synonyms,
    aisle: aisle ?? this.aisle,
    baseUnit: baseUnit ?? this.baseUnit,
    conversions: conversions ?? this.conversions,
    alwaysAvailable: alwaysAvailable ?? this.alwaysAvailable,
  );
}
