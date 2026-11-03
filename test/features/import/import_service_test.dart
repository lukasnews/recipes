import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';

import '../../helpers/fakes.dart';

void main() {
  test('uses the AI result when available', () async {
    final s = fakeImportService(aiResult: const RecipeDraft(title: 'Strudel'));
    final d = await s.import(['/a.jpg', '/b.jpg']);
    expect(d.title, 'Strudel');
    expect(d.imagePaths, ['/a.jpg', '/b.jpg']);
    expect(d.recognizedOffline, isFalse);
  });

  test('falls back to on-device OCR when the AI fails', () async {
    final s = fakeImportService(ocrText: 'Gulasch\n500 g Rindfleisch');
    final d = await s.import(['/a.jpg']);
    expect(d.title, 'Gulasch');
    expect(d.ingredientLines, ['500 g Rindfleisch']);
    expect(d.recognizedOffline, isTrue);
  });
}
