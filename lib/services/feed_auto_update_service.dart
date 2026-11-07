import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Feed Auto Update Service
///
/// Called from splash_screen.dart when user is confirmed logged in.
///
/// Once notifications are scheduled via zonedSchedule(), Android AlarmManager
/// fires them at the set time even if the app is completely closed/killed.
/// The app does NOT need to be open for notifications to fire.
///
/// Background delivery:
///   scheduleRestockAlert()         → fires at 8 AM (today if not passed, else tomorrow)
///   scheduleFeedingTimeReminder()  → fires daily at 7 AM / 12 PM / 6 PM
class FeedAutoUpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Call this on app open (from splash_screen.dart after auth confirmed).
  ///
  /// 1. Schedules restock alert at 8 AM for any feed entry with stock ≤ 7 days.
  /// 2. Schedules daily feeding time reminders for each feed entry.
  ///
  /// Never modifies Firestore. Only reads and schedules notifications.
  Future<void> runDailyCheck() async {
    if (_uid.isEmpty) return;

    try {
      final snap = await _db
          .collection('feed_entries')
          .where('ownerId', isEqualTo: _uid)
          .get();

      final notifService = NotificationService();
      await notifService.init(); // ensure plugin is ready before scheduling

      // Cache horse names to avoid repeated Firestore reads for same horse
      final Map<String, String> horseNameCache = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final daysRemaining = (data['daysRemaining'] as num?)?.toInt();
        final itemName = data['itemName'] as String? ?? 'Supplement';
        final timeOfDay = data['timeOfDay'] as String? ?? 'AM';
        final horseId = data['horseId'] as String? ?? '';
        final storedHorseName = data['horseName'] as String?;

        final safeId = doc.id.hashCode.abs();

        // ── Resolve horse name ────────────────────────────────────────
        // 1. Use stored horseName if it's real (not empty / placeholder)
        // 2. Otherwise look up the horse document by horseId
        // 3. Fallback: item name
        String horseName;
        final isPlaceholder = storedHorseName == null ||
            storedHorseName.isEmpty ||
            storedHorseName == 'Your horse';

        if (!isPlaceholder) {
          horseName = storedHorseName!;
        } else if (horseId.isNotEmpty) {
          if (horseNameCache.containsKey(horseId)) {
            horseName = horseNameCache[horseId]!;
          } else {
            try {
              final horseDoc =
                  await _db.collection('horses').doc(horseId).get();
              final name = horseDoc.data()?['name'] as String?;
              horseName =
                  (name != null && name.isNotEmpty) ? name : itemName;
              horseNameCache[horseId] = horseName;
              // Patch the feed entry so future reads skip this lookup
              await doc.reference.update({'horseName': horseName});
            } catch (_) {
              horseName = itemName;
            }
          }
        } else {
          horseName = itemName;
        }

        // ── Step 1: Schedule daily feeding time reminder ──────────────
        await notifService.scheduleFeedingTimeReminder(
          id: safeId,
          horseName: horseName,
          itemName: itemName,
          timeOfDay: timeOfDay,
        );

        // ── Step 2: Restock alert if low stock ────────────────────────
        if (daysRemaining == null) continue;

        // Cancel stale alert first so count shown is always current
        await notifService.cancelNotification(10000 + safeId);

        if (daysRemaining <= 7) {
          await notifService.scheduleRestockAlert(
            id: safeId,
            horseName: horseName,
            itemName: itemName,
            daysRemaining: daysRemaining,
          );
        }
      }
    } catch (_) {
      // Non-fatal — never crash the app on notification errors
    }
  }

  /// Called when user TICKS a feed item (marks as given today).
  Future<void> onFeedItemTicked({
    required String docId,
    required String itemName,
    required int newDaysRemaining,
  }) async {
    final notifService = NotificationService();
    await notifService.init();

    if (newDaysRemaining <= 7) {
      await notifService.scheduleRestockAlert(
        id: docId.hashCode.abs(),
        itemName: itemName,
        daysRemaining: newDaysRemaining,
      );
    } else {
      await notifService.cancelNotification(10000 + docId.hashCode.abs());
    }
  }
}