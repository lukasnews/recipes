import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/frozen_meal.dart';

/// households/{hid}/frozenMeals: cooked dishes in the freezer.
/// Portions change with increments (several phones, offline).
class FrozenMealRepository {
  FrozenMealRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('frozenMeals');

  Stream<List<FrozenMeal>> watchAll() => _col.snapshots().map(
    (s) =>
        s.docs.map((d) => FrozenMeal.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.frozenOn.compareTo(b.frozenOn)),
  );

  Future<void> add({
    required String title,
    required int portions,
    String? recipeId,
    DateTime? frozenOn,
    String note = '',
  }) => _col.add({
    'title': title,
    'portions': portions,
    'recipeId': ?recipeId,
    'frozenOn': Timestamp.fromDate(frozenOn ?? DateTime.now()),
    'note': note,
  });

  /// Takes out or adds portions. Taking out the last one removes the entry.
  Future<void> changePortions(FrozenMeal meal, int delta) {
    if (meal.portions + delta <= 0) return _col.doc(meal.id).delete();
    return _col.doc(meal.id).update({'portions': FieldValue.increment(delta)});
  }

  Future<void> update(
    String id, {
    required String title,
    required int portions,
    required DateTime frozenOn,
    required String note,
  }) => _col.doc(id).update({
    'title': title,
    'portions': portions,
    'frozenOn': Timestamp.fromDate(frozenOn),
    'note': note,
  });

  Future<void> delete(String id) => _col.doc(id).delete();
}
