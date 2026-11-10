import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/menu.dart';

/// households/{hid}/menus: menus for guests.
class MenuRepository {
  MenuRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('menus');

  /// Upcoming dates first, then without date, by title.
  Stream<List<Menu>> watchAll() => _col.snapshots().map(
    (s) =>
        s.docs.map((d) => Menu.fromMap(d.id, d.data())).toList()..sort((a, b) {
          final da = a.date ?? '9999';
          final db = b.date ?? '9999';
          final c = da.compareTo(db);
          return c != 0
              ? c
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        }),
  );

  String newId() => _col.doc().id;

  Future<void> save(Menu menu, {bool isNew = false}) => _col.doc(menu.id).set({
    ...menu.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
    if (isNew) 'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}
