import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../recipes/domain/nutrition.dart';
import '../domain/recipe_draft.dart';

/// Reads a recipe from one or more images.
abstract class RecipeExtractor {
  /// Usually one draft; several when the images show several recipes.
  Future<List<RecipeDraft>> extract(List<Uint8List> jpegImages);

  /// Same for the text of a web page without recipe metadata.
  Future<List<RecipeDraft>> extractFromText(String pageText);

  /// New recipe ideas that use up the pantry. [pantry] lines like
  /// "Topfen (250 g, läuft bald ab)"; [avoid] allergens to leave out.
  Future<List<RecipeDraft>> suggestFromPantry({
    required List<String> pantry,
    String wish = '',
    List<String> avoid = const [],
    int count = 3,
  });

  /// Rough nutrition per serving for a recipe given as text.
  Future<Nutrition> estimateNutrition(String recipeText);
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
- Die Bilder kommen in Seitenreihenfolge. Geht ein Rezept über mehrere Bilder (z. B. Zutaten auf Seite 1, Zubereitung auf Seite 2, oder "Fortsetzung"), ist das EIN Rezept: Zutaten und Schritte in Reihenfolge zusammenführen, Titel von der ersten Seite.
- Stehen dagegen mehrere verschiedene Rezepte auf den Bildern, jedes als eigenen Eintrag in recipes; Zutaten und Schritte nie zwischen Rezepten vermischen.
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
  Future<List<RecipeDraft>> extract(List<Uint8List> jpegImages) => _run(
    (ai, name) => _extractWith(ai, name, [
      const TextPart(_prompt),
      for (final img in jpegImages) InlineDataPart('image/jpeg', img),
    ]),
  );

  @override
  Future<List<RecipeDraft>> extractFromText(String pageText) => _run(
    (ai, name) => _extractWith(ai, name, [
      const TextPart(
        '$_prompt\n- Die Quelle ist der Text einer Webseite; Werbung, '
        'Kommentare und Nährwerte ignorieren.',
      ),
      TextPart(pageText),
    ]),
  );

  @override
  Future<List<RecipeDraft>> suggestFromPantry({
    required List<String> pantry,
    String wish = '',
    List<String> avoid = const [],
    int count = 3,
  }) => _run(
    (ai, name) => _extractWith(ai, name, [
      TextPart('''
Schlage $count unterschiedliche, alltagstaugliche Rezepte vor, die möglichst viel aus diesem Vorrat verbrauchen – was bald abläuft zuerst. Österreichische Hausmannskost ist willkommen, aber kein Muss.
Gib NUR JSON nach dem Schema zurück. Regeln:
- Salz, Pfeffer, Öl, Wasser, Zucker und Mehl darf man voraussetzen; sonst möglichst wenig Zutaten, die nicht im Vorrat sind.
- Mengen für 4 Portionen (servings = 4), amount als Zahl, unit kurz (g, kg, ml, l, EL, TL, Prise, Pkg., Stk.), name ohne Menge, Zusätze in note.
- Österreichische Begriffe verwenden (Topfen, Schlagobers, Paradeiser, Erdäpfel …).
- steps: konkrete Arbeitsschritte mit Zeiten (z. B. "10 Minuten köcheln"), ohne Nummerierung.
- prepMinutes und cookMinutes schätzen.
${wish.trim().isEmpty ? '' : '- Wunsch: ${wish.trim()}\n'}${avoid.isEmpty ? '' : '- Keine Zutaten mit diesen Allergenen: ${avoid.join(', ')}\n'}
Vorrat:
${pantry.map((p) => '- $p').join('\n')}'''),
    ], temperature: 0.9),
  );

  static final _nutritionSchema = Schema.object(
    properties: {
      'kcal': Schema.number(),
      'protein': Schema.number(),
      'fat': Schema.number(),
      'carbs': Schema.number(),
    },
  );

  @override
  Future<Nutrition> estimateNutrition(String recipeText) =>
      _run((ai, name) async {
        final model = ai.generativeModel(
          model: name,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _nutritionSchema,
            temperature: 0,
          ),
        );
        final response = await model
            .generateContent([
              Content.text('''
Schätze die Nährwerte PRO PORTION für dieses Rezept anhand üblicher Nährwerttabellen. Fehlen Mengen, nimm übliche Mengen an.
Gib NUR JSON zurück: kcal (Kilokalorien), protein, fat, carbs (jeweils Gramm).

$recipeText'''),
            ])
            .timeout(const Duration(seconds: 60));
        final n = Nutrition.fromMap(
          (jsonDecode(response.text ?? '') as Map).cast<String, dynamic>(),
        );
        if (n == null) throw const FormatException('No nutrition values');
        return n;
      });

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

  /// Runs [call] with the first backend and model that works.
  Future<T> _run<T>(
    Future<T> Function(FirebaseAI ai, String model) call,
  ) async {
    final candidates = {modelName, ...fallbackModels}.toList();
    final attempts = <String>[];
    for (final (label, backend) in backends) {
      for (final name in candidates) {
        try {
          return await call(backend(), name);
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
    List<Part> parts, {
    double temperature = 0,
  }) async {
    final model = ai.generativeModel(
      model: name,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _schema,
        temperature: temperature,
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
