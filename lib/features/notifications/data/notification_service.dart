import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Run timezone DB load off the synchronous call path to avoid UI jank
    await Future(() => tz_data.initializeTimeZones());

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    if (Platform.isAndroid) {
      final androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  // Daily reminder at a fixed hour
  static Future<void> scheduleDailyReminder({int hour = 9, int minute = 0}) async {
    await _plugin.cancel(1);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1,
      'Skripsi Manager',
      'Jangan lupa update progress skripsimu hari ini!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          channelDescription: 'Pengingat harian progress skripsi',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleDeadline({
    required int id,
    required String title,
    required DateTime deadline,
  }) async {
    final scheduled = tz.TZDateTime.from(deadline.subtract(const Duration(days: 1)), tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id + 100,
      'Deadline Besok!',
      title,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'deadline',
          'Deadline Reminder',
          channelDescription: 'Notifikasi deadline tugas',
          importance: Importance.max,
          priority: Priority.max,
          autoCancel: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<List<PendingNotificationRequest>> getPending() =>
      _plugin.pendingNotificationRequests();
}
