import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// A TikTok video whose caption holds no recipe (it is only spoken or
/// shown in the video).
class NoRecipeInCaptionException implements Exception {
  @override
  String toString() => 'No recipe in the video caption';
}

/// Short links (vm./vt.tiktok.com) and www.tiktok.com/@user/video/….
bool isTikTok(Uri url) =>
    url.host == 'tiktok.com' || url.host.endsWith('.tiktok.com');

/// Writes a downloaded cover image to a temporary file for the review
/// screen ("Ausgangsbild auch als Rezeptfoto speichern").
Future<String?> _saveTempImage(Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('baco_link_');
  final file = File('${dir.path}/cover.jpg');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Link import: JSON-LD `schema.org/Recipe` first, the AI on the page text
/// only when that is missing. Needs a connection.
class LinkImporter {
  LinkImporter({
    required this.extractor,
    http.Client? client,
    this.saveImage = _saveTempImage,
  }) : _client = client ?? http.Client();

  final RecipeExtractor extractor;
  final http.Client _client;
  final Future<String?> Function(Uint8List bytes) saveImage;

  static const _browserHeaders = {
    // Some sites only serve full pages to browser-like clients.
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/130.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'de-AT,de;q=0.9',
  };

  Future<List<RecipeDraft>> import(Uri url) async {
    if (isTikTok(url)) return _importTikTok(url);
    final response = await _client
        .get(url, headers: _browserHeaders)
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

  /// TikTok pages are built by scripts, so the caption comes from TikTok's
  /// public oEmbed endpoint (no account, no key): caption → AI, cover image
  /// as optional photo. The video itself is not read.
  Future<List<RecipeDraft>> _importTikTok(Uri url) async {
    final full = await _resolveRedirects(url);
    final response = await _client
        .get(
          Uri.https('www.tiktok.com', '/oembed', {'url': full.toString()}),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      throw LinkImportException('TikTok: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) throw LinkImportException('TikTok: keine Daten');
    final caption = '${data['title'] ?? ''}'.trim();
    final author = '${data['author_name'] ?? ''}'.trim();
    if (caption.length < 20) throw NoRecipeInCaptionException();

    final drafts = await extractor.extractFromText(
      [if (author.isNotEmpty) 'TikTok-Video von $author', caption].join('\n'),
    );
    if (drafts.every((d) => d.ingredientLines.isEmpty)) {
      throw NoRecipeInCaptionException();
    }
    final cover = await _downloadCover('${data['thumbnail_url'] ?? ''}');
    return [
      for (final d in drafts)
        d.copyWith(
          sourceUrl: full.toString(),
          imagePaths: [?cover],
          notes: [
            if (d.notes.isNotEmpty) d.notes,
            if (author.isNotEmpty) 'TikTok: $author',
          ].join('\n'),
        ),
    ];
  }

  /// vm.tiktok.com/… → the full video address (oEmbed needs it).
  Future<Uri> _resolveRedirects(Uri url) async {
    var current = url;
    for (var i = 0; i < 5; i++) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(_browserHeaders);
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      await response.stream.drain<void>();
      final location = response.headers['location'];
      if (!response.isRedirect &&
              (response.statusCode < 300 || response.statusCode >= 400) ||
          location == null) {
        return current;
      }
      current = current.resolve(location);
    }
    return current;
  }

  Future<String?> _downloadCover(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    try {
      final r = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (r.statusCode >= 400 || r.bodyBytes.isEmpty) return null;
      return await saveImage(r.bodyBytes);
    } catch (_) {
      return null; // The recipe matters more than the picture.
    }
  }
}
