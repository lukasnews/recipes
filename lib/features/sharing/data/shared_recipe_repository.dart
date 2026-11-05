import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/shared_recipe.dart';

/// Recipes sent to other households (sharedRecipes/{code}).
class SharedRecipeRepository {
  SharedRecipeRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('sharedRecipes');

  /// Works offline: the copy is queued and readable for others once synced.
  Future<void> send(SharedRecipe recipe) =>
      _col.doc(recipe.code).set(recipe.toMap());

  Future<void> setPhoto(String code, String path) =>
      _col.doc(code).update({'photoPath': path});

  /// Null if there is no (or no longer a) recipe with this code. Needs
  /// network unless it was read before.
  Future<SharedRecipe?> fetch(String code) async {
    try {
      final doc = await _col.doc(code).get();
      final data = doc.data();
      if (data == null) return null;
      return SharedRecipe.fromMap(doc.id, data);
    } on FirebaseException catch (e) {
      // Expired or never existed: the rules deny the read.
      if (e.code == 'permission-denied' || e.code == 'not-found') return null;
      rethrow;
    }
  }

  /// What [uid] has sent, newest first.
  Stream<List<SharedRecipe>> watchSentBy(String uid) => _col
      .where('createdBy', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => SharedRecipe.fromMap(d.id, d.data())).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(2100)).compareTo(
              a.createdAt ?? DateTime(2100),
            ),
          ),
      );

  Future<void> delete(String code) => _col.doc(code).delete();
}
