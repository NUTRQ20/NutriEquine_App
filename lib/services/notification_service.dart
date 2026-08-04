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
      final impl = _plugin.resolvePlatformSpecificImplementation();
      if (impl is AndroidFlutterLocalNotificationsPlugin) {
        await impl.createNotificationChannel(channel);
      }
    } catch (_) {}
  }

  Future<void> requestPermissions() async {
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation();
      if (impl is AndroidFlutterLocalNotificationsPlugin) {
        await impl.requestNotificationsPermission();
        await impl.requestExactAlarmsPermission();
      } else if (impl is IOSFlutterLocalNotificationsPlugin) {
        await impl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {}
  }

  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) await init();

    final notifyAt =
        scheduledDate.subtract(const Duration(hours: 24));
    if (notifyAt.isBefore(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'nutriequine_channel',
            'NutriEquine Reminders',
            channelDescription:
                'Horse care and supplement reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(notifyAt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'nutriequine_channel',
              'NutriEquine Reminders',
              channelDescription:
                  'Horse care and supplement reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutriequine_channel',
          'NutriEquine Reminders',
          channelDescription:
              'Horse care and supplement reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedules a notification at 9:00 AM on the exact due date.
  Future<void> scheduleOnDayNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    if (!_initialized) await init();

    // Fire at 9:00 AM on the due date
    final notifyAt = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
      0,
    );
    if (notifyAt.isBefore(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(notifyAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'nutriequine_channel',
            'NutriEquine Reminders',
            channelDescription:
                'Horse care and supplement reminders',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(notifyAt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'nutriequine_channel',
              'NutriEquine Reminders',
              channelDescription:
                  'Horse care and supplement reminders',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode:
              AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  /// Schedules TWO notifications for a due date:
  ///   1. 24 hours before the due date
  ///   2. At 9:00 AM on the due date
  /// Uses baseId for the first and baseId+1 for the second.
  Future<void> scheduleBothNotifications({
    required int baseId,
    required String title,
    required String beforeBody,
    required String onDayBody,
    required DateTime dueDate,
  }) async {
    // 24 hours before
    await scheduleReminderNotification(
      id: baseId,
      title: title,
      body: beforeBody,
      scheduledDate: dueDate,
    );
    // On the day at 9 AM
    await scheduleOnDayNotification(
      id: baseId + 1,
      title: title,
      body: onDayBody,
      dueDate: dueDate,
    );
  }

  Future<void> cancelNotification(int id) =>
      _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}