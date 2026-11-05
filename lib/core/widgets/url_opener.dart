import 'package:url_launcher/url_launcher.dart';

/// Opens web pages in the browser. Behind an interface for tests.
abstract interface class UrlOpener {
  Future<bool> open(Uri url);
}

class BrowserUrlOpener implements UrlOpener {
  const BrowserUrlOpener();

  @override
  Future<bool> open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Public pages (GitHub Pages of the repo).
abstract final class Links {
  static final privacy = Uri.parse(
    'https://lukasnews.github.io/recipes/datenschutz.html',
  );
  static final deleteAccount = Uri.parse(
    'https://lukasnews.github.io/recipes/konto-loeschen.html',
  );

  /// Web page of a recipe sent to another household (works without the
  /// app; offers "In BaCo öffnen").
  static Uri sharedRecipe(String code) =>
      Uri.parse('https://lukasnews.github.io/recipes/r/?c=$code');
}
