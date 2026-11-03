import 'dart:io';
import 'dart:typed_data';

import '../../../core/firebase/fire.dart';
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

  Future<List<RecipeDraft>> import(List<String> imagePaths) async {
    try {
      final images = [for (final p in imagePaths) await readBytes(p)];
      final drafts = await extractor.extract(images);
      return [for (final d in drafts) d.copyWith(imagePaths: imagePaths)];
    } catch (e, s) {
      reportError(e, s);
      final texts = [for (final p in imagePaths) await ocr.recognize(p)];
      return [
        draftFromOcrText(texts.join('\n')).copyWith(
          imagePaths: imagePaths,
          recognizedOffline: true,
          aiError: describeAiError(e),
        ),
      ];
    }
  }
}

/// Short, readable reason for the review banner.
String describeAiError(Object e) {
  final text = e.toString().replaceFirst(RegExp(r'^\w*Exception:?\s*'), '');
  return text.length > 200 ? '${text.substring(0, 200)}…' : text;
}
