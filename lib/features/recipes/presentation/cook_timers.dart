import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/fire.dart';
import '../data/timer_alarms.dart';

/// Android notification for timers; no-op elsewhere (web preview, tests
/// override it).
final timerAlarmsProvider = Provider<TimerAlarms>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? LocalNotificationAlarms(channelName: 'Küchentimer')
      : const NoTimerAlarms(),
);

class CookTimer {
  const CookTimer({
    required this.id,
    required this.label,
    required this.endsAt,
    this.alerted = false,
    this.alarmTitle = '',
  });

  final int id;
  final String label;
  final DateTime endsAt;
  final bool alerted;

  /// Title of the system notification ("Timer abgelaufen").
  final String alarmTitle;

  Duration remaining(DateTime now) => endsAt.difference(now);

  CookTimer copyWith({DateTime? endsAt, bool? alerted}) => CookTimer(
    id: id,
    label: label,
    endsAt: endsAt ?? this.endsAt,
    alerted: alerted ?? this.alerted,
    alarmTitle: alarmTitle,
  );
}

/// Running kitchen timers. They keep running while the cook moves between
/// steps; the cook mode screen ticks and alerts.
class CookTimers extends Notifier<List<CookTimer>> {
  // Notification ids must stay unique across app restarts.
  var _nextId = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 1000000;

  TimerAlarms get _alarms => ref.read(timerAlarmsProvider);

  void _schedule(CookTimer t) =>
      fire(_alarms.schedule(t.id, t.alarmTitle, t.label, t.endsAt));

  @override
  List<CookTimer> build() => const [];

  void start(
    String label,
    Duration duration, {
    String alarmTitle = '',
    DateTime? now,
  }) {
    final timer = CookTimer(
      id: _nextId++,
      label: label,
      endsAt: (now ?? DateTime.now()).add(duration),
      alarmTitle: alarmTitle,
    );
    state = [...state, timer];
    _schedule(timer);
  }

  void addTime(int id, Duration extra) {
    state = [
      for (final t in state)
        if (t.id == id)
          t.copyWith(endsAt: t.endsAt.add(extra), alerted: false)
        else
          t,
    ];
    // Re-scheduling with the same id replaces the pending notification.
    state.where((t) => t.id == id).forEach(_schedule);
  }

  void markAlerted(int id) => state = [
    for (final t in state) t.id == id ? t.copyWith(alerted: true) : t,
  ];

  void cancel(int id) {
    fire(_alarms.cancel(id));
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];
  }

  void clear() {
    for (final t in state) {
      fire(_alarms.cancel(t.id));
    }
    state = const [];
  }
}

final cookTimersProvider = NotifierProvider<CookTimers, List<CookTimer>>(
  CookTimers.new,
);
