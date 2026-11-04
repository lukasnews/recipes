import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipes/features/recipes/data/timer_alarms.dart';
import 'package:recipes/features/recipes/presentation/cook_timers.dart';

class RecordingAlarms implements TimerAlarms {
  final scheduled = <int, DateTime>{};

  @override
  Future<void> schedule(int id, String title, String body, DateTime at) async =>
      scheduled[id] = at;

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

void main() {
  test('timers schedule, extend and cancel notifications', () {
    final alarms = RecordingAlarms();
    final c = ProviderContainer(
      overrides: [timerAlarmsProvider.overrideWithValue(alarms)],
    );
    addTearDown(c.dispose);
    final timers = c.read(cookTimersProvider.notifier);
    final now = DateTime(2026, 11, 4, 12);

    timers.start('Schritt 1: 10 Min.', const Duration(minutes: 10), now: now);
    final id = c.read(cookTimersProvider).single.id;
    expect(alarms.scheduled[id], DateTime(2026, 11, 4, 12, 10));

    timers.addTime(id, const Duration(minutes: 1));
    expect(alarms.scheduled[id], DateTime(2026, 11, 4, 12, 11));

    timers.start('Schritt 2', const Duration(minutes: 5), now: now);
    timers.cancel(id);
    expect(alarms.scheduled.keys, isNot(contains(id)));
    timers.clear();
    expect(alarms.scheduled, isEmpty);
  });
}
