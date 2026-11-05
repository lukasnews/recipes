import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/units/units.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../recipes/domain/recipe.dart';
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

  /// A code no other household uses (checked a few times).
  Future<String> _freeCode() async {
    var code = _newCode();
    for (var i = 0; i < 5; i++) {
      final existing = await _db.collection('invites').doc(code).get();
      if (!existing.exists) break;
      code = _newCode();
    }
    return code;
  }

  /// Replaces the invite code; the old one stops working. Needs a
  /// connection. Returns the new code.
  Future<String> renewInviteCode(String hid, String oldCode) async {
    final code = await _freeCode();
    final household = _db.collection('households').doc(hid);
    final batch = _db.batch()
      ..update(household, {'inviteCode': code})
      ..set(_db.collection('invites').doc(code), {'householdId': hid})
      ..delete(_db.collection('invites').doc(oldCode));
    await batch.commit();
    return code;
  }

  Future<void> setDisplayName(String uid, String name) =>
      _user(uid).set({'displayName': name}, SetOptions(merge: true));

  /// Creates a household, copies the seed ingredients and links the user.
  Future<String> createHousehold({
    required String uid,
    required String name,
    required List<Ingredient> seed,
    List<Recipe> recipes = const [],
  }) async {
    final code = await _freeCode();
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
        'activeHouseholdId': household.id,
      }, SetOptions(merge: true));
    for (final ing in seed) {
      batch.set(household.collection('ingredients').doc(ing.id), ing.toMap());
    }
    for (final r in recipes) {
      batch.set(household.collection('recipes').doc(r.id), {
        ...r.toMap(),
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
        'activeHouseholdId': hid,
      }, SetOptions(merge: true));
    await batch.commit();
    return hid;
  }

  Future<void> setFavorite(String uid, String recipeId, {required bool on}) =>
      _user(uid).set({
        'favoriteRecipeIds': on
            ? FieldValue.arrayUnion([recipeId])
            : FieldValue.arrayRemove([recipeId]),
      }, SetOptions(merge: true));

  /// Null resets to the default order.
  Future<void> setAisleOrder(String uid, List<String>? order) => _user(
    uid,
  ).set({'aisleOrder': order ?? FieldValue.delete()}, SetOptions(merge: true));

  Future<void> setOnboardingDone(String uid) =>
      _user(uid).set({'onboardingDone': true}, SetOptions(merge: true));

  Future<void> setActiveHousehold(String uid, String hid) =>
      _user(uid).set({'activeHouseholdId': hid}, SetOptions(merge: true));

  Future<void> setUnitDisplay(String uid, String mode) =>
      _user(uid).set({'unitDisplay': mode}, SetOptions(merge: true));

  Future<void> setShoppingByStore(String uid, {required bool on}) =>
      _user(uid).set({'shoppingByStore': on}, SetOptions(merge: true));

  /// The household's shops, in its order.
  Future<void> setStores(String hid, List<String> stores) =>
      _db.collection('households').doc(hid).update({'stores': stores});

  Future<void> rename(String hid, String name) =>
      _db.collection('households').doc(hid).update({'name': name});

  static const seedVersion = 5;

  /// One-time update of older households from the seed list: allergens
  /// (v2), missing synonyms and conversions (v3, e.g. "Schlag" and g → ml
  /// for Schlagobers), density and weight per piece (v4). Only adds;
  /// names, own synonyms, conversions and weights stay.
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
    // v5: parts (Eiweiß, Dotter, Zitronenschale …) know their whole. A part
    // the household created itself (e.g. "Eiweiß" from a recipe) is linked
    // instead of adding a second one.
    final byName = <String, String>{
      for (final e in existing.entries)
        for (final n in [
          e.value['name'],
          ...(e.value['synonyms'] as List<dynamic>? ?? const []),
        ])
          '$n'.toLowerCase(): e.key,
    };
    for (final ing in seed) {
      final part = ing.partOf;
      if (part == null || existing[ing.id] != null) continue;
      if (existing[part.id] == null) continue;
      final ownId = [
        ing.name,
        ...ing.synonyms,
      ].map((n) => byName[n.toLowerCase()]).nonNulls.firstOrNull;
      if (ownId == null) {
        batch.set(ingredients.doc(ing.id), ing.toMap());
        continue;
      }
      final own = existing[ownId]!;
      final partOf = _partOfFor(own, ing);
      if (own['partOf'] != null || partOf == null) continue;
      batch.update(ingredients.doc(ownId), {
        'partOf': partOf.toMap(),
        if (own['pieceGrams'] == null && ing.pieceGrams != null)
          'pieceGrams': ing.pieceGrams,
        'synonyms': FieldValue.arrayUnion([
          for (final n in [ing.name, ...ing.synonyms])
            if (n.toLowerCase() != '${own['name']}'.toLowerCase()) n,
        ]),
      });
    }
    for (final ing in seed) {
      final data = existing[ing.id];
      if (data == null) continue;
      final update = <Object, Object?>{};
      final hasAllergens =
          (data['allergens'] as List<dynamic>?)?.isNotEmpty ?? false;
      if (!hasAllergens && ing.allergens.isNotEmpty) {
        update['allergens'] = [for (final a in ing.allergens) a.name]..sort();
      }
      final known = {
        (data['name'] as String? ?? '').toLowerCase(),
        for (final s in (data['synonyms'] as List<dynamic>? ?? const []))
          '$s'.toLowerCase(),
      };
      final newSynonyms = [
        for (final s in ing.synonyms)
          if (!known.contains(s.toLowerCase())) s,
      ];
      if (newSynonyms.isNotEmpty) {
        update['synonyms'] = FieldValue.arrayUnion(newSynonyms);
      }
      final conversions =
          (data['conversions'] as Map<dynamic, dynamic>?) ?? const {};
      // Same base unit only, else the factor would be wrong.
      if (data['baseUnit'] == ing.baseUnit.name) {
        for (final e in ing.conversions.entries) {
          if (!conversions.containsKey(e.key)) {
            update[FieldPath(['conversions', e.key])] = e.value;
          }
        }
      }
      if (data['density'] == null && ing.density != null) {
        update['density'] = ing.density;
      }
      if (data['pieceGrams'] == null && ing.pieceGrams != null) {
        update['pieceGrams'] = ing.pieceGrams;
      }
      final partOf = _partOfFor(data, ing);
      if (data['partOf'] == null &&
          partOf != null &&
          existing[partOf.id] != null) {
        update['partOf'] = partOf.toMap();
      }
      if (update.isNotEmpty) batch.update(ingredients.doc(ing.id), update);
    }
    batch.update(ref, {'seedVersion': seedVersion});
    await batch.commit();
  }

  /// The seed's partOf for an existing ingredient [data]; the factor is per
  /// base unit, so a part kept in grams (seed: pieces) is converted with the
  /// piece weight, other mismatches are skipped.
  static PartOf? _partOfFor(Map<String, dynamic> data, Ingredient seed) {
    final p = seed.partOf;
    if (p == null) return null;
    final base = data['baseUnit'];
    if (base == seed.baseUnit.name) return p;
    final grams = seed.pieceGrams;
    if (base == 'g' && seed.baseUnit == BaseUnit.pcs && grams != null) {
      return PartOf(p.id, p.per / grams);
    }
    return null;
  }
}
