import 'package:cloud_firestore/cloud_firestore.dart';

/// What is planned on one day: recipes and dishes from the freezer.
class MealPlanDay {
  const MealPlanDay({this.recipeIds = const [], this.frozenMealIds = const []});

  final List<String> recipeIds;
  final List<String> frozenMealIds;

  bool get isEmpty => recipeIds.isEmpty && frozenMealIds.isEmpty;
}

class MealPlanRepository {
  MealPlanRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('mealplan');

  static List<String> _ids(Object? v) =>
      ((v as List<dynamic>?) ?? const []).whereType<String>().toList();

  /// Day key (`yyyy-MM-dd`) -> plan of that day.
  Stream<Map<String, MealPlanDay>> watchAll() => _col.snapshots().map(
    (s) => {
      for (final d in s.docs)
        d.id: MealPlanDay(
          recipeIds: _ids(d.data()['recipeIds']),
          frozenMealIds: _ids(d.data()['frozenMealIds']),
        ),
    },
  );

  Future<void> add(String day, String recipeId) => _col.doc(day).set({
    'recipeIds': FieldValue.arrayUnion([recipeId]),
  }, SetOptions(merge: true));

  Future<void> remove(String day, String recipeId) => _col.doc(day).set({
    'recipeIds': FieldValue.arrayRemove([recipeId]),
  }, SetOptions(merge: true));

  Future<void> addFrozen(String day, String frozenMealId) => _col.doc(day).set({
    'frozenMealIds': FieldValue.arrayUnion([frozenMealId]),
  }, SetOptions(merge: true));

  Future<void> removeFrozen(String day, String frozenMealId) =>
      _col.doc(day).set({
        'frozenMealIds': FieldValue.arrayRemove([frozenMealId]),
      }, SetOptions(merge: true));
}
