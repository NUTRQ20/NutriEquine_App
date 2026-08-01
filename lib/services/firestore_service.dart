import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/horse.dart';
import '../models/care_models.dart';
import '../models/training_log.dart';
import '../models/barn_task.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get userEmail =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '';

  // ─── Collection references ────────────────────────────────────────────
  // All defined here so deleteHorse and deleteAllUserData can reuse them
  // without duplicating collection name strings.

  CollectionReference<Map<String, dynamic>> get _horses =>
      _db.collection('horses');

  CollectionReference<Map<String, dynamic>> get _feed =>
      _db.collection('feed_entries');

  CollectionReference<Map<String, dynamic>> get _wellness =>
      _db.collection('wellness_logs');

  CollectionReference<Map<String, dynamic>> get _reminders =>
      _db.collection('care_reminders');

  CollectionReference<Map<String, dynamic>> get _training =>
      _db.collection('training_logs');

  CollectionReference<Map<String, dynamic>> get _barnTasks =>
      _db.collection('barn_tasks');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ─── HORSES ──────────────────────────────────────────────────────────

  Stream<List<Horse>> streamHorses() {
    if (uid.isEmpty) return Stream.value([]);

    final ownedStream = _horses
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Horse.fromMap(d.id, d.data())).toList());

    final sharedStream = _horses
        .where('sharedWith', arrayContains: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Horse.fromMap(d.id, d.data())).toList());

    List<Horse> latestOwned = [];
    List<Horse> latestShared = [];

    List<Horse> merge() {
      final seen = <String>{};
      final all = <Horse>[];
      for (final h in [...latestOwned, ...latestShared]) {
        if (seen.add(h.id)) all.add(h);
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    }

    return Stream<List<Horse>>.multi((c) {
      ownedStream.listen((owned) {
        latestOwned = owned;
        c.add(merge());
      }, onError: c.addError);

      sharedStream.listen((shared) {
        latestShared = shared;
        c.add(merge());
      }, onError: c.addError);
    });
  }

  /// Wraps [streamHorses] and automatically cleans up orphaned data
  /// whenever a horse disappears from the stream.
  ///
  /// This handles the case where an admin deletes a horse document
  /// directly from the Firebase Console. In that case the app's
  /// [deleteHorse] method is never called, so feed entries, wellness
  /// logs, reminders, training logs, and barn tasks for that horse
  /// remain as orphaned documents.
  ///
  /// How it works:
  ///   1. Keeps track of the previous set of horse IDs.
  ///   2. Every time the stream emits a new list, compares it with
  ///      the previous list.
  ///   3. Any ID that was present before but is now missing means
  ///      that horse was deleted externally.
  ///   4. Calls [deleteHorse] for each missing ID to remove all
  ///      related documents.
  ///   5. The cleanup runs in the background — the UI updates
  ///      immediately and the cleanup happens silently after.
  Stream<List<Horse>> streamHorsesWithOrphanCleanup() {
    Set<String> previousIds = {};
    bool isFirstEmit = true;

    return streamHorses().asyncMap((horses) async {
      final currentIds = horses.map((h) => h.id).toSet();

      if (isFirstEmit) {
        // First emit — just record the initial set.
        // Don't treat missing IDs as deletions because we have no
        // previous state to compare against yet.
        isFirstEmit = false;
        previousIds = currentIds;
        return horses;
      }

      // Find IDs that were present before but are now gone
      final deletedIds = previousIds.difference(currentIds);

      // Update previous IDs before running cleanup
      previousIds = currentIds;

      // Clean up orphaned data for each deleted horse
      // Run in background — don't block the UI
      for (final horseId in deletedIds) {
        try {
          // deleteHorse handles feed_entries, wellness_logs,
          // care_reminders, training_logs, barn_tasks.
          // The horse document itself is already gone (admin deleted it)
          // so we only need to clean up related collections.
          await _cleanupOrphanedHorseData(horseId);
        } catch (_) {
          // Non-fatal — continue with other horses
        }
      }

      return horses;
    });
  }

  /// Deletes all documents related to [horseId] from every
  /// horse-dependent collection WITHOUT deleting the horse document
  /// itself (because it may already be gone when called from orphan
  /// cleanup).
  Future<void> _cleanupOrphanedHorseData(String horseId) async {
    final horseCollections = [
      _feed,
      _wellness,
      _reminders,
      _training,
      _barnTasks,
    ];

    final toDelete = <DocumentReference>[];

    for (final col in horseCollections) {
      final snap = await col.where('horseId', isEqualTo: horseId).get();
      for (final doc in snap.docs) {
        toDelete.add(doc.reference);
      }
    }

    if (toDelete.isEmpty) return;

    await _commitInChunks(toDelete);
  }

  Future<String> addHorse(Horse horse) async {
    final doc = await _horses.add(horse.toMap());
    return doc.id;
  }

  Future<void> updateHorse(String id, Map<String, dynamic> data) =>
      _horses.doc(id).update(data);

  /// Deletes a single horse and ALL its related data.
  ///
  /// This is the single source of truth for horse deletion.
  /// Both the user-initiated delete (horse list screen) and
  /// the account deletion flow call this method, ensuring
  /// consistent cleanup with no orphaned documents.
  ///
  /// Collections cleaned up:
  ///   feed_entries, wellness_logs, care_reminders,
  ///   training_logs, barn_tasks — all where horseId == id
  ///
  /// Commits in chunks of 500 to respect the Firestore batch limit.
  Future<void> deleteHorse(String horseId) async {
    // All collections that store horse-specific data
    final horseCollections = [
      _feed,
      _wellness,
      _reminders,
      _training,
      _barnTasks,
    ];

    final toDelete = <DocumentReference>[];

    // Collect all related documents
    for (final col in horseCollections) {
      final snap = await col.where('horseId', isEqualTo: horseId).get();
      for (final doc in snap.docs) {
        toDelete.add(doc.reference);
      }
    }

    // Delete the horse document itself last
    toDelete.add(_horses.doc(horseId));

    // Commit in chunks of 500 (Firestore hard limit per batch)
    await _commitInChunks(toDelete);
  }

  /// Deletes ALL horses owned by [ownerUid] and every piece of
  /// data related to each horse.
  ///
  /// Called during account deletion to ensure no orphaned data
  /// remains after the user's account is removed.
  Future<void> deleteAllHorsesForUser(String ownerUid) async {
    // Find every horse owned by this user
    final horsesSnap =
        await _horses.where('ownerId', isEqualTo: ownerUid).get();

    // Delete each horse and all its data using the canonical method
    for (final horseDoc in horsesSnap.docs) {
      await deleteHorse(horseDoc.id);
    }
  }

  /// Deletes the user profile document from the users collection.
  /// This is a critical security step — once this document is deleted,
  /// the Firestore rules block all CREATE and UPDATE operations for this user.
  /// Throws on error so callers can handle and log failures.
  Future<void> deleteUserProfile(String userUid) async {
    await _users.doc(userUid).delete();
  }

  Future<void> updateHorsePhoto(String horseId, String photoUrl) =>
      _horses.doc(horseId).update({'photoUrl': photoUrl});

  Future<void> shareHorseWithUser(String horseId, String targetUid) =>
      _horses.doc(horseId).update({
        'sharedWith': FieldValue.arrayUnion([targetUid]),
      });

  Future<void> removeSharedAccess(String horseId, String targetUid) =>
      _horses.doc(horseId).update({
        'sharedWith': FieldValue.arrayRemove([targetUid]),
      });

  // ─── USERS ───────────────────────────────────────────────────────────

  Future<void> registerUserEmail() async {
    if (uid.isEmpty || userEmail.isEmpty) return;
    try {
      await _users.doc(uid).set(
        {
          'email': userEmail,
          'uid': uid,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  Future<void> saveUserProfile(Map<String, dynamic> data) async {
    if (uid.isEmpty) return;
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> findUidByEmail(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    try {
      final snap = await _users
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['uid'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── FEED ENTRIES ────────────────────────────────────────────────────

  Stream<List<FeedEntry>> streamFeedEntries(String horseId) {
    return _feed.where('horseId', isEqualTo: horseId).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => FeedEntry.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));
      return list;
    });
  }

  Future<void> addFeedEntry(FeedEntry entry) => _feed.add(entry.toMap());

  Future<void> markFeedGiven(String entryId) => _feed
      .doc(entryId)
      .update({'lastGivenAt': DateTime.now().millisecondsSinceEpoch});

  Future<void> decrementDaysRemaining(String entryId, int current) {
    final newVal = current - 1;
    return _feed
        .doc(entryId)
        .update({'daysRemaining': newVal < 0 ? 0 : newVal});
  }

  Future<void> resetInventory(String entryId, int daysOfSupply) => _feed
      .doc(entryId)
      .update({'daysRemaining': daysOfSupply, 'refillAlertSent': false});

  Future<void> deleteFeedEntry(String id) => _feed.doc(id).delete();

  // ─── WELLNESS LOGS ───────────────────────────────────────────────────

  Stream<List<WellnessLog>> streamWellnessLogs(String horseId) {
    return _wellness
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => WellnessLog.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addWellnessLog(WellnessLog log) => _wellness.add(log.toMap());

  // ─── CARE REMINDERS ──────────────────────────────────────────────────

  Stream<List<CareReminder>> streamReminders(String horseId) {
    return _reminders
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => CareReminder.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Stream<List<CareReminder>> streamAllReminders() {
    if (uid.isEmpty) return Stream.value([]);
    return _reminders.where('ownerId', isEqualTo: uid).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => CareReminder.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Future<String> addReminder(CareReminder reminder) async {
    final doc = await _reminders.add(reminder.toMap());
    return doc.id;
  }

  Future<void> completeReminder(String id) =>
      _reminders.doc(id).update({'isComplete': true});

  Future<void> uncompleteReminder(String id) =>
      _reminders.doc(id).update({'isComplete': false});

  Future<void> deleteReminder(String id) => _reminders.doc(id).delete();

  // ─── TRAINING LOGS ───────────────────────────────────────────────────

  Stream<List<TrainingLog>> streamTrainingLogs(String horseId) {
    return _training
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => TrainingLog.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addTrainingLog(TrainingLog log) => _training.add(log.toMap());

  Future<void> deleteTrainingLog(String id) => _training.doc(id).delete();

  Stream<List<TrainingLog>> streamAllTrainingLogs() {
    if (uid.isEmpty) return Stream.value([]);
    return _training.where('ownerId', isEqualTo: uid).snapshots().map((snap) =>
        snap.docs.map((d) => TrainingLog.fromMap(d.id, d.data())).toList());
  }

  // ─── BARN TASKS ──────────────────────────────────────────────────────

  Stream<List<BarnTask>> streamBarnTasks(String horseId) {
    return _barnTasks
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => BarnTask.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Stream<List<BarnTask>> streamAllBarnTasks() {
    if (uid.isEmpty) return Stream.value([]);
    return _barnTasks.where('ownerId', isEqualTo: uid).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => BarnTask.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Future<void> addBarnTask(BarnTask task) => _barnTasks.add(task.toMap());

  Future<void> completeBarnTask(String id) => _barnTasks.doc(id).update({
        'isComplete': true,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> uncompleteBarnTask(String id) => _barnTasks.doc(id).update({
        'isComplete': false,
        'completedAt': null,
      });

  Future<void> deleteBarnTask(String id) => _barnTasks.doc(id).delete();

  // ─── DATA VIEWER ─────────────────────────────────────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> fetchAllUserData() async {
    final results = <String, List<Map<String, dynamic>>>{};
    Future<List<Map<String, dynamic>>> fetch(
        CollectionReference<Map<String, dynamic>> ref, String field) async {
      final snap = await ref.where(field, isEqualTo: uid).get();
      return snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList();
    }

    results['horses'] = await fetch(_horses, 'ownerId');
    results['feed_entries'] = await fetch(_feed, 'ownerId');
    results['wellness_logs'] = await fetch(_wellness, 'ownerId');
    results['care_reminders'] = await fetch(_reminders, 'ownerId');
    results['training_logs'] = await fetch(_training, 'ownerId');
    results['barn_tasks'] = await fetch(_barnTasks, 'ownerId');
    return results;
  }

  // ─── INTERNAL HELPERS ─────────────────────────────────────────────────

  /// Commits a list of delete operations in chunks of 500.
  /// Firestore batches are limited to 500 operations each.
  Future<void> _commitInChunks(List<DocumentReference> refs) async {
    const chunkSize = 500;
    for (int i = 0; i < refs.length; i += chunkSize) {
      final chunk = refs.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
