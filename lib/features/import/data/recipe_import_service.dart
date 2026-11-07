import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/firebase/fire.dart';
import '../../shopping/domain/shopping_scan.dart';
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

  /// No connection (or the connection dropped): worth trying again later.
  static bool isNetworkError(Object e) {
    if (e is SocketException || e is TimeoutException) return true;
    final m = e.toString().toLowerCase();
    return m.contains('socketexception') ||
        m.contains('failed host lookup') ||
        m.contains('network') ||
        m.contains('connection') ||
        m.contains('unavailable') ||
        m.contains('timed out') ||
        m.contains('timeout');
  }

  /// For the import queue: AI only; throws on network errors so the queue
  /// retries later. Other AI errors fall back to OCR like [import].
  Future<List<RecipeDraft>> importWhenOnline(List<String> imagePaths) async {
    try {
      final images = [for (final p in imagePaths) await readBytes(p)];
      final drafts = await extractor.extract(images);
      return [for (final d in drafts) d.copyWith(imagePaths: imagePaths)];
    } catch (e) {
      if (isNetworkError(e)) rethrow;
      return import(imagePaths);
    }
  }

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

extension ShoppingListImport on RecipeImportService {
  /// Photographed shopping list: AI first, on-device OCR as fallback
  /// (offline or AI error).
  Future<ShoppingScan> readShoppingList(List<String> imagePaths) async {
    try {
      final images = [for (final p in imagePaths) await readBytes(p)];
      final lines = await extractor.extractShoppingList(images);
      return ShoppingScan(dedupeLines(lines));
    } catch (e, s) {
      reportError(e, s);
      final texts = [for (final p in imagePaths) await ocr.recognize(p)];
      return ShoppingScan(
        shoppingLinesFromText(texts.join('\n')),
        offline: true,
        aiError: describeAiError(e),
      );
    }
  }
}

/// Short, readable reason for the review banner.
String describeAiError(Object e) {
  if (e is AiUnavailableException) return e.toString();
  final text = e.toString().replaceFirst(RegExp(r'^\w*Exception:?\s*'), '');
  return text.length > 200 ? '${text.substring(0, 200)}…' : text;
}
