import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Feed Auto Update Service
///
/// Runs every time the app opens (called from home_screen.dart initState).
///
/// KEY CHANGE from old version:
///   Old: showInstantNotification()  → only works when app is open
///   New: scheduleRestockAlert()     → schedules tomorrow 8 AM → works in background
///        scheduleFeedingTimeReminder() → schedules at 7/12/18h → works in background
///
/// This means even if the user opens the app once and closes it:
///   - The OS AlarmManager will fire the notifications at the right time
///   - Works even when app is completely closed / killed
class FeedAutoUpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Call this every time the app opens.
  ///
  /// 1. Auto-decrements daysRemaining for missed days.
  /// 2. Schedules restock alert (tomorrow 8 AM) if low stock.
  /// 3. Schedules feeding time reminders for today (7 AM / 12 PM / 6 PM).
  Future<void> runDailyCheck() async {
    if (_uid.isEmpty) return;

    try {
      final snap = await _db
          .collection('feed_entries')
          .where('ownerId', isEqualTo: _uid)
          .get();

      final today = _normalizeDate(DateTime.now());
      final notifService = NotificationService();

      for (final doc in snap.docs) {
        final data = doc.data();
        final daysRemaining = data['daysRemaining'] as int?;
        final itemName = data['itemName'] as String? ?? 'Supplement';
        final timeOfDay = data['timeOfDay'] as String? ?? 'AM';
        final horseId = data['horseId'] as String? ?? '';

        // ── Step 1: Schedule feeding time reminder (works in background) ──
        // This is separate from restock — it's a daily feeding alarm
        if (horseId.isNotEmpty) {
          await notifService.scheduleFeedingTimeReminder(
            id: doc.id.hashCode.abs() % 9000,
            horseName: data['horseName'] as String? ?? 'Your horse',
            itemName: itemName,
            timeOfDay: timeOfDay,
          );
        }

        // ── Step 2: Restock check (only if inventory tracking enabled) ──
        if (daysRemaining == null) continue;

        // If already out of stock, schedule restock alert but skip decrement
        if (daysRemaining <= 0) {
          await notifService.scheduleRestockAlert(
            id: doc.id.hashCode.abs() % 9000,
            itemName: itemName,
            daysRemaining: 0,
          );
          continue;
        }

        final lastGivenAt = data['lastGivenAt'] as int?;
        int daysMissed = 0;

        if (lastGivenAt == null) {
          final createdAt = data['createdAt'] as int?;
          if (createdAt != null) {
            final createdDate = _normalizeDate(
              DateTime.fromMillisecondsSinceEpoch(createdAt),
            );
            daysMissed = today.difference(createdDate).inDays;
          }
        } else {
          final lastDate = _normalizeDate(
            DateTime.fromMillisecondsSinceEpoch(lastGivenAt),
          );
          daysMissed = today.difference(lastDate).inDays;
          // Already given today — skip decrement, but still check low stock
          if (daysMissed == 0) {
            if (daysRemaining <= 7) {
              await notifService.scheduleRestockAlert(
                id: doc.id.hashCode.abs() % 9000,
                itemName: itemName,
                daysRemaining: daysRemaining,
              );
            }
            continue;
          }
        }

        if (daysMissed <= 0) continue;

        // Calculate new days remaining after missed days
        final newDaysRemaining =
            (daysRemaining - daysMissed).clamp(0, daysRemaining);

        // Update Firestore
        await doc.reference.update({'daysRemaining': newDaysRemaining});

        // Schedule restock alert if low stock (fires tomorrow 8 AM in background)
        if (newDaysRemaining <= 7) {
          await notifService.scheduleRestockAlert(
            id: doc.id.hashCode.abs() % 9000,
            itemName: itemName,
            daysRemaining: newDaysRemaining,
          );
        }
      }
    } catch (_) {
      // Non-fatal — never crash the app on notification errors
    }
  }

  /// Called when user TICKS a feed item (marks as given today).
  ///
  /// OLD: showInstantNotification() — only worked when app was open.
  /// NEW: scheduleRestockAlert() at tomorrow 8 AM — works in background.
  Future<void> onFeedItemTicked({
    required String docId,
    required String itemName,
    required int newDaysRemaining,
  }) async {
    final notifService = NotificationService();

    if (newDaysRemaining <= 7) {
      // Schedule restock alert for tomorrow 8 AM (fires even when app is closed)
      await notifService.scheduleRestockAlert(
        id: docId.hashCode.abs() % 9000,
        itemName: itemName,
        daysRemaining: newDaysRemaining,
      );
    } else {
      // Cancel any existing restock alert — stock is now sufficient
      await notifService.cancelNotification(10000 + docId.hashCode.abs() % 9000);
    }
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}