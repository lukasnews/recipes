import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/cook_history.dart';
import '../domain/nutrition.dart';
import '../domain/recipe.dart';

class RecipeRepository {
  RecipeRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  DocumentReference<Map<String, dynamic>> get _household =>
      _db.collection('households').doc(householdId);
  CollectionReference<Map<String, dynamic>> get _col =>
      _household.collection('recipes');

  Stream<List<Recipe>> watchAll() => _col.snapshots().map(
    (s) => s.docs.map((d) => Recipe.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
  );

  String newId() => _col.doc().id;

  Stream<List<CookLogEntry>> watchCookLog() => _household
      .collection('cookLog')
      .snapshots()
      .map(
        (s) => s.docs.map((d) => CookLogEntry.fromMap(d.id, d.data())).toList(),
      );

  Future<void> save(Recipe recipe, {required bool isNew}) =>
      _col.doc(recipe.id).set({
        ...recipe.toMap(),
        // The ingredients may have changed: the estimate is stale.
        'nutrition': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Only the tags (e.g. accepted AI suggestions); keeps the estimate.
  Future<void> setTags(String id, List<String> tags) =>
      _col.doc(id).update({'tags': tags});

  Future<void> setCollections(String id, List<String> collections) =>
      _col.doc(id).update({'collections': collections..sort()});

  Future<void> setRating(String id, int rating) =>
      _col.doc(id).update({'rating': rating});

  Future<void> setNutrition(String id, Nutrition n) => _col.doc(id).update({
    'nutrition': {...n.toMap(), 'estimatedAt': FieldValue.serverTimestamp()},
  });

  /// Deducts [deductions] (already clamped) from the pantry and logs it.
  /// Returns the cook log id for undo.
  String cook({
    required Recipe recipe,
    required int servings,
    required Map<String, double> deductions,
    void Function(Future<void>)? onCommit,
  }) {
    final log = _household.collection('cookLog').doc();
    final batch = _db.batch();
    deductions.forEach((id, amount) {
      if (amount <= 0) return;
      batch.set(_household.collection('pantry').doc(id), {
        'amount': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    batch.set(log, {
      'recipeId': recipe.id,
      'servings': servings,
      'cookedAt': FieldValue.serverTimestamp(),
      'deductions': [
        for (final e in deductions.entries)
          if (e.value > 0) {'ingredientId': e.key, 'amountBase': e.value},
      ],
      'undone': false,
    });
    final commit = batch.commit();
    onCommit?.call(commit);
    return log.id;
  }

  /// Books the deductions of a cook log back into the pantry.
  Future<void> undoCook(String logId, Map<String, double> deductions) {
    final batch = _db.batch();
    deductions.forEach((id, amount) {
      batch.set(_household.collection('pantry').doc(id), {
        'amount': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    batch.update(_household.collection('cookLog').doc(logId), {'undone': true});
    return batch.commit();
  }
}
