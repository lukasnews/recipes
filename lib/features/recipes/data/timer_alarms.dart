import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// System notification when a kitchen timer ends, also while the app is
/// closed. Behind an interface so tests and web use a no-op.
abstract class TimerAlarms {
  Future<void> schedule(int id, String title, String body, DateTime at);

  Future<void> cancel(int id);
}

class NoTimerAlarms implements TimerAlarms {
  const NoTimerAlarms();

  @override
  Future<void> schedule(int id, String title, String body, DateTime at) async {}

  @override
  Future<void> cancel(int id) async {}
}

class LocalNotificationAlarms implements TimerAlarms {
  LocalNotificationAlarms({required this.channelName});

  /// Shown in Android's notification settings.
  final String channelName;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  var _exact = false;

  Future<void> _init() => _ready ??= () async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    // Android 13+: asks once, on the first timer.
    await android?.requestNotificationsPermission();
    // Exact alarms need the user's OK on Android 14+; otherwise the
    // notification may come a little late.
    _exact = await android?.canScheduleExactNotifications() ?? false;
  }();

  @override
  Future<void> schedule(int id, String title, String body, DateTime at) async {
    await _init();
    if (!at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'cook_timers',
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: _exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}
