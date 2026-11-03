import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlanRepository {
  MealPlanRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('mealplan');

  /// Day key (`yyyy-MM-dd`) -> recipe ids.
  Stream<Map<String, List<String>>> watchAll() => _col.snapshots().map(
    (s) => {
      for (final d in s.docs)
        d.id: ((d.data()['recipeIds'] as List<dynamic>?) ?? const [])
            .whereType<String>()
            .toList(),
    },
  );

  Future<void> add(String day, String recipeId) => _col.doc(day).set({
    'recipeIds': FieldValue.arrayUnion([recipeId]),
  }, SetOptions(merge: true));

  Future<void> remove(String day, String recipeId) => _col.doc(day).set({
    'recipeIds': FieldValue.arrayRemove([recipeId]),
  }, SetOptions(merge: true));
}
