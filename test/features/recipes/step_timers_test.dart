import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/recipes/domain/step_timers.dart';

void main() {
  test('finds durations in step text', () {
    expect(parseStepTimers('Im Rohr ca. 20 Minuten backen.'), [
      const Duration(minutes: 20),
    ]);
    expect(parseStepTimers('10–15 Min. köcheln lassen'), [
      const Duration(minutes: 10),
    ]);
    expect(parseStepTimers('1 Std. 30 Min. schmoren'), [
      const Duration(hours: 1, minutes: 30),
    ]);
    expect(
      parseStepTimers('Eine Stunde rasten lassen, dann 5 Minuten kneten.'),
      [const Duration(hours: 1), const Duration(minutes: 5)],
    );
    expect(parseStepTimers('½ Stunde ziehen lassen'), [
      const Duration(minutes: 30),
    ]);
    expect(parseStepTimers('30 Sekunden mixen'), [const Duration(seconds: 30)]);
    expect(parseStepTimers('1,5 h garen'), [const Duration(minutes: 90)]);
  });

  test('ignores steps without durations', () {
    expect(parseStepTimers('Zwiebeln schälen und hacken.'), isEmpty);
    expect(parseStepTimers('200 g Mehl dazugeben'), isEmpty);
  });

  test('formatting', () {
    expect(formatTimer(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(formatTimer(const Duration(hours: 1, minutes: 2)), '1:02:00');
    expect(formatTimer(const Duration(seconds: -7)), '-0:07');
    expect(timerLabel(const Duration(minutes: 20)), '20 Min.');
    expect(timerLabel(const Duration(hours: 1, minutes: 30)), '1 Std. 30 Min.');
    expect(timerLabel(const Duration(seconds: 45)), '45 Sek.');
  });
}
