import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for recipe photos, keyed by Storage path. Photos never change
/// (every upload gets a new name), so a cached file is used without asking
/// the server again; not even the download URL is fetched.
abstract class PhotoCache {
  Future<File?> cached(String path);
  Future<File> download(String path, String url);
  Future<void> put(String path, String localFile);
}

class CacheManagerPhotoCache implements PhotoCache {
  static final _manager = CacheManager(
    Config(
      'recipePhotos',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1000,
    ),
  );

  @override
  Future<File?> cached(String path) async =>
      (await _manager.getFileFromCache(path))?.file;

  @override
  Future<File> download(String path, String url) async =>
      (await _manager.downloadFile(url, key: path)).file;

  @override
  Future<void> put(String path, String localFile) async {
    final bytes = await File(localFile).readAsBytes();
    await _manager.putFile(
      path,
      bytes,
      key: path,
      maxAge: const Duration(days: 365),
      fileExtension: 'jpg',
    );
  }
}
