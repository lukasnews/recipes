import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/map_utils.dart';
import '../../import/domain/recipe_draft.dart';
import '../../recipes/domain/recipe.dart';

/// Letters and digits that can't be mixed up (no 0/O, 1/I/L).
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Random 8-character code, e.g. "K7MQX4PA" (31^8 ≈ 850 billion).
String newShareCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(8, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

/// "K7MQX4PA" -> "K7MQ-X4PA" for reading out or typing.
String formatShareCode(String code) =>
    code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

/// Accepts what people type or paste: "k7mq-x4pa", a whole link, spaces.
/// Null if no 8-character code is in it.
String? parseShareCode(String input) {
  final fromLink = Uri.tryParse(input.trim())?.queryParameters['c'];
  final cleaned = (fromLink ?? input).toUpperCase().replaceAll(
    RegExp('[^A-Z0-9]'),
    '',
  );
  if (cleaned.length != 8) return null;
  if (cleaned.split('').any((c) => !_alphabet.contains(c))) return null;
  return cleaned;
}

/// The code in a link to a sent recipe's web page
/// (https://lukasnews.github.io/recipes/r/?c=CODE), else null.
String? sharedRecipeCode(Uri url) {
  if (url.host != 'lukasnews.github.io' || !url.path.startsWith('/recipes/r')) {
    return null;
  }
  return parseShareCode(url.queryParameters['c'] ?? '');
}

/// How long a sent recipe stays readable.
enum ShareValidity {
  never(null),
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  year(Duration(days: 365));

  const ShareValidity(this.duration);

  final Duration? duration;
}

/// A copy of a recipe sent to another household ("Das musst du probieren").
/// Lives at sharedRecipes/{code}, independent of the sender's household.
class SharedRecipe {
  const SharedRecipe({
    required this.code,
    required this.title,
    required this.createdBy,
    this.senderName = '',
    this.message = '',
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.ingredientLines = const [],
    this.steps = const [],
    this.photoPath,
    this.createdAt,
    this.expiresAt,
  });

  /// The copy to send: ingredient lines as shown in the recipe (the
  /// receiver's own ingredients are matched on import), steps as text.
  factory SharedRecipe.fromRecipe(
    Recipe recipe, {
    required String code,
    required String uid,
    required String senderName,
    String message = '',
    ShareValidity validity = ShareValidity.never,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return SharedRecipe(
      code: code,
      title: recipe.title,
      createdBy: uid,
      senderName: senderName,
      message: message.trim(),
      servings: recipe.servings,
      prepMinutes: recipe.prepMinutes,
      cookMinutes: recipe.cookMinutes,
      ingredientLines: [
        for (final i in recipe.ingredients)
          if (i.rawText.trim().isNotEmpty) i.rawText.trim(),
      ],
      steps: [
        for (final s in recipe.steps)
          if (s.text.trim().isNotEmpty) s.text.trim(),
      ],
      createdAt: at,
      expiresAt: validity.duration == null ? null : at.add(validity.duration!),
    );
  }

  factory SharedRecipe.fromMap(String code, Map<String, dynamic> m) =>
      SharedRecipe(
        code: code,
        title: m.str('title'),
        createdBy: m.str('createdBy'),
        senderName: m.str('senderName'),
        message: m.str('message'),
        servings: m.integer('servings'),
        prepMinutes: m.integer('prepMinutes'),
        cookMinutes: m.integer('cookMinutes'),
        ingredientLines: m.strings('ingredients'),
        steps: m.strings('steps'),
        photoPath: m.strOrNull('photoPath'),
        createdAt: m.date('createdAt'),
        expiresAt: m.date('expiresAt'),
      );

  final String code;
  final String title;
  final String createdBy;
  final String senderName;
  final String message;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final List<String> ingredientLines;
  final List<String> steps;

  /// Storage path under shared/{uid}/, readable by anyone with the link.
  final String? photoPath;
  final DateTime? createdAt;

  /// Null = never expires.
  final DateTime? expiresAt;

  bool isExpired(DateTime now) => expiresAt != null && expiresAt!.isBefore(now);

  Map<String, dynamic> toMap() => {
    'title': title,
    'createdBy': createdBy,
    'senderName': senderName,
    'message': message,
    'servings': ?servings,
    'prepMinutes': ?prepMinutes,
    'cookMinutes': ?cookMinutes,
    'ingredients': ingredientLines,
    'steps': steps,
    'photoPath': ?photoPath,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
    'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
  };

  /// Opens in the review screen like any import; [notes] says who sent it.
  RecipeDraft toDraft({
    required String notes,
    List<String> imagePaths = const [],
  }) => RecipeDraft(
    title: title,
    servings: servings,
    prepMinutes: prepMinutes,
    cookMinutes: cookMinutes,
    ingredientLines: ingredientLines,
    steps: steps,
    notes: notes,
    imagePaths: imagePaths,
  );
}
