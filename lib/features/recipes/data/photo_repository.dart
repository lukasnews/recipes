import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Recipe photos in Cloud Storage under households/{hid}/recipes/{rid}/.
/// Images are already downscaled by the picker (1600 px, JPEG 80 %).
abstract class PhotoRepository {
  /// Uploads [file] and appends its path to the recipe. Needs network.
  Future<String> upload(String recipeId, String file);

  /// Removes the photo from the recipe and deletes it in Storage.
  Future<void> remove(String recipeId, String path);

  Future<String> downloadUrl(String path);

  /// Deletes stored files only (e.g. after the recipe itself was deleted).
  Future<void> deleteFiles(Iterable<String> paths);
}

class FirebasePhotoRepository implements PhotoRepository {
  FirebasePhotoRepository(this._storage, this._db, this.householdId);

  final FirebaseStorage _storage;
  final FirebaseFirestore _db;
  final String householdId;

  DocumentReference<Map<String, dynamic>> _recipe(String id) =>
      _db.collection('households/$householdId/recipes').doc(id);

  @override
  Future<String> upload(String recipeId, String file) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'households/$householdId/recipes/$recipeId/$name';
    await _storage
        .ref(path)
        .putFile(File(file), SettableMetadata(contentType: 'image/jpeg'));
    await _recipe(recipeId).update({
      'photoPaths': FieldValue.arrayUnion([path]),
    });
    return path;
  }

  @override
  Future<void> remove(String recipeId, String path) async {
    await _recipe(recipeId).update({
      'photoPaths': FieldValue.arrayRemove([path]),
    });
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final p in paths) {
      try {
        await _storage.ref(p).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
  }

  @override
  Future<String> downloadUrl(String path) =>
      _storage.ref(path).getDownloadURL();
}
