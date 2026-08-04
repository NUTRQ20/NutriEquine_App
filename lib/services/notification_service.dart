import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);
    await _createAndroidChannel();
    _initialized = true;
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'nutriequine_channel',
      'NutriEquine Reminders',
      description: 'Horse care and supplement reminders',
      importance: Importance.high,
    );
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(channel);
    } catch (_) {}
  }

  Future<void> requestPermissions() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
  }

  // ── Shared notification details ──────────────────────────────────────

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'nutriequine_channel',
      'NutriEquine Reminders',
      channelDescription: 'Horse care and supplement reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  // ── Internal schedule helper — works with v17 ────────────────────────

  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await init();
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Try exact alarm first
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    } catch (_) {}

    // Fall back to inexact alarm
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Shows a notification immediately.
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    try {
      await _plugin.show(id, title, body, _notifDetails);
    } catch (_) {}
  }

  /// Schedules a notification 24 hours before [scheduledDate].
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final notifyAt =
        scheduledDate.subtract(const Duration(hours: 24));
    await _scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: notifyAt,
    );
  }

  /// Schedules a notification at 9:00 AM on [dueDate].
  Future<void> scheduleOnDayNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    final notifyAt = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
      0,
    );
    await _scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: notifyAt,
    );
  }

  /// Schedules TWO notifications:
  ///   1. 24 hours before the due date
  ///   2. At 9:00 AM on the due date
  /// Uses baseId for the first, baseId+1 for the second.
  Future<void> scheduleBothNotifications({
    required int baseId,
    required String title,
    required String beforeBody,
    required String onDayBody,
    required DateTime dueDate,
  }) async {
    await scheduleReminderNotification(
      id: baseId,
      title: title,
      body: beforeBody,
      scheduledDate: dueDate,
    );
    await scheduleOnDayNotification(
      id: baseId + 1,
      title: title,
      body: onDayBody,
      dueDate: dueDate,
    );
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
