import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/import/data/recipe_extractor.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';

import '../../helpers/fakes.dart';

void main() {
  test('uses the AI result when available', () async {
    final s = fakeImportService(aiResult: const RecipeDraft(title: 'Strudel'));
    final d = (await s.import(['/a.jpg', '/b.jpg'])).single;
    expect(d.title, 'Strudel');
    expect(d.imagePaths, ['/a.jpg', '/b.jpg']);
    expect(d.recognizedOffline, isFalse);
  });

  test('falls back to on-device OCR when the AI fails', () async {
    final s = fakeImportService(ocrText: 'Gulasch\n500 g Rindfleisch');
    final d = (await s.import(['/a.jpg'])).single;
    expect(d.title, 'Gulasch');
    expect(d.ingredientLines, ['500 g Rindfleisch']);
    expect(d.recognizedOffline, isTrue);
  });

  test('the AI error reason is kept for the banner', () async {
    final s = fakeImportService(ocrText: 'X');
    final d = (await s.import(['/a.jpg'])).single;
    expect(d.aiError, contains('offline'));
  });

  test('unknown model errors are recognized for the fallback chain', () {
    expect(
      GeminiRecipeExtractor.isUnknownModel(
        Exception('models/gemini-x is not found for API version v1beta'),
      ),
      isTrue,
    );
    expect(
      GeminiRecipeExtractor.isUnknownModel(Exception('API key not valid')),
      isFalse,
    );
  });

  test('setup errors switch to the other Gemini backend', () {
    expect(
      GeminiRecipeExtractor.isBackendSetupError(
        Exception('Firebase AI Logic genai config not found. Learn more'),
      ),
      isTrue,
    );
    expect(
      GeminiRecipeExtractor.isBackendSetupError(Exception('quota exceeded')),
      isFalse,
    );
  });
}
