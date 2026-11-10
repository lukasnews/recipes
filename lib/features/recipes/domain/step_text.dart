/// Steps typed or pasted into the editor (e.g. copied from ChatGPT):
/// "1. … / 2. …" numbering and bullets removed, lines broken mid-sentence
/// joined, and a trailing section like "Zum Verfeinern:" or "Tipp:" moved
/// to the notes.
({List<String> steps, String extraNotes}) cleanStepText(String text) {
  final lines = [
    for (final l in text.split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  final numbered = lines.where(_number.hasMatch).length;
  // "Numbered" only when it really is a list (1., 2., …).
  final isNumbered = numbered >= 2;

  final steps = <String>[];
  final notes = <String>[];
  var inNotes = false;
  for (final line in lines) {
    if (inNotes) {
      notes.add(line);
      continue;
    }
    if (steps.isNotEmpty && _isSectionHeading(line)) {
      inNotes = true;
      notes.add(line);
      continue;
    }
    final text = line
        .replaceFirst(_number, '')
        .replaceFirst(_bullet, '')
        .trim();
    if (text.isEmpty) continue;
    final startsStep = !isNumbered || _number.hasMatch(line);
    final continues =
        steps.isNotEmpty &&
        (!startsStep ||
            // Wrapped mid-sentence without numbering ("in die heiße" /
            // "Schokolade geben.").
            (!isNumbered &&
                !RegExp(r'[.!?:)]$').hasMatch(steps.last) &&
                RegExp(r'^[a-zäöüß]').hasMatch(text)));
    if (continues) {
      steps[steps.length - 1] = '${steps.last} $text';
    } else {
      steps.add(text);
    }
  }
  return (steps: steps, extraNotes: notes.join('\n'));
}

final _number = RegExp(
  r'^(?:schritt\s*)?\d{1,2}\s*[.):]\s*',
  caseSensitive: false,
);
final _bullet = RegExp(r'^[-–—•*·▪●◦]\s*');

/// "Zum Verfeinern:", "Tipp:", "Mein Tipp: Nimm …", "Variante:".
bool _isSectionHeading(String line) {
  if (_number.hasMatch(line)) return false;
  final head = line.split(':').first.trim().toLowerCase();
  if (!line.contains(':') || head.length > 30) return false;
  if (RegExp(
    r'^(mein |unser )?(tipps?|hinweise?|varianten?|serviervorschlag|'
    r'zum (verfeinern|servieren)|dazu passt|toppings?|extras?|optional|'
    r'aufbewahrung|anmerkungen?|notizen?)$',
  ).hasMatch(head)) {
    return true;
  }
  // Any other short "Heading:" line on its own.
  return line.endsWith(':') && line.length <= 30 && !line.contains(' und ');
}
