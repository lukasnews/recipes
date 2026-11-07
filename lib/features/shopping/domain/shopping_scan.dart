/// Result of reading a photographed shopping list.
class ShoppingScan {
  const ShoppingScan(this.lines, {this.offline = false, this.aiError});

  /// One item per line, amount first where known ("500 g Mehl").
  final List<String> lines;

  /// Read on the phone without AI (worse with handwriting).
  final bool offline;
  final String? aiError;
}

final _bullet = RegExp(r'^(?:[-–—•*·□☐☑✓✔>]+|\d{1,2}[.)])\s*');
final _heading = RegExp(
  r'^(einkaufs?(liste|zettel)?|liste|to ?do|zu kaufen)\s*:?$',
  caseSensitive: false,
);

/// Item lines from raw OCR text: one per line, also "Milch, Eier, Brot",
/// without bullets, headings and duplicates. Decimal commas ("1,5 l")
/// stay because only a comma followed by a space splits.
List<String> shoppingLinesFromText(String text) {
  final seen = <String>{};
  final lines = <String>[];
  for (final raw in text.split(RegExp(r'[\r\n]+'))) {
    for (final part in raw.split(RegExp(r'[,;]\s+'))) {
      final line = part
          .replaceFirst(_bullet, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (line.length < 2 || _heading.hasMatch(line)) continue;
      // Needs at least one letter ("500" alone is noise).
      if (!RegExp(r'[A-Za-zÄÖÜäöüß]').hasMatch(line)) continue;
      if (seen.add(line.toLowerCase())) lines.add(line);
    }
  }
  return lines;
}

/// AI lines: trimmed, without empty lines and duplicates (no splitting,
/// "Mehl, glatt" stays one item).
List<String> dedupeLines(Iterable<String> lines) {
  final seen = <String>{};
  return [
    for (final l in lines.map((l) => l.trim()))
      if (l.isNotEmpty && seen.add(l.toLowerCase())) l,
  ];
}
