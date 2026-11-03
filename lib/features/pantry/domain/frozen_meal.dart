import '../../../core/firebase/map_utils.dart';

/// A cooked dish in the freezer, counted in portions.
class FrozenMeal {
  const FrozenMeal({
    required this.id,
    required this.title,
    required this.portions,
    required this.frozenOn,
    this.recipeId,
    this.note = '',
  });

  factory FrozenMeal.fromMap(String id, Map<String, dynamic> m) => FrozenMeal(
    id: id,
    title: m.str('title'),
    portions: m.integer('portions') ?? 0,
    frozenOn: m.date('frozenOn') ?? DateTime.now(),
    recipeId: m.strOrNull('recipeId'),
    note: m.str('note'),
  );

  /// After this long a hint suggests eating it soon.
  static const eatWithin = Duration(days: 90);

  final String id;
  final String title;
  final int portions;
  final DateTime frozenOn;
  final String? recipeId;
  final String note;

  bool isOld(DateTime now) => now.difference(frozenOn) > eatWithin;
}
