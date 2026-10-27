import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// EquineEdge Notification Service
///
/// KEY PRINCIPLE — why background notifications work:
/// flutter_local_notifications uses Android AlarmManager for zonedSchedule().
/// AlarmManager fires even when the app is completely closed / killed.
/// The OS wakes a background process just to fire the notification.
///
/// What DOES NOT work in background:
///   showInstantNotification() — calls show() which needs a running Dart isolate.
///
/// The fix for ALL 3 notification types:
///   NEVER use showInstantNotification() when you want background delivery.
///   Instead: schedule every notification at a specific future time using
///   zonedSchedule(). Even scheduling 5 seconds from now works in background.
///
/// Notification ID ranges (to avoid collisions):
///   Feed restock    : 10000 + hash  (scheduled next morning 8 AM)
///   Feed time AM    : 20000 + hash  (7:00 AM daily)
///   Feed time PM    : 21000 + hash  (6:00 PM daily)
///   Feed time Mid   : 22000 + hash  (12:00 PM daily)
///   Reminder before : 30000 + index (24 hrs before due)
///   Reminder on day : 31000 + index (9:00 AM on due date)
///   Barn before     : 40000 + index (24 hrs before due)
///   Barn on day     : 41000 + index (9:00 AM on due date)
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'equineedge_channel';
  static const String _channelName = 'EquineEdge Notifications';
  static const String _channelDesc =
      'Feed reminders, restock alerts, care reminders and barn tasks';

  bool _initialized = false;

  // ── Init ───────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Set device local timezone
    final String timeZoneName = _localTimeZoneName();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    _initialized = true;
  }

  String _localTimeZoneName() {
    // Best-effort local timezone detection
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'Asia/Kolkata';
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ── Android channel details ────────────────────────────────────────

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

  NotificationDetails get _notifDetails =>
      NotificationDetails(android: _androidDetails);

  // ── SCHEDULE helper ────────────────────────────────────────────────

  /// The ONLY method that fires in background.
  /// Schedules a notification at [scheduledDate].
  /// Uses inexact alarm as fallback for devices that deny exact alarms.
  Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    // Don't schedule in the past
    final now = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(now)) return;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on Exception {
      // Fallback: inexact alarm (still fires in background, just not exactly on time)
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          _notifDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }
  }

  // ── Cancel ─────────────────────────────────────────────────────────

  Future<void> cancelNotification(int id) =>
      _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  // ═══════════════════════════════════════════════════════════════════
  // FEED PLAN NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Schedule a LOW STOCK / OUT OF STOCK alert for tomorrow 8:00 AM.
  ///
  /// Called when:
  ///   - User ticks a feed item and daysRemaining drops to ≤ 7
  ///   - App opens and auto-check finds low stock (runDailyCheck)
  ///
  /// WHY TOMORROW 8 AM:
  ///   Scheduling at a future time works even when app is closed.
  ///   The OS AlarmManager fires the notification regardless of app state.
  ///   Cancels any previous restock alert for same item first.
  Future<void> scheduleRestockAlert({
    required int id,
    required String itemName,
    required int daysRemaining,
  }) async {
    // Cancel previous alert for this item
    await _plugin.cancel(10000 + id);

    final now = tz.TZDateTime.now(tz.local);
    // Schedule for tomorrow 8:00 AM
    var tomorrow8am = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      8,
      0,
    );

    final title = daysRemaining == 0
        ? '🚨 Out of Stock: $itemName'
        : '⚠️ Low Stock: $itemName';

    final body = daysRemaining == 0
        ? '$itemName has run out. Reorder now before feeding time!'
        : 'Only $daysRemaining days of $itemName remaining. Time to reorder.';

    await _scheduleAt(
      id: 10000 + id,
      title: title,
      body: body,
      scheduledDate: tomorrow8am,
    );
  }

  /// Schedule feeding time reminder for today.
  ///
  /// timeOfDay: 'AM' → 7:00 AM, 'Midday' → 12:00 PM, 'PM' → 6:00 PM
  ///
  /// If that time has already passed today, schedules for tomorrow.
  /// This fires even when app is completely closed.
  Future<void> scheduleFeedingTimeReminder({
    required int id,
    required String horseName,
    required String itemName,
    required String timeOfDay,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    int hour;
    int baseId;
    switch (timeOfDay) {
      case 'AM':
        hour = 7;
        baseId = 20000;
        break;
      case 'Midday':
        hour = 12;
        baseId = 22000;
        break;
      case 'PM':
      default:
        hour = 18;
        baseId = 21000;
        break;
    }

    // Cancel old notification for this entry
    await _plugin.cancel(baseId + id);

    // Schedule for today at the feeding hour
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      0,
    );

    // If time already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _scheduleAt(
      id: baseId + id,
      title: '🐴 Feeding Time: $horseName',
      body: 'Time to give $itemName to $horseName.',
      scheduledDate: scheduledTime,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REMINDERS — 24 hrs before + 9 AM on the day
  // ═══════════════════════════════════════════════════════════════════

  /// Schedule BOTH reminder notifications for a care reminder.
  ///
  /// notification 1: 24 hours before dueDate
  /// notification 2: 9:00 AM on the day of dueDate
  ///
  /// Both fire in background via AlarmManager.
  Future<void> scheduleReminderNotifications({
    required int baseId,
    required String title,
    required DateTime dueDate,
    String? category,
  }) async {
    // Cancel existing notifications for this reminder
    await _plugin.cancel(30000 + baseId);
    await _plugin.cancel(31000 + baseId);

    final now = tz.TZDateTime.now(tz.local);
    final categoryTag = category != null ? '[$category] ' : '';

    // Notification 1: 24 hours before (only schedules if still in the future)
    final before = tz.TZDateTime.from(
      dueDate.subtract(const Duration(hours: 24)),
      tz.local,
    );
    await _scheduleAt(
      id: 30000 + baseId,
      title: '📅 Reminder Tomorrow: $title',
      body: '${categoryTag}Due tomorrow. Tap to view.',
      scheduledDate: before,
    );

    // Notification 2: at the user's set time on the due day.
    // If that time is already past, fire 2 hours from now as fallback.
    var onDay = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueDate.hour,    // user's chosen hour
      dueDate.minute,  // user's chosen minute
    );
    if (onDay.isBefore(now)) {
      onDay = now.add(const Duration(hours: 2));
    }
    await _scheduleAt(
      id: 31000 + baseId,
      title: '📅 Reminder: $title',
      body: '${categoryTag}Due today. Tap to view.',
      scheduledDate: onDay,
    );
  }

  /// Cancel both notifications for a reminder (when marked complete or deleted).
  Future<void> cancelReminderNotifications(int baseId) async {
    await _plugin.cancel(30000 + baseId);
    await _plugin.cancel(31000 + baseId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // BARN TASKS — 24 hrs before + 9 AM on the day
  // ═══════════════════════════════════════════════════════════════════

  /// Schedule BOTH barn task notifications.
  ///
  /// notification 1: 24 hours before dueDate
  /// notification 2: 9:00 AM on the day of dueDate
  ///
  /// Both fire in background via AlarmManager.
  Future<void> scheduleBarnTaskNotifications({
    required int baseId,
    required String taskTitle,
    required DateTime dueDate,
    String? assignedTo,
  }) async {
    // Cancel existing notifications for this task
    await _plugin.cancel(40000 + baseId);
    await _plugin.cancel(41000 + baseId);

    final now = tz.TZDateTime.now(tz.local);
    final assignee = assignedTo != null && assignedTo.isNotEmpty
        ? ' (Assigned to $assignedTo)'
        : '';

    // Notification 1: 24 hours before (only schedules if still in the future)
    final before = tz.TZDateTime.from(
      dueDate.subtract(const Duration(hours: 24)),
      tz.local,
    );
    await _scheduleAt(
      id: 40000 + baseId,
      title: '🏚️ Task Tomorrow: $taskTitle',
      body: 'Due tomorrow.$assignee Tap to view.',
      scheduledDate: before,
    );

    // Notification 2: at the user's set time on the due day.
    // If that time is already past, fire 2 hours from now as fallback.
    var onDay = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      dueDate.hour,    // user's chosen hour
      dueDate.minute,  // user's chosen minute
    );
    if (onDay.isBefore(now)) {
      onDay = now.add(const Duration(hours: 2));
    }
    await _scheduleAt(
      id: 41000 + baseId,
      title: '🏚️ Task Due: $taskTitle',
      body: 'Due today.$assignee Tap to view.',
      scheduledDate: onDay,
    );
  }

  /// Cancel both notifications for a barn task (when marked complete or deleted).
  Future<void> cancelBarnTaskNotifications(int baseId) async {
    await _plugin.cancel(40000 + baseId);
    await _plugin.cancel(41000 + baseId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // LEGACY — kept for any callers in existing screens
  // ═══════════════════════════════════════════════════════════════════

  /// @deprecated Use scheduleReminderNotifications() instead.
  /// Left here so existing calendar_screen.dart / care_reminder code
  /// doesn't break. Internally routes to the new scheduled method.
  Future<void> scheduleBothNotifications({
    required int baseId,
    required String beforeBody,
    required String onDayBody,
    required DateTime dueDate,
    String? title, // optional — callers may pass a custom title
  }) async {
    await _plugin.cancel(30000 + baseId);
    await _plugin.cancel(31000 + baseId);

    final notifTitle = title ?? '📅 EquineEdge Reminder';

    final before = tz.TZDateTime.from(
      dueDate.subtract(const Duration(hours: 24)),
      tz.local,
    );
    await _scheduleAt(
      id: 30000 + baseId,
      title: notifTitle,
      body: beforeBody,
      scheduledDate: before,
    );

    final onDay = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
      0,
    );
    await _scheduleAt(
      id: 31000 + baseId,
      title: notifTitle,
      body: onDayBody,
      scheduledDate: onDay,
    );
  }

  /// @deprecated Use scheduleRestockAlert() or scheduleFeedingTimeReminder().
  /// Kept for legacy call sites. Routes to scheduleRestockAlert for low stock.
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Route to a scheduled notification (5 minutes from now)
    // This works in background unlike show()
    final scheduledTime = tz.TZDateTime.now(tz.local).add(
      const Duration(minutes: 5),
    );
    await _scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
    );
  }

  /// @deprecated Use scheduleFeedingTimeReminder().
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
    );
  }

  /// @deprecated Use scheduleFeedingTimeReminder().
  Future<void> scheduleOnDayNotification({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    int hour = 9,
    int minute = 0,
  }) async {
    final scheduledTime = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    await _scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FEED AUTO UPDATE SERVICE
// ═══════════════════════════════════════════════════════════════════════════
//
// Runs on app start for logged-in users.
//
// IMPORTANT — what this service does and does NOT do:
//
//   ✅ Reads current daysRemaining from Firestore.
//   ✅ Fires a low-stock notification if daysRemaining ≤ 7.
//   ❌ NEVER decrements daysRemaining automatically.
//
// daysRemaining is decremented ONLY when the user explicitly taps
// the check button (✓) on a feed entry in the Feed Plan tab.
// That tap calls FirestoreService.decrementDaysRemaining() from
// the UI — this service has no role in the countdown.
//
// The previous auto-decrement logic (subtracting days elapsed since
// lastGivenAt) was removed because it reduced the stock counter
// without the user confirming the feed was actually given.
//
// Usage in main.dart:
//   import 'notification_service.dart';
//   // Remove: import 'feed_auto_update_service.dart';
//   await FeedAutoUpdateService().runDailyCheck();
// ═══════════════════════════════════════════════════════════════════════════

class FeedAutoUpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Call this every time the app opens (for a logged-in user).
  ///
  /// Reads all feed entries and fires a low-stock notification for
  /// any entry whose daysRemaining is already ≤ 7.
  /// No Firestore writes are performed here — stock counts are never
  /// modified by this service.
  Future<void> runDailyCheck() async {
    if (_uid.isEmpty) return;

    try {
      final snap = await _db
          .collection('feed_entries')
          .where('ownerId', isEqualTo: _uid)
          .get();

      final notifService = NotificationService();

      for (final doc in snap.docs) {
        final data = doc.data();
        final daysRemaining = data['daysRemaining'] as int?;

        // Skip entries with no inventory tracking
        if (daysRemaining == null) continue;

        // Notify if stock is low — never modify the value
        if (daysRemaining <= 7) {
          final itemName =
              data['itemName'] as String? ?? 'Supplement';

          // Schedule alert for tomorrow 8 AM (works even when app is closed)
          await notifService.scheduleRestockAlert(
            id: doc.id.hashCode,
            itemName: itemName,
            daysRemaining: daysRemaining,
          );
        }
      }
    } catch (_) {
      // Non-fatal — don't crash the app on startup
    }
  }
}