import 'package:cloud_firestore/cloud_firestore.dart';

import '../../pantry/domain/pantry_item.dart';
import '../../recipes/domain/recipe.dart';
import '../../shopping/domain/shopping_item.dart';
import '../domain/ingredient.dart';

class IngredientRepository {
  IngredientRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  DocumentReference<Map<String, dynamic>> get _household =>
      _db.collection('households').doc(householdId);
  CollectionReference<Map<String, dynamic>> get _col =>
      _household.collection('ingredients');

  Stream<List<Ingredient>> watchAll() => _col.snapshots().map(
    (s) => s.docs.map((d) => Ingredient.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );

  /// New id for an ingredient that is about to be created.
  String newId() => _col.doc().id;

  Future<void> save(Ingredient ingredient) =>
      _col.doc(ingredient.id).set(ingredient.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Remembered pack sizes (base unit), e.g. after a purchase.
  Future<void> setPackSizes(String id, List<double> sizes) =>
      _col.doc(id).update({'packSizes': sizes});

  /// Merges [source] into [target]: source name and synonyms become synonyms
  /// of target, recipes, pantry and shopping list are re-linked, source is
  /// deleted. Both must share the same base unit for pantry amounts to add.
  Future<void> merge({
    required Ingredient source,
    required Ingredient target,
    required List<Recipe> recipes,
    required PantryItem? sourcePantry,
    required List<ShoppingItem> shopping,
  }) {
    final batch = _db.batch();
    final synonyms = {...target.synonyms, source.name, ...source.synonyms}
      ..removeWhere((s) => s.toLowerCase() == target.name.toLowerCase());
    final conversions = {...source.conversions, ...target.conversions};
    batch.update(_col.doc(target.id), {
      'synonyms': synonyms.toList(),
      'conversions': conversions,
    });

    for (final r in recipes.where((r) => r.ingredientIds.contains(source.id))) {
      final lines = [
        for (final l in r.ingredients)
          l.ingredientId == source.id ? l.withIngredientId(target.id) : l,
      ];
      final updated = r.copyWith(ingredients: lines);
      batch.update(_household.collection('recipes').doc(r.id), {
        'ingredients': updated.ingredients.map((l) => l.toMap()).toList(),
        'ingredientIds': updated.ingredientIds,
      });
    }

    if (sourcePantry != null) {
      if (source.baseUnit == target.baseUnit && sourcePantry.amount > 0) {
        batch.set(_household.collection('pantry').doc(target.id), {
          'amount': FieldValue.increment(sourcePantry.amount),
          'location': sourcePantry.location.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      batch.delete(_household.collection('pantry').doc(source.id));
    }

    for (final item in shopping.where((i) => i.ingredientId == source.id)) {
      batch.update(_household.collection('shopping').doc(item.id), {
        'ingredientId': target.id,
        'aisle': target.aisle.name,
      });
    }

    batch.delete(_col.doc(source.id));
    return batch.commit();
  }
}
