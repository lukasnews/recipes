import 'dart:io';
import 'dart:typed_data';

import '../domain/recipe_draft.dart';
import 'recipe_extractor.dart';
import 'text_recognizer.dart';

/// AI first; without network (or on any AI error) fall back to on-device
/// OCR so importing still works offline.
class RecipeImportService {
  RecipeImportService({
    required this.extractor,
    required this.ocr,
    this.readBytes = _readFile,
  });

  final RecipeExtractor extractor;
  final TextRecognizerService ocr;
  final Future<Uint8List> Function(String path) readBytes;

  static Future<Uint8List> _readFile(String path) => File(path).readAsBytes();

  Future<RecipeDraft> import(List<String> imagePaths) async {
    try {
      final images = [for (final p in imagePaths) await readBytes(p)];
      final draft = await extractor.extract(images);
      return draft.copyWith(imagePaths: imagePaths);
    } catch (_) {
      final texts = [for (final p in imagePaths) await ocr.recognize(p)];
      return draftFromOcrText(texts.join('\n'))
          .copyWith(imagePaths: imagePaths, recognizedOffline: true);
    }
  }
}
