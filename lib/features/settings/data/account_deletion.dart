import 'package:cloud_firestore/cloud_firestore.dart';

import 'backup_service.dart';

class NeedsOnlineException implements Exception {}

/// Deletes a person's data: households where they are the last member
/// (with all data, photos and invite), their entry in shared households
/// (which stay for the others) and users/{uid}. The Auth account itself
/// is deleted afterwards by the caller. Needs a connection.
class AccountDeletionService {
  AccountDeletionService(this._db, this._deleteFiles);

  final FirebaseFirestore _db;

  /// Deletes recipe photos in Storage.
  final Future<void> Function(List<String> paths) _deleteFiles;

  Future<DocumentSnapshot<Map<String, dynamic>>> _serverUser(String uid) async {
    try {
      // Server read: fails fast offline instead of hanging on writes.
      return await _db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException {
      throw NeedsOnlineException();
    }
  }

  Future<void> deleteData(String uid) async {
    final user = await _serverUser(uid);
    final ids = ((user.data()?['householdIds'] as List<dynamic>?) ?? const [])
        .whereType<String>();
    for (final hid in ids) {
      await _leave(uid, hid);
    }
    await user.reference.delete();
  }

  /// Leaves [hid]; as the last member the household is deleted with all its
  /// data. Returns true when it was deleted.
  Future<bool> leaveHousehold(String uid, String hid) async {
    final user = await _serverUser(uid);
    final deleted = await _leave(uid, hid);
    final data = user.data() ?? const <String, dynamic>{};
    await user.reference.update({
      'householdIds': FieldValue.arrayRemove([hid]),
      if (data['activeHouseholdId'] == hid)
        'activeHouseholdId': FieldValue.delete(),
    });
    return deleted;
  }

  /// True when [uid] is the only member, so leaving deletes the household.
  Future<bool> isLastMember(String uid, String hid) async {
    final data = (await _db.collection('households').doc(hid).get()).data();
    final members = ((data?['memberIds'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .toList();
    return members.length <= 1 && members.contains(uid);
  }

  Future<bool> _leave(String uid, String hid) async {
    final ref = _db.collection('households').doc(hid);
    final data = (await ref.get()).data();
    if (data == null) return false;
    final members = ((data['memberIds'] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .toList();
    // Own member entry first: the rules need us to still be a member.
    await ref.collection('members').doc(uid).delete();
    if (members.length > 1 || !members.contains(uid)) {
      await ref.update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
      return false;
    }
    await _deleteHousehold(ref, data['inviteCode'] as String?);
    return true;
  }

  Future<void> _deleteHousehold(
    DocumentReference<Map<String, dynamic>> ref,
    String? inviteCode,
  ) async {
    final recipes = await ref.collection('recipes').get();
    final photos = [
      for (final r in recipes.docs)
        ...((r.data()['photoPaths'] as List<dynamic>?) ?? const [])
            .whereType<String>(),
    ];
    if (photos.isNotEmpty) await _deleteFiles(photos);

    for (final c in BackupService.collections) {
      final docs = (await ref.collection(c).get()).docs;
      for (var i = 0; i < docs.length; i += 450) {
        final batch = _db.batch();
        for (final d in docs.skip(i).take(450)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    if (inviteCode != null) {
      await _db.collection('invites').doc(inviteCode).delete();
    }
    await ref.delete();
  }
}
