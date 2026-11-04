/// Durations mentioned in a recipe step, e.g. "20 Minuten backen" or
/// "1 Std. 30 Min. schmoren". Ranges ("10–15 Min.") use the lower bound;
/// the cook can add time on the running timer.
List<Duration> parseStepTimers(String text) {
  final found = <Duration>[];
  final re = RegExp(
    r'(\d+(?:[.,]\d+)?|½|eine[nr]?|ein)\s*(?:(?:-|–|bis)\s*\d+(?:[.,]\d+)?\s*)?'
    r'(stunden|stunde|std\.?|h\b|minuten|minute|min\.?|sekunden|sek\.?)',
    caseSensitive: false,
  );
  final matches = re.allMatches(text).toList();
  var i = 0;
  while (i < matches.length) {
    var total = _duration(matches[i]);
    // "1 Std. 30 Min." is one timer.
    if (i + 1 < matches.length &&
        _isHours(matches[i]) &&
        !_isHours(matches[i + 1]) &&
        text.substring(matches[i].end, matches[i + 1].start).trim().length <=
            4) {
      total += _duration(matches[i + 1]);
      i++;
    }
    if (total > Duration.zero && total <= const Duration(hours: 24)) {
      found.add(total);
    }
    i++;
  }
  return found;
}

bool _isHours(RegExpMatch m) => m[2]!.toLowerCase().startsWith(RegExp('st|h'));

Duration _duration(RegExpMatch m) {
  final raw = m[1]!.toLowerCase();
  final value = switch (raw) {
    '½' => 0.5,
    'ein' || 'eine' || 'einen' || 'einer' => 1.0,
    _ => double.tryParse(raw.replaceAll(',', '.')) ?? 0,
  };
  final unit = m[2]!.toLowerCase();
  final seconds = unit.startsWith(RegExp('st|h'))
      ? value * 3600
      : unit.startsWith('min')
      ? value * 60
      : value;
  return Duration(seconds: seconds.round());
}

/// "1:05:00", "12:30", "0:45".
String formatTimer(Duration d) {
  final neg = d.isNegative;
  final a = d.abs();
  final h = a.inHours;
  final m = a.inMinutes.remainder(60);
  final s = a.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  final text = h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  return neg ? '-$text' : text;
}

/// Short label for a timer button: "20 Min.", "1 Std. 30 Min.", "45 Sek."
String timerLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return [
    if (h > 0) '$h Std.',
    if (m > 0) '$m Min.',
    if (h == 0 && m == 0 && s > 0) '$s Sek.',
  ].join(' ');
}
