import 'package:flutter_riverpod/flutter_riverpod.dart';

class CookTimer {
  const CookTimer({
    required this.id,
    required this.label,
    required this.endsAt,
    this.alerted = false,
  });

  final int id;
  final String label;
  final DateTime endsAt;
  final bool alerted;

  Duration remaining(DateTime now) => endsAt.difference(now);

  CookTimer copyWith({DateTime? endsAt, bool? alerted}) => CookTimer(
    id: id,
    label: label,
    endsAt: endsAt ?? this.endsAt,
    alerted: alerted ?? this.alerted,
  );
}

/// Running kitchen timers. They keep running while the cook moves between
/// steps; the cook mode screen ticks and alerts.
class CookTimers extends Notifier<List<CookTimer>> {
  var _nextId = 0;

  @override
  List<CookTimer> build() => const [];

  void start(String label, Duration duration, {DateTime? now}) {
    state = [
      ...state,
      CookTimer(
        id: _nextId++,
        label: label,
        endsAt: (now ?? DateTime.now()).add(duration),
      ),
    ];
  }

  void addTime(int id, Duration extra) => state = [
    for (final t in state)
      if (t.id == id)
        t.copyWith(endsAt: t.endsAt.add(extra), alerted: false)
      else
        t,
  ];

  void markAlerted(int id) => state = [
    for (final t in state) t.id == id ? t.copyWith(alerted: true) : t,
  ];

  void cancel(int id) => state = [
    for (final t in state)
      if (t.id != id) t,
  ];

  void clear() => state = const [];
}

final cookTimersProvider = NotifierProvider<CookTimers, List<CookTimer>>(
  CookTimers.new,
);
