import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Channel IDs
  static const _channelDaily = 'daily_reminder';
  static const _channelDeadline = 'deadline_reminder';

  static Future<void> init() async {
    if (_initialized) return;

    // Init timezone database — always Asia/Jakarta (WIB)
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      dev.log(
        '[Notif] Timezone set → Asia/Jakarta (WIB)',
        name: 'NotifService',
      );
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
      dev.log(
        '[Notif] WARN: Timezone fallback to UTC — $e',
        name: 'NotifService',
      );
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final result = await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    dev.log('[Notif] Plugin initialized → $result', name: 'NotifService');

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Android 13+ — POST_NOTIFICATIONS runtime permission
      final notifGranted = await androidImpl?.requestNotificationsPermission();
      dev.log(
        '[Notif] POST_NOTIFICATIONS granted → $notifGranted',
        name: 'NotifService',
      );

      // Android 12+ — SCHEDULE_EXACT_ALARM permission (non-blocking)
      try {
        await androidImpl?.requestExactAlarmsPermission();
        final exactOk = await androidImpl?.canScheduleExactNotifications();
        dev.log(
          '[Notif] Exact alarm permission → $exactOk',
          name: 'NotifService',
        );
      } catch (e) {
        dev.log(
          '[Notif] Exact alarm permission error (non-fatal) → $e',
          name: 'NotifService',
        );
      }

      // Create notification channels (required Android 8+)
      await _createChannels(androidImpl);
    }

    _initialized = true;
    dev.log('[Notif] NotificationService ready ✓', name: 'NotifService');
  }

  static Future<void> _createChannels(
    AndroidFlutterLocalNotificationsPlugin? androidImpl,
  ) async {
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelDaily,
        'Daily Reminder',
        description: 'Pengingat harian progress skripsi',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelDeadline,
        'Deadline Reminder',
        description: 'Notifikasi deadline tugas',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    dev.log('[Notif] Channels created ✓', name: 'NotifService');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    dev.log(
      '[Notif] Tapped → id=${response.id} payload=${response.payload}',
      name: 'NotifService',
    );
  }

  // ── Ensure init is called before any schedule operation ───────────────────

  static Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  // ── Daily reminder at a fixed hour (WIB) ──────────────────────────────────

  static Future<void> scheduleDailyReminder({
    int hour = 9,
    int minute = 0,
  }) async {
    await _ensureInit();
    await _plugin.cancel(1);

    final jakarta = tz.getLocation('Asia/Jakarta');
    final now = tz.TZDateTime.now(jakarta);
    var scheduled = tz.TZDateTime(
      jakarta,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    dev.log(
      '[Notif] Scheduling daily reminder → $scheduled',
      name: 'NotifService',
    );

    await _zonedScheduleSafe(
      id: 1,
      title: 'Skripsi Manager',
      body: 'Garap Skripsimu Cokkkkkk!!!',
      scheduled: scheduled,
      channelId: _channelDaily,
      channelName: 'Daily Reminder',
      channelDesc: 'Pengingat harian progress skripsi',
      importance: Importance.high,
      priority: Priority.high,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    dev.log(
      '[Notif] Daily reminder scheduled → pukul ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} WIB',
      name: 'NotifService',
    );
  }

  // ── Deadline notification (1 day before deadline) ─────────────────────────

  static Future<void> scheduleDeadline({
    required int id,
    required String title,
    required DateTime deadline,
  }) async {
    await _ensureInit();

    final jakarta = tz.getLocation('Asia/Jakarta');
    final target = deadline.subtract(const Duration(days: 1));
    final scheduled = tz.TZDateTime.from(target, jakarta);
    final now = tz.TZDateTime.now(jakarta);

    if (scheduled.isBefore(now)) {
      dev.log(
        '[Notif] Skipping deadline "$title" — waktu sudah lewat ($scheduled)',
        name: 'NotifService',
      );
      return;
    }

    dev.log(
      '[Notif] Scheduling deadline "$title" → $scheduled',
      name: 'NotifService',
    );

    await _zonedScheduleSafe(
      id: id + 100,
      title: 'Deadline Besok!',
      body: title,
      scheduled: scheduled,
      channelId: _channelDeadline,
      channelName: 'Deadline Reminder',
      channelDesc: 'Notifikasi deadline tugas',
      importance: Importance.max,
      priority: Priority.max,
    );

    dev.log(
      '[Notif] Deadline scheduled ✓ id=${id + 100}',
      name: 'NotifService',
    );
  }

  // ── Schedule a one-time reminder at a specific DateTime (WIB) ─────────────

  static Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _ensureInit();

    final jakarta = tz.getLocation('Asia/Jakarta');
    final scheduled = tz.TZDateTime.from(scheduledTime, jakarta);
    final now = tz.TZDateTime.now(jakarta);

    if (scheduled.isBefore(now)) {
      dev.log(
        '[Notif] Skipping one-time "$title" — waktu sudah lewat ($scheduled)',
        name: 'NotifService',
      );
      return;
    }

    dev.log(
      '[Notif] Scheduling one-time "$title" → $scheduled',
      name: 'NotifService',
    );

    await _zonedScheduleSafe(
      id: id,
      title: title,
      body: body,
      scheduled: scheduled,
      channelId: _channelDeadline,
      channelName: 'Deadline Reminder',
      channelDesc: 'Notifikasi deadline tugas',
      importance: Importance.max,
      priority: Priority.max,
    );
  }

  // ── Core schedule helper — exact first, inexact fallback ──────────────────

  static Future<void> _zonedScheduleSafe({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required Importance importance,
    required Priority priority,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: importance,
        priority: priority,
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        styleInformation: const BigTextStyleInformation(''),
      ),
    );

    // Attempt exact alarm (Android 12+ requires SCHEDULE_EXACT_ALARM permission)
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        // Required by FLN v18 API (iOS legacy param — irrelevant on Android but must be passed)
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      dev.log('[Notif] zonedSchedule EXACT ok → id=$id', name: 'NotifService');
    } catch (e) {
      dev.log(
        '[Notif] Exact alarm denied, falling back to inexact → $e',
        name: 'NotifService',
      );
      // Fallback to inexact — fires even without SCHEDULE_EXACT_ALARM permission
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
        );
        dev.log(
          '[Notif] zonedSchedule INEXACT ok → id=$id',
          name: 'NotifService',
        );
      } catch (e2) {
        dev.log(
          '[Notif] ERROR: Both exact and inexact schedule failed → $e2',
          name: 'NotifService',
        );
      }
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  static Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAll();
    dev.log('[Notif] All notifications cancelled', name: 'NotifService');
  }

  static Future<void> cancel(int id) async {
    await _ensureInit();
    await _plugin.cancel(id);
    dev.log('[Notif] Notification cancelled → id=$id', name: 'NotifService');
  }

  static Future<List<PendingNotificationRequest>> getPending() async {
    await _ensureInit();
    final list = await _plugin.pendingNotificationRequests();
    dev.log(
      '[Notif] Pending notifications → ${list.length}',
      name: 'NotifService',
    );
    return list;
  }

  /// Returns true if exact alarm permission is granted (Android 12+)
  static Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    await _ensureInit();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final result = await androidImpl?.canScheduleExactNotifications() ?? false;
    dev.log('[Notif] hasExactAlarmPermission → $result', name: 'NotifService');
    return result;
  }

  /// Debug: show current timezone info
  static void logTimezoneInfo() {
    final jakarta = tz.getLocation('Asia/Jakarta');
    final now = tz.TZDateTime.now(jakarta);
    dev.log('[Notif] Current WIB time → $now', name: 'NotifService');
    dev.log('[Notif] tz.local → ${tz.local.name}', name: 'NotifService');
  }
}
