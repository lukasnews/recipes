import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/allergen.dart';

/// households/{hid}/members/{uid}: name and allergies per person.
/// Everyone in the household can read, each person only writes their own.
class MemberRepository {
  MemberRepository(this._db, this.householdId);

  final FirebaseFirestore _db;
  final String householdId;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('households').doc(householdId).collection('members');

  Stream<List<HouseholdMember>> watchAll() => _col.snapshots().map(
    (s) =>
        s.docs.map((d) => HouseholdMember.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName)),
  );

  Future<void> ensure(String uid, String displayName) =>
      _col.doc(uid).set({'displayName': displayName}, SetOptions(merge: true));

  Future<void> setAllergens(String uid, Set<Allergen> allergens) =>
      _col.doc(uid).set({
        'allergens': [for (final a in allergens) a.name]..sort(),
      }, SetOptions(merge: true));
}
