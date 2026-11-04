import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/pantry_item.dart';

/// Pantry amounts are only ever changed with [FieldValue.increment] so that
/// concurrent offline edits from several phones add up correctly.
class PantryRepository {
  PantryRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('pantry');

  Stream<Map<String, PantryItem>> watchAll() => _col.snapshots().map(
    (s) => {for (final d in s.docs) d.id: PantryItem.fromMap(d.id, d.data())},
  );

  Future<void> changeAmount(
    String ingredientId,
    double delta, {
    StorageLocation? location,
  }) => _col.doc(ingredientId).set({
    'amount': FieldValue.increment(delta),
    'location': ?location?.name,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> update(
    String ingredientId, {
    StorageLocation? location,
    double? Function()? minAmount,
    DateTime? Function()? expiresOn,
  }) => _col.doc(ingredientId).set({
    'location': ?location?.name,
    if (minAmount != null) 'minAmount': minAmount() ?? FieldValue.delete(),
    if (expiresOn != null)
      'expiresOn': switch (expiresOn()) {
        final d? => Timestamp.fromDate(d),
        null => FieldValue.delete(),
      },
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> delete(String ingredientId) => _col.doc(ingredientId).delete();
}
