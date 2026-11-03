import 'package:cloud_firestore/cloud_firestore.dart';

import '../../ingredients/domain/ingredient.dart';
import '../domain/shopping_item.dart';

class ShoppingRepository {
  ShoppingRepository(this._db, this.householdId, this.uid);

  final FirebaseFirestore _db;
  final String householdId;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('shopping');

  Stream<List<ShoppingItem>> watchAll() => _col.snapshots().map(
    (s) => s.docs.map((d) => ShoppingItem.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase())),
  );

  /// Adds an item. If the same ingredient is already on the list and not
  /// checked, the amount is added instead of creating a duplicate.
  Future<void> add({
    required String text,
    required List<ShoppingItem> current,
    String? ingredientId,
    double? amount,
    String? unit,
    Aisle aisle = Aisle.other,
    String? fromRecipeId,
  }) {
    if (ingredientId != null) {
      final existing = current.where(
        (i) => !i.checked && i.ingredientId == ingredientId,
      );
      for (final e in existing) {
        if (e.unit == unit) {
          if (amount == null || e.amount == null) return Future.value();
          return _col.doc(e.id).update({
            'amount': FieldValue.increment(amount),
          });
        }
      }
      if (existing.isNotEmpty && amount == null) return Future.value();
    }
    return _col.add({
      ...ShoppingItem(
        id: '',
        text: text,
        ingredientId: ingredientId,
        amount: amount,
        unit: unit,
        aisle: aisle,
        fromRecipeId: fromRecipeId,
        addedBy: uid,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setChecked(String id, bool checked) =>
      _col.doc(id).update({'checked': checked});

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> deleteAll(Iterable<String> ids) {
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    return batch.commit();
  }

  /// Moves checked items into the pantry and removes them from the list.
  /// Items whose amount can't be converted stay checked on the list.
  Future<void> moveCheckedToPantry(
    List<ShoppingItem> items,
    Map<String, Ingredient> ingredients,
  ) {
    final batch = _db.batch();
    final pantry = _db
        .collection('households')
        .doc(householdId)
        .collection('pantry');
    for (final item in items.where((i) => i.checked)) {
      final ing = ingredients[item.ingredientId];
      final base = (ing == null || item.amount == null)
          ? null
          : ing.toBase(item.amount!, item.unit);
      if (ing != null && item.amount != null && base == null) continue;
      if (ing != null && base != null && base > 0) {
        batch.set(pantry.doc(ing.id), {
          'amount': FieldValue.increment(base),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      batch.delete(_col.doc(item.id));
    }
    return batch.commit();
  }
}
