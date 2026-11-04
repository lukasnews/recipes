import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../ingredients/domain/ingredient.dart';
import '../domain/household.dart';

class InviteNotFoundException implements Exception {}

class HouseholdRepository {
  HouseholdRepository(this._db, {Random? random})
    : _random = random ?? Random.secure();

  final FirebaseFirestore _db;
  final Random _random;

  // No 0/O/1/I/L to avoid typos when reading a code aloud.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Stream<AppUser?> watchUser(String uid) =>
      _user(uid)
          .snapshots()
          .map((s) => s.exists ? AppUser.fromMap(s.id, s.data()!) : null);

  Stream<Household?> watchHousehold(String hid) => _db
      .collection('households')
      .doc(hid)
      .snapshots()
      .map((s) => s.exists ? Household.fromMap(s.id, s.data()!) : null);

  Future<void> ensureUser(String uid, String displayName) async {
    final ref = _user(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'displayName': displayName,
        'householdIds': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (displayName.isNotEmpty &&
        snap.data()?['displayName'] != displayName) {
      await ref.update({'displayName': displayName});
    }
  }

  String _newCode() => List.generate(
    6,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();

  /// Creates a household, copies the seed ingredients and links the user.
  Future<String> createHousehold({
    required String uid,
    required String name,
    required List<Ingredient> seed,
  }) async {
    var code = _newCode();
    for (var i = 0; i < 5; i++) {
      final existing = await _db.collection('invites').doc(code).get();
      if (!existing.exists) break;
      code = _newCode();
    }
    final household = _db.collection('households').doc();
    final batch = _db.batch()
      ..set(household, {
        'name': name,
        'memberIds': [uid],
        'inviteCode': code,
        'seedVersion': seedVersion,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_db.collection('invites').doc(code), {'householdId': household.id})
      ..set(_user(uid), {
        'householdIds': FieldValue.arrayUnion([household.id]),
      }, SetOptions(merge: true));
    for (final ing in seed) {
      batch.set(household.collection('ingredients').doc(ing.id), ing.toMap());
    }
    await batch.commit();
    return household.id;
  }

  /// Joins the household behind [code]. Needs a connection.
  Future<String> joinHousehold({
    required String uid,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    final invite = await _db.collection('invites').doc(normalized).get();
    final hid = invite.data()?['householdId'] as String?;
    if (!invite.exists || hid == null) throw InviteNotFoundException();
    final batch = _db.batch()
      ..update(_db.collection('households').doc(hid), {
        'memberIds': FieldValue.arrayUnion([uid]),
        'joinCode': normalized,
      })
      ..set(_user(uid), {
        'householdIds': FieldValue.arrayUnion([hid]),
      }, SetOptions(merge: true));
    await batch.commit();
    return hid;
  }

  Future<void> setUnitDisplay(String uid, String mode) =>
      _user(uid).set({'unitDisplay': mode}, SetOptions(merge: true));

  Future<void> rename(String hid, String name) =>
      _db.collection('households').doc(hid).update({'name': name});

  static const seedVersion = 2;

  /// One-time update for households created before allergens existed:
  /// copies allergens from the seed list onto matching ingredients.
  /// Updates (not sets) so deleted or merged ingredients stay gone.
  Future<void> backfillSeed(String hid, List<Ingredient> seed) async {
    final ref = _db.collection('households').doc(hid);
    final snap = await ref.get();
    final version = (snap.data()?['seedVersion'] as num?)?.toInt() ?? 1;
    if (version >= seedVersion) return;
    final ingredients = ref.collection('ingredients');
    final existing = {
      for (final d in (await ingredients.get()).docs) d.id: d.data(),
    };
    final batch = _db.batch();
    for (final ing in seed) {
      final data = existing[ing.id];
      if (data == null || ing.allergens.isEmpty) continue;
      if ((data['allergens'] as List<dynamic>?)?.isNotEmpty ?? false) continue;
      batch.update(ingredients.doc(ing.id), {
        'allergens': [for (final a in ing.allergens) a.name]..sort(),
      });
    }
    batch.update(ref, {'seedVersion': seedVersion});
    await batch.commit();
  }
}
