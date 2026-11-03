import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipes/features/import/data/link_importer.dart';
import 'package:recipes/features/import/domain/recipe_draft.dart';
import 'package:recipes/features/import/domain/web_recipe.dart';

import '../../helpers/fakes.dart';

const _graphPage = '''
<html><head>
<script type="application/ld+json">{"@type": "WebSite", "name": "Kochseite"}</script>
<script type="application/ld+json">
{"@context": "https://schema.org", "@graph": [
  {"@type": "BreadcrumbList"},
  {"@type": ["Recipe"], "name": "Wiener Schnitzel &amp; Erdäpfelsalat",
   "recipeYield": ["4", "4 Portionen"],
   "prepTime": "PT30M", "cookTime": "PT1H5M",
   "recipeIngredient": ["4 Kalbsschnitzel", " 2  Eier ", "<b>Semmelbrösel</b>"],
   "recipeInstructions": [
     {"@type": "HowToSection", "name": "Schnitzel", "itemListElement": [
       {"@type": "HowToStep", "text": "Schnitzel klopfen."},
       {"@type": "HowToStep", "text": "Panieren.<br>Ausbacken."}
     ]},
     "Mit Zitrone servieren."
   ]}
]}
</script></head><body>Werbung</body></html>
''';

void main() {
  group('draftsFromJsonLd', () {
    test('reads a recipe nested in @graph with sections', () {
      final d = draftsFromJsonLd(
        _graphPage,
        sourceUrl: 'https://x.at/r',
      ).single;
      expect(d.title, 'Wiener Schnitzel & Erdäpfelsalat');
      expect(d.servings, 4);
      expect(d.prepMinutes, 30);
      expect(d.cookMinutes, 65);
      expect(d.ingredientLines, ['4 Kalbsschnitzel', '2 Eier', 'Semmelbrösel']);
      expect(d.steps, [
        'Schnitzel klopfen.',
        'Panieren. Ausbacken.',
        'Mit Zitrone servieren.',
      ]);
      expect(d.sourceUrl, 'https://x.at/r');
    });

    test('instructions as one string with line breaks', () {
      final d = draftsFromJsonLd(
        '''
<script type="application/ld+json">{"@type":"Recipe","name":"Tee",
"recipeInstructions":"Wasser kochen.<br/>Tee ziehen lassen."}</script>''',
      ).single;
      expect(d.steps, ['Wasser kochen.', 'Tee ziehen lassen.']);
    });

    test('page without recipe data gives nothing', () {
      expect(draftsFromJsonLd('<html><body>Hallo</body></html>'), isEmpty);
      expect(
        draftsFromJsonLd('<script type="application/ld+json">{kaputt</script>'),
        isEmpty,
      );
    });
  });

  test('parseIsoMinutes and parseYield', () {
    expect(parseIsoMinutes('PT1H30M'), 90);
    expect(parseIsoMinutes('P0DT0H20M'), 20);
    expect(parseIsoMinutes('PT0S'), isNull);
    expect(parseIsoMinutes('20 Min'), isNull);
    expect(parseYield('6 Stück'), 6);
    expect(parseYield(2), 2);
    expect(parseYield(null), isNull);
  });

  test('findUrl picks the link out of shared text', () {
    expect(
      findUrl(
        'Schau mal: https://www.gutekueche.at/kaiserschmarrn-rezept-1234.',
      ).toString(),
      'https://www.gutekueche.at/kaiserschmarrn-rezept-1234',
    );
    expect(findUrl('kein Link'), isNull);
  });

  group('LinkImporter', () {
    test('uses JSON-LD without asking the AI', () async {
      final ai = FakeExtractor(const [], fail: true);
      final importer = LinkImporter(
        extractor: ai,
        client: MockClient(
          (_) async => http.Response(
            _graphPage,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ),
        ),
      );
      final d = (await importer.import(Uri.parse('https://x.at/r'))).single;
      expect(d.title, startsWith('Wiener Schnitzel'));
      expect(ai.lastText, isNull);
    });

    test('falls back to the AI with the page text', () async {
      final ai = FakeExtractor(const [RecipeDraft(title: 'Blog-Kuchen')]);
      final importer = LinkImporter(
        extractor: ai,
        client: MockClient(
          (_) async => http.Response(
            '<html><body><nav>Menü</nav><article>Kuchen<br>200 g Mehl</article>'
            '<script>tracking()</script></body></html>',
            200,
          ),
        ),
      );
      final d = (await importer.import(Uri.parse('https://blog.at/k'))).single;
      expect(d.title, 'Blog-Kuchen');
      expect(d.sourceUrl, 'https://blog.at/k');
      expect(ai.lastText, contains('200 g Mehl'));
      expect(ai.lastText, isNot(contains('Menü')));
      expect(ai.lastText, isNot(contains('tracking')));
    });

    test('HTTP errors are reported', () async {
      final importer = LinkImporter(
        extractor: FakeExtractor(const []),
        client: MockClient((_) async => http.Response('nope', 404)),
      );
      expect(
        () => importer.import(Uri.parse('https://x.at/404')),
        throwsA(isA<LinkImportException>()),
      );
    });
  });
}
