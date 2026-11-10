import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'recipe_draft.dart';

/// Recipes from the `schema.org/Recipe` JSON-LD that almost every recipe
/// site embeds. Empty when the page has none (then the AI reads the text).
List<RecipeDraft> draftsFromJsonLd(String html, {String? sourceUrl}) {
  final doc = html_parser.parse(html);
  final drafts = <RecipeDraft>[];
  for (final script in doc.querySelectorAll(
    'script[type="application/ld+json"]',
  )) {
    Object? data;
    try {
      data = jsonDecode(script.text.trim());
    } on FormatException {
      continue;
    }
    for (final r in _findRecipes(data)) {
      final d = _draftFromSchema(r, sourceUrl);
      if (d != null) drafts.add(d);
    }
  }
  return [
    for (final (i, d) in drafts.indexed)
      d.copyWith(position: i + 1, count: drafts.length),
  ];
}

Iterable<Map<String, dynamic>> _findRecipes(Object? node) sync* {
  if (node is List) {
    for (final n in node) {
      yield* _findRecipes(n);
    }
  } else if (node is Map<String, dynamic>) {
    final type = node['@type'];
    final isRecipe =
        type == 'Recipe' || (type is List && type.contains('Recipe'));
    if (isRecipe) {
      yield node;
    } else {
      yield* _findRecipes(node['@graph']);
      yield* _findRecipes(node['mainEntity']);
    }
  }
}

RecipeDraft? _draftFromSchema(Map<String, dynamic> r, String? sourceUrl) {
  final title = cleanText(r['name']);
  if (title.isEmpty) return null;
  final ingredients = [
    for (final i in _list(r['recipeIngredient'] ?? r['ingredients']))
      if (cleanText(i).isNotEmpty) cleanText(i),
  ];
  return RecipeDraft(
    title: title,
    servings: parseYield(r['recipeYield']),
    prepMinutes: parseIsoMinutes(r['prepTime']),
    cookMinutes: parseIsoMinutes(r['cookTime']),
    ingredientLines: ingredients,
    steps: _steps(r['recipeInstructions']),
    sourceUrl: sourceUrl,
  );
}

List<Object?> _list(Object? v) => v is List ? v : (v == null ? [] : [v]);

List<String> _steps(Object? v) {
  final out = <String>[];
  void walk(Object? n) {
    if (n is String) {
      // Some sites put all steps in one string with line breaks.
      for (final line in cleanText(n, keepLines: true).split('\n')) {
        if (line.trim().isNotEmpty) out.add(line.trim());
      }
    } else if (n is List) {
      n.forEach(walk);
    } else if (n is Map) {
      if (n['itemListElement'] != null) {
        walk(n['itemListElement']);
      } else {
        final text = cleanText(n['text'] ?? n['name']);
        if (text.isNotEmpty) out.add(text);
      }
    }
  }

  walk(v);
  return out;
}

/// "PT1H30M" -> 90. Null for missing or zero durations.
int? parseIsoMinutes(Object? v) {
  if (v is! String) return null;
  final m = RegExp(
    r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    caseSensitive: false,
  ).firstMatch(v.trim());
  if (m == null) return null;
  final minutes =
      int.parse(m[1] ?? '0') * 1440 +
      int.parse(m[2] ?? '0') * 60 +
      int.parse(m[3] ?? '0');
  return minutes == 0 ? null : minutes;
}

/// "4", 4, ["4", "4 Portionen"], "4 Stück" -> 4.
int? parseYield(Object? v) {
  for (final item in _list(v)) {
    if (item is num) return item.round();
    if (item is String) {
      final m = RegExp(r'\d+').firstMatch(item);
      if (m != null) return int.parse(m[0]!);
    }
  }
  return null;
}

/// Strips HTML tags and entities that sites leave in JSON-LD strings.
String cleanText(Object? v, {bool keepLines = false}) {
  if (v is! String) return '';
  var s = v;
  s = s.replaceAll(
    RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false),
    keepLines ? '\n' : ' ',
  );
  final text = html_parser.parseFragment(s).text ?? '';
  return keepLines
      ? text
            .split('\n')
            .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
            .join('\n')
      : text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Readable page text for the AI fallback (no scripts, menus or footers).
String pageText(String html, {int maxChars = 30000}) {
  final doc = html_parser.parse(html);
  for (final tag in [
    'script',
    'style',
    'noscript',
    'nav',
    'footer',
    'header',
    'aside',
    'form',
  ]) {
    for (final Element e in doc.querySelectorAll(tag)) {
      e.remove();
    }
  }
  final root =
      doc.querySelector('article') ?? doc.querySelector('main') ?? doc.body;
  final text = (root?.text ?? '')
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
  return text.length > maxChars ? text.substring(0, maxChars) : text;
}

/// First http(s) URL in a shared text ("Schau dir das an: https://…").
/// Shared text that is a recipe itself (e.g. a ChatGPT answer) rather
/// than a link with a few words around it.
bool isRecipeText(String text) {
  final rest = text.replaceAll(RegExp(r'https?://[^\s<>"]+'), '').trim();
  final lines = rest.split('\n').where((l) => l.trim().isNotEmpty);
  return rest.length >= 80 && lines.length >= 3;
}

Uri? findUrl(String text) {
  final m = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
  if (m == null) return null;
  final raw = m[0]!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
  return Uri.tryParse(raw);
}
