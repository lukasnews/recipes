import 'units.dart';

/// One parsed recipe ingredient line, e.g. `"200 g Mehl glatt (gesiebt)"`.
class ParsedIngredientLine {
  const ParsedIngredientLine({
    required this.rawText,
    required this.name,
    this.amount,
    this.unit,
    this.note,
  });

  final String rawText;
  final double? amount;

  /// Canonical unit key (see [Units]) or null.
  final String? unit;
  final String name;
  final String? note;

  @override
  String toString() =>
      'ParsedIngredientLine($amount, $unit, "$name", note: $note)';
}

const _unicodeFractions = {
  '½': 0.5,
  '¼': 0.25,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
  '⅛': 0.125,
};

const _number =
    r'(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:[.,]\d+)?(?:\s*[½¼¾⅓⅔⅛])?|[½¼¾⅓⅔⅛])';
final _amountRe = RegExp(
  '^(?:ca\\.?|etwa|circa|ungefähr)?\\s*($_number)(?:\\s*(?:-|–|bis)\\s*($_number))?',
  caseSensitive: false,
);

double? parseNumber(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  // "1 1/2"
  final mixed = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(s);
  if (mixed != null) {
    final d = int.parse(mixed[3]!);
    if (d == 0) return null;
    return int.parse(mixed[1]!) + int.parse(mixed[2]!) / d;
  }
  final frac = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
  if (frac != null) {
    final d = int.parse(frac[2]!);
    if (d == 0) return null;
    return int.parse(frac[1]!) / d;
  }
  var extra = 0.0;
  final last = s.characters.last;
  if (_unicodeFractions.containsKey(last)) {
    extra = _unicodeFractions[last]!;
    s = s.substring(0, s.length - 1).trim();
    if (s.isEmpty) return extra;
  }
  final n = double.tryParse(s.replaceAll(',', '.'));
  return n == null ? null : n + extra;
}

extension on String {
  List<String> get characters => split('');
}

/// Parses a free text ingredient line. Never throws; unknown parts end up in
/// [ParsedIngredientLine.name].
ParsedIngredientLine parseIngredientLine(String line) {
  final raw = line.trim();
  var rest = raw.replaceFirst(RegExp(r'^[-•*·–]\s*'), '');

  double? amount;
  final m = _amountRe.firstMatch(rest);
  if (m != null) {
    final from = parseNumber(m[1]!);
    final to = m[2] == null ? null : parseNumber(m[2]!);
    // For ranges ("2-3 Eier") take the upper bound so nothing runs short.
    amount = to ?? from;
    rest = rest.substring(m.end).trim();
  }

  String? unit;
  final unitMatch = RegExp(r'^([A-Za-zÄÖÜäöüß]+\.?)(?=\s|$)').firstMatch(rest);
  if (unitMatch != null) {
    final canonical = Units.canonical(unitMatch[1]);
    if (canonical != null) {
      unit = canonical;
      rest = rest.substring(unitMatch.end).trim();
    }
  }
  // Keep "Würfel Germ" style: unit followed by "Hand voll".
  if (unit == null && rest.toLowerCase().startsWith('hand voll')) {
    unit = 'Handvoll';
    rest = rest.substring(9).trim();
  }

  String? note;
  final paren = RegExp(r'\(([^)]*)\)').firstMatch(rest);
  if (paren != null) {
    note = paren[1]!.trim();
    rest = (rest.substring(0, paren.start) + rest.substring(paren.end)).trim();
  }
  final comma = rest.indexOf(',');
  if (comma > 0) {
    final after = rest.substring(comma + 1).trim();
    note = [after, ?note].where((s) => s.isNotEmpty).join(', ');
    rest = rest.substring(0, comma).trim();
  }
  rest = rest.replaceAll(RegExp(r'\s+'), ' ');

  return ParsedIngredientLine(
    rawText: raw,
    amount: amount,
    unit: unit,
    name: rest.isEmpty ? raw : rest,
    note: (note == null || note.isEmpty) ? null : note,
  );
}
