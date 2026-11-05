import '../../ingredients/domain/ingredient.dart';

/// The person's walk through their store: stored aisle names first (in
/// that order), then any aisle not listed in the default order.
List<Aisle> aisleOrder(List<String>? stored) {
  final known = <Aisle>[
    for (final name in stored ?? const <String>[])
      if (Aisle.values.any((a) => a.name == name)) Aisle.parse(name),
  ];
  final unique = <Aisle>{...known};
  return [...unique, ...Aisle.values.where((a) => !unique.contains(a))];
}
