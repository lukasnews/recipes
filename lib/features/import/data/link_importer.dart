import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/recipe_draft.dart';
import '../domain/web_recipe.dart';
import 'recipe_extractor.dart';

class LinkImportException implements Exception {
  LinkImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Link import: JSON-LD `schema.org/Recipe` first, the AI on the page text
/// only when that is missing. Needs a connection.
class LinkImporter {
  LinkImporter({required this.extractor, http.Client? client})
    : _client = client ?? http.Client();

  final RecipeExtractor extractor;
  final http.Client _client;

  Future<List<RecipeDraft>> import(Uri url) async {
    final response = await _client
        .get(
          url,
          headers: const {
            // Some sites only serve full pages to browser-like clients.
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/130.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'de-AT,de;q=0.9',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      throw LinkImportException('HTTP ${response.statusCode}');
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final source = url.toString();

    final fromJsonLd = draftsFromJsonLd(html, sourceUrl: source);
    if (fromJsonLd.isNotEmpty) return fromJsonLd;

    final text = pageText(html);
    if (text.isEmpty) throw LinkImportException('Seite ist leer');
    final drafts = await extractor.extractFromText(text);
    return [for (final d in drafts) d.copyWith(sourceUrl: source)];
  }
}
