import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FeedAutoUpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Call this every time the app opens.
  /// Checks all feed entries and auto-decrements
  /// daysRemaining based on days missed since last given.
  Future<void> runDailyCheck() async {
    if (_uid.isEmpty) return;

    try {
      // Get all feed entries for this user
      final snap = await _db
          .collection('feed_entries')
          .where('ownerId', isEqualTo: _uid)
          .get();

      final today = _normalizeDate(DateTime.now());
      final notifService = NotificationService();

      for (final doc in snap.docs) {
        final data = doc.data();
        final daysRemaining =
            data['daysRemaining'] as int?;

        // Skip if no inventory tracking
        if (daysRemaining == null) continue;
        // Skip if already at 0
        if (daysRemaining <= 0) continue;

        final lastGivenAt =
            data['lastGivenAt'] as int?;

        int daysMissed = 0;

        if (lastGivenAt == null) {
          // Never been marked given
          // Check when the entry was created
          final createdAt =
              data['createdAt'] as int?;
          if (createdAt != null) {
            final createdDate = _normalizeDate(
              DateTime.fromMillisecondsSinceEpoch(
                  createdAt),
            );
            daysMissed =
                today.difference(createdDate).inDays;
          }
        } else {
          final lastDate = _normalizeDate(
            DateTime.fromMillisecondsSinceEpoch(
                lastGivenAt),
          );
          daysMissed =
              today.difference(lastDate).inDays;

          // Already marked today — skip
          if (daysMissed == 0) continue;
        }

        if (daysMissed <= 0) continue;

        // Calculate new days remaining
        final newDaysRemaining =
            (daysRemaining - daysMissed)
                .clamp(0, daysRemaining);

        // Update Firestore
        await doc.reference.update({
          'daysRemaining': newDaysRemaining,
        });

        // Fire notification if low stock
        if (newDaysRemaining <= 7) {
          final itemName =
              data['itemName'] as String? ??
                  'Supplement';

          await notifService.showInstantNotification(
            id: doc.id.hashCode,
            title: '⚠️ Low Stock: $itemName',
            body: newDaysRemaining == 0
                ? '$itemName has run out — reorder now!'
                : 'Only $newDaysRemaining days remaining — time to reorder.',
          );
        }
      }
    } catch (e) {
      // Non-fatal — don't crash the app
    }
  }

  /// Normalize date to midnight so we compare
  /// only dates not times
  DateTime _normalizeDate(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}
