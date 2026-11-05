import 'dart:convert';

import '../../../core/units/ingredient_line_parser.dart';
import '../../../core/units/units.dart';

/// Unsaved recipe from an import. Always goes to the review screen
/// (the recipe editor) before anything is stored.
class RecipeDraft {
  const RecipeDraft({
    this.title = '',
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.ingredientLines = const [],
    this.steps = const [],
    this.notes = '',
    this.imagePaths = const [],
    this.recognizedOffline = false,
    this.aiError,
    this.position = 1,
    this.count = 1,
    this.sourceUrl,
  });

  final String title;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;

  /// One free text line per ingredient, e.g. `200 g Mehl glatt`.
  final List<String> ingredientLines;
  final List<String> steps;
  final String notes;

  /// Local image files the draft was read from.
  final List<String> imagePaths;

  /// True when the AI was not reachable and on-device OCR was used.
  final bool recognizedOffline;

  /// Why the AI could not be used (shown in the review banner).
  final String? aiError;

  /// "Rezept [position] von [count]" when one image held several recipes.
  final int position;
  final int count;

  /// Web page the recipe came from (link import).
  final String? sourceUrl;

  RecipeDraft copyWith({
    List<String>? imagePaths,
    bool? recognizedOffline,
    String? notes,
    String? aiError,
    int? position,
    int? count,
    String? sourceUrl,
  }) => RecipeDraft(
    title: title,
    servings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    ingredientLines: ingredientLines,
    steps: steps,
    notes: notes ?? this.notes,
    imagePaths: imagePaths ?? this.imagePaths,
    recognizedOffline: recognizedOffline ?? this.recognizedOffline,
    aiError: aiError ?? this.aiError,
    position: position ?? this.position,
    count: count ?? this.count,
    sourceUrl: sourceUrl ?? this.sourceUrl,
  );
}

/// For the import queue on the phone (JSON).
extension RecipeDraftJson on RecipeDraft {
  Map<String, dynamic> toJson() => {
    'title': title,
    'servings': ?servings,
    'prepMinutes': ?prepMinutes,
    'cookMinutes': ?cookMinutes,
    'ingredientLines': ingredientLines,
    'steps': steps,
    'notes': notes,
    'imagePaths': imagePaths,
    'recognizedOffline': recognizedOffline,
    'aiError': ?aiError,
    'sourceUrl': ?sourceUrl,
  };

  static RecipeDraft fromJson(Map<String, dynamic> m) => RecipeDraft(
    title: m['title'] as String? ?? '',
    servings: m['servings'] as int?,
    prepMinutes: m['prepMinutes'] as int?,
    cookMinutes: m['cookMinutes'] as int?,
    ingredientLines: [...?(m['ingredientLines'] as List?)?.cast<String>()],
    steps: [...?(m['steps'] as List?)?.cast<String>()],
    notes: m['notes'] as String? ?? '',
    imagePaths: [...?(m['imagePaths'] as List?)?.cast<String>()],
    recognizedOffline: m['recognizedOffline'] as bool? ?? false,
    aiError: m['aiError'] as String?,
    sourceUrl: m['sourceUrl'] as String?,
  );
}

class InvalidDraftException implements Exception {
  InvalidDraftException(this.message);
  final String message;
  @override
  String toString() => 'InvalidDraftException: $message';
}

int? _int(Object? v) => switch (v) {
  final int i => i,
  final double d => d.round(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

double? _double(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => parseNumber(s),
  _ => null,
};

/// Validates the AI answer against the fixed schema
/// `{recipes: [{title, servings, prepMinutes?, cookMinutes?,
///   ingredients: [{amount?, unit?, name, note?}], steps: [string]}]}`.
/// A single recipe object without `recipes` is accepted too. Invalid
/// entries are skipped; throws [InvalidDraftException] if none is valid.
List<RecipeDraft> draftsFromAiJson(String raw) {
  var text = raw.trim();
  // Tolerate ```json fences.
  final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(text);
  if (fence != null) text = fence[1]!;
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw InvalidDraftException('not JSON: ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw InvalidDraftException('not an object');
  }
  final list = decoded['recipes'];
  final maps = list is List ? list : [decoded];
  final drafts = <RecipeDraft>[];
  InvalidDraftException? firstError;
  for (final m in maps) {
    try {
      if (m is! Map<String, dynamic>) {
        throw InvalidDraftException('recipe is not an object');
      }
      drafts.add(_draftFromMap(m));
    } on InvalidDraftException catch (e) {
      firstError ??= e;
    }
  }
  if (drafts.isEmpty) {
    throw firstError ?? InvalidDraftException('no recipes');
  }
  return [
    for (final (i, d) in drafts.indexed)
      d.copyWith(position: i + 1, count: drafts.length),
  ];
}

RecipeDraft _draftFromMap(Map<String, dynamic> decoded) {
  final title = decoded['title'];
  if (title is! String || title.trim().isEmpty) {
    throw InvalidDraftException('title missing');
  }
  final ingredients = decoded['ingredients'];
  final steps = decoded['steps'];
  if (ingredients is! List || steps is! List) {
    throw InvalidDraftException('ingredients or steps missing');
  }

  final lines = <String>[];
  for (final i in ingredients) {
    if (i is! Map) throw InvalidDraftException('ingredient is not an object');
    final name = i['name'];
    if (name is! String || name.trim().isEmpty) {
      throw InvalidDraftException('ingredient without name');
    }
    final amount = _double(i['amount']);
    final rawUnit = i['unit'];
    final unit = rawUnit is String && rawUnit.trim().isNotEmpty
        ? (Units.canonical(rawUnit) ?? rawUnit.trim())
        : null;
    final note = i['note'];
    final qty = formatWithUnit(
      amount,
      unit,
    ).replaceAll('½', '1/2').replaceAll('¼', '1/4').replaceAll('¾', '3/4');
    lines.add(
      [
        [if (qty.isNotEmpty) qty, name.trim()].join(' '),
        if (note is String && note.trim().isNotEmpty) note.trim(),
      ].join(', '),
    );
  }

  return RecipeDraft(
    title: title.trim(),
    servings: _int(decoded['servings']),
    prepMinutes: _int(decoded['prepMinutes']),
    cookMinutes: _int(decoded['cookMinutes']),
    ingredientLines: lines,
    steps: [
      for (final s in steps)
        if (s is String && s.trim().isNotEmpty) s.trim(),
    ],
  );
}

final _ingredientsHeader = RegExp(
  r'^(zutaten|einkaufsliste|du brauchst|ihr braucht|man braucht)\b.*$',
  caseSensitive: false,
);
final _stepsHeader = RegExp(
  r'^(zubereitung|anleitung|so geht.s|schritte|arbeitsschritte|zubereitungsschritte|und so wird.s gemacht)\b.*$',
  caseSensitive: false,
);
final _subHeader = RegExp(
  r'^(für|fuer|außerdem|ausserdem)\b.*:$',
  caseSensitive: false,
);
final _servings = RegExp(
  r'(\d+)\s*(portionen|personen|pers\.|stück|stk\.?)',
  caseSensitive: false,
);
final _numberedStep = RegExp(r'^(\d+)[.)]\s+');

bool _looksLikeIngredient(String line) {
  final p = parseIngredientLine(line);
  if (p.amount != null && p.name.split(' ').length <= 6) return true;
  if (p.unit != null) return true;
  return false;
}

/// Turns plain OCR text into a draft with simple heuristics. The user
/// reviews everything afterwards, so this only needs to get close.
RecipeDraft draftFromOcrText(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  String title = '';
  int? servings;
  final ingredients = <String>[];
  final stepLines = <String>[];
  var mode = 'start'; // start | ingredients | steps

  for (final line in lines) {
    final s = _servings.firstMatch(line);
    if (servings == null && s != null && line.length < 40) {
      servings = int.tryParse(s[1]!);
      if (mode == 'start' && title.isNotEmpty) continue;
    }
    if (_ingredientsHeader.hasMatch(line) && line.length < 40) {
      mode = 'ingredients';
      continue;
    }
    if (_stepsHeader.hasMatch(line) && line.length < 40) {
      mode = 'steps';
      continue;
    }
    switch (mode) {
      case 'start':
        if (_looksLikeIngredient(line)) {
          mode = 'ingredients';
          ingredients.add(line);
        } else if (title.isEmpty) {
          title = line;
        }
      case 'ingredients':
        if (_subHeader.hasMatch(line)) continue;
        // A long sentence after the ingredient list starts the steps.
        if (!_looksLikeIngredient(line) &&
            line.length > 45 &&
            ingredients.isNotEmpty) {
          mode = 'steps';
          stepLines.add(line);
        } else {
          ingredients.add(line);
        }
      case 'steps':
        stepLines.add(line);
    }
  }

  // OCR breaks sentences across lines: join until a sentence ends or a
  // numbered step begins.
  final steps = <String>[];
  var current = '';
  for (final line in stepLines) {
    final numbered = _numberedStep.hasMatch(line);
    final clean = line.replaceFirst(_numberedStep, '');
    if (numbered && current.isNotEmpty) {
      steps.add(current);
      current = '';
    }
    current = current.isEmpty ? clean : '$current $clean';
    if (RegExp(r'[.!]$').hasMatch(clean)) {
      steps.add(current);
      current = '';
    }
  }
  if (current.isNotEmpty) steps.add(current);

  return RecipeDraft(
    title: title,
    servings: servings,
    ingredientLines: ingredients,
    steps: steps,
  );
}
