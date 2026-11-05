import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/shared_list.dart';

/// Live links to the household's shopping list (sharedLists/{token}).
class SharedListRepository {
  SharedListRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('sharedLists');

  Future<void> create(SharedList list) =>
      _col.doc(list.token).set(list.toMap());

  Stream<List<SharedList>> watchFor(String householdId) => _col
      .where('householdId', isEqualTo: householdId)
      .snapshots()
      .map((s) => [for (final d in s.docs) SharedList.fromMap(d.id, d.data())]);

  Future<void> delete(String token) => _col.doc(token).delete();
}
