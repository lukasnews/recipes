import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/recipe_draft.dart';

/// Reads a recipe from one or more images.
abstract class RecipeExtractor {
  /// Usually one draft; several when the images show several recipes.
  Future<List<RecipeDraft>> extract(List<Uint8List> jpegImages);

  /// Same for the text of a web page without recipe metadata.
  Future<List<RecipeDraft>> extractFromText(String pageText);
}

/// Gemini via Firebase AI Logic. Handles print, handwriting and screenshots.
class GeminiRecipeExtractor implements RecipeExtractor {
  GeminiRecipeExtractor(this.modelName);

  /// From Remote Config `ai_model`.
  final String modelName;

  /// Tried in order when a model name is unknown or retired, so an old
  /// default never breaks the import. Remote Config stays the first choice.
  static const fallbackModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3-flash-preview',
    'gemini-flash-latest',
    'gemini-2.5-flash',
  ];

  static bool isUnknownModel(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('not found') ||
        m.contains('is not supported') ||
        m.contains('404') ||
        m.contains('unknown model') ||
        m.contains('deprecated') ||
        m.contains('does not have access');
  }

  static const _prompt = '''
Du liest ein Rezept aus den Bildern (Foto, Screenshot oder Handschrift, eventuell über mehrere Seiten).
Gib NUR JSON nach dem Schema zurück. Regeln:
- Texte auf Deutsch so übernehmen, wie sie dastehen (österreichische Begriffe nicht übersetzen).
- ingredients: jede Zutat einzeln; amount als Zahl (½ = 0.5), unit kurz (g, kg, dag, ml, l, EL, TL, Prise, Msp., Pkg., Becher, Dose, Bund, Zehe, Stk.), name ohne Menge, Zusätze wie "weich" oder "gehackt" in note.
- Zwischenüberschriften wie "Für den Teig" weglassen.
- steps: ein Eintrag pro Arbeitsschritt, ohne Nummerierung.
- servings: Anzahl Portionen, falls angegeben.
- Stehen mehrere Rezepte auf den Bildern, jedes als eigenen Eintrag in recipes; Zutaten und Schritte nie zwischen Rezepten vermischen.
- Nichts erfinden, was nicht auf den Bildern steht.''';

  static final _recipeSchema = Schema.object(
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

  static final _schema = Schema.object(
    properties: {'recipes': Schema.array(items: _recipeSchema)},
  );

  @override
  Future<List<RecipeDraft>> extract(List<Uint8List> jpegImages) => _run([
    const TextPart(_prompt),
    for (final img in jpegImages) InlineDataPart('image/jpeg', img),
  ]);

  @override
  Future<List<RecipeDraft>> extractFromText(String pageText) => _run([
    const TextPart(
      '$_prompt\n- Die Quelle ist der Text einer Webseite; Werbung, '
      'Kommentare und Nährwerte ignorieren.',
    ),
    TextPart(pageText),
  ]);

  /// Backends in order: Gemini Developer API first, then the Agent Platform
  /// (Vertex) Gemini API. If the first one isn't set up in the Firebase
  /// project ("genai config not found", missing API key) the second is used.
  static List<(String, FirebaseAI Function())> backends = [
    ('Developer API', FirebaseAI.googleAI),
    ('Agent Platform', FirebaseAI.agentPlatform),
  ];

  static bool isBackendSetupError(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('genai config') ||
        m.contains('api key') ||
        m.contains('api_key') ||
        m.contains('not been used in project') ||
        m.contains('is disabled') ||
        m.contains('servicedisabled') ||
        // Billing/quota of one backend (e.g. empty AI Studio prepay credits
        // for the Developer API) doesn't affect the other one (Blaze).
        m.contains('prepayment') ||
        m.contains('credits') ||
        m.contains('billing') ||
        m.contains('quota') ||
        m.contains('resource_exhausted') ||
        m.contains('resource exhausted');
  }

  Future<List<RecipeDraft>> _run(List<Part> parts) async {
    final candidates = {modelName, ...fallbackModels}.toList();
    final attempts = <String>[];
    for (final (label, backend) in backends) {
      for (final name in candidates) {
        try {
          return await _extractWith(backend(), name, parts);
        } catch (e) {
          if (isUnknownModel(e)) {
            attempts.add('$label/$name: ${_short(e)}');
            continue;
          }
          if (isBackendSetupError(e)) {
            attempts.add('$label: ${_short(e)}');
            break;
          }
          rethrow;
        }
      }
    }
    String? project;
    try {
      project = Firebase.app().options.projectId;
    } catch (_) {}
    throw AiUnavailableException(attempts, project: project);
  }

  static String _short(Object e) {
    final t = e
        .toString()
        .replaceFirst(RegExp(r'^\w*Exception:?\s*'), '')
        .replaceFirst(RegExp(r'\s*Learn more:.*$', dotAll: true), '');
    return t.length > 120 ? '${t.substring(0, 120)}…' : t;
  }

  Future<List<RecipeDraft>> _extractWith(
    FirebaseAI ai,
    String name,
    List<Part> parts,
  ) async {
    final model = ai.generativeModel(
      model: name,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
        temperature: 0,
      ),
    );
    final content = Content.multi(parts);

    String? lastText;
    // Validate against the schema; ask once more if it doesn't fit.
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await model
          .generateContent([content])
          .timeout(const Duration(seconds: 90));
      lastText = response.text;
      if (lastText == null) continue;
      try {
        return draftsFromAiJson(lastText);
      } on InvalidDraftException {
        continue;
      }
    }
    // Still invalid: show the raw text in the review screen.
    final fallback = draftFromOcrText(lastText ?? '');
    return [fallback.copyWith(notes: lastText ?? '')];
  }
}

/// No AI backend worked; lists every attempt for the review banner.
class AiUnavailableException implements Exception {
  AiUnavailableException(this.attempts, {this.project});

  final List<String> attempts;
  final String? project;

  @override
  String toString() => [
    ...attempts,
    if (project != null) 'Firebase-Projekt: $project',
  ].join('\n');
}
