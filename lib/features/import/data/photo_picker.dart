import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Picks photos already downscaled to max 1600 px edge, JPEG ~80 %.
abstract class PhotoPicker {
  Future<List<String>> pick(PhotoSource source, {bool multiple = true});
}

class ImagePickerPhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  static const maxEdge = 1600.0;
  static const quality = 80;

  @override
  Future<List<String>> pick(PhotoSource source, {bool multiple = true}) async {
    if (source == PhotoSource.camera) {
      final f = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxEdge,
        maxHeight: maxEdge,
        imageQuality: quality,
      );
      return [?f?.path];
    }
    if (!multiple) {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxEdge,
        maxHeight: maxEdge,
        imageQuality: quality,
      );
      return [?f?.path];
    }
    final files = await _picker.pickMultiImage(
      maxWidth: maxEdge,
      maxHeight: maxEdge,
      imageQuality: quality,
      limit: 6,
    );
    return files.map((f) => f.path).toList();
  }
}
