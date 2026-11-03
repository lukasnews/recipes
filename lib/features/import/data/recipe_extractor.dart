import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../domain/recipe_draft.dart';

/// Reads a recipe from one or more images.
abstract class RecipeExtractor {
  Future<RecipeDraft> extract(List<Uint8List> jpegImages);
}

/// Gemini via Firebase AI Logic. Handles print, handwriting and screenshots.
class GeminiRecipeExtractor implements RecipeExtractor {
  GeminiRecipeExtractor(this.modelName);

  final String modelName;

  static const _prompt = '''
Du liest ein Rezept aus den Bildern (Foto, Screenshot oder Handschrift, eventuell über mehrere Seiten).
Gib NUR JSON nach dem Schema zurück. Regeln:
- Texte auf Deutsch so übernehmen, wie sie dastehen (österreichische Begriffe nicht übersetzen).
- ingredients: jede Zutat einzeln; amount als Zahl (½ = 0.5), unit kurz (g, kg, dag, ml, l, EL, TL, Prise, Msp., Pkg., Becher, Dose, Bund, Zehe, Stk.), name ohne Menge, Zusätze wie "weich" oder "gehackt" in note.
- Zwischenüberschriften wie "Für den Teig" weglassen.
- steps: ein Eintrag pro Arbeitsschritt, ohne Nummerierung.
- servings: Anzahl Portionen, falls angegeben.
- Nichts erfinden, was nicht auf den Bildern steht.''';

  static final _schema = Schema.object(
    properties: {
      'title': Schema.string(),
      'servings': Schema.integer(),
      'prepMinutes': Schema.integer(),
      'cookMinutes': Schema.integer(),
      'ingredients': Schema.array(
        items: Schema.object(
          properties: {
            'amount': Schema.number(),
            'unit': Schema.string(),
            'name': Schema.string(),
            'note': Schema.string(),
          },
          optionalProperties: ['amount', 'unit', 'note'],
        ),
      ),
      'steps': Schema.array(items: Schema.string()),
    },
    optionalProperties: ['servings', 'prepMinutes', 'cookMinutes'],
  );

  @override
  Future<RecipeDraft> extract(List<Uint8List> jpegImages) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
        temperature: 0,
      ),
    );
    final content = Content.multi([
      const TextPart(_prompt),
      for (final img in jpegImages) InlineDataPart('image/jpeg', img),
    ]);

    String? lastText;
    // Validate against the schema; ask once more if it doesn't fit.
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await model
          .generateContent([content])
          .timeout(const Duration(seconds: 90));
      lastText = response.text;
      if (lastText == null) continue;
      try {
        return draftFromAiJson(lastText);
      } on InvalidDraftException {
        continue;
      }
    }
    // Still invalid: show the raw text in the review screen.
    final fallback = draftFromOcrText(lastText ?? '');
    return fallback.copyWith(notes: lastText ?? '');
  }
}
