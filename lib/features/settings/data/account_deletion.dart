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

  Future<void> deleteData(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final DocumentSnapshot<Map<String, dynamic>> user;
    try {
      // Server read: fails fast offline instead of hanging on writes.
      user = await userRef.get(const GetOptions(source: Source.server));
    } on FirebaseException {
      throw NeedsOnlineException();
    }
    final ids = ((user.data()?['householdIds'] as List<dynamic>?) ?? const [])
        .whereType<String>();
    for (final hid in ids) {
      final ref = _db.collection('households').doc(hid);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) continue;
      final members = ((data['memberIds'] as List<dynamic>?) ?? const [])
          .whereType<String>()
          .toList();
      // Own member entry first: the rules need us to still be a member.
      await ref.collection('members').doc(uid).delete();
      if (members.length > 1 || !members.contains(uid)) {
        await ref.update({
          'memberIds': FieldValue.arrayRemove([uid]),
        });
      } else {
        await _deleteHousehold(ref, data['inviteCode'] as String?);
      }
    }
    await userRef.delete();
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
