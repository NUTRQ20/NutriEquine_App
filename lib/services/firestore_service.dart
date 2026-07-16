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

  CollectionReference<Map<String, dynamic>> get _horses =>
      _db.collection('horses');

  Stream<List<Horse>> streamHorses() {
    if (uid.isEmpty) return Stream.value([]);
    return _horses
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .asyncMap((ownedSnap) async {
      final owned = ownedSnap.docs
          .map((d) => Horse.fromMap(d.id, d.data()))
          .toList();
      try {
        final sharedSnap = await _horses
            .where('sharedWith', arrayContains: uid)
            .get();
        final shared = sharedSnap.docs
            .map((d) => Horse.fromMap(d.id, d.data()))
            .toList();
        final seen = <String>{};
        final all = <Horse>[];
        for (final h in [...owned, ...shared]) {
          if (seen.add(h.id)) all.add(h);
        }
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return all;
      } catch (_) {
        owned.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return owned;
      }
    });
  }

  Future<String> addHorse(Horse horse) async {
    final doc = await _horses.add(horse.toMap());
    return doc.id;
  }

  Future<void> updateHorse(String id, Map<String, dynamic> data) =>
      _horses.doc(id).update(data);

  Future<void> deleteHorse(String id) => _horses.doc(id).delete();

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

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

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

  CollectionReference<Map<String, dynamic>> get _feed =>
      _db.collection('feed_entries');

  Stream<List<FeedEntry>> streamFeedEntries(String horseId) {
    return _feed.where('horseId', isEqualTo: horseId).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => FeedEntry.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));
      return list;
    });
  }

  Future<void> addFeedEntry(FeedEntry entry) => _feed.add(entry.toMap());

  Future<void> markFeedGiven(String entryId) => _feed.doc(entryId)
      .update({'lastGivenAt': DateTime.now().millisecondsSinceEpoch});

  Future<void> decrementDaysRemaining(String entryId, int current) {
    final newVal = current - 1;
    return _feed
        .doc(entryId)
        .update({'daysRemaining': newVal < 0 ? 0 : newVal});
  }

  Future<void> resetInventory(String entryId, int daysOfSupply) =>
      _feed.doc(entryId).update(
          {'daysRemaining': daysOfSupply, 'refillAlertSent': false});

  Future<void> deleteFeedEntry(String id) => _feed.doc(id).delete();

  CollectionReference<Map<String, dynamic>> get _wellness =>
      _db.collection('wellness_logs');

  Stream<List<WellnessLog>> streamWellnessLogs(String horseId) {
    return _wellness
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => WellnessLog.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addWellnessLog(WellnessLog log) =>
      _wellness.add(log.toMap());

  CollectionReference<Map<String, dynamic>> get _reminders =>
      _db.collection('care_reminders');

  Stream<List<CareReminder>> streamReminders(String horseId) {
    return _reminders
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => CareReminder.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Stream<List<CareReminder>> streamAllReminders() {
    if (uid.isEmpty) return Stream.value([]);
    return _reminders
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => CareReminder.fromMap(d.id, d.data()))
          .toList();
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

  CollectionReference<Map<String, dynamic>> get _training =>
      _db.collection('training_logs');

  Stream<List<TrainingLog>> streamTrainingLogs(String horseId) {
    return _training
        .where('horseId', isEqualTo: horseId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => TrainingLog.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> addTrainingLog(TrainingLog log) =>
      _training.add(log.toMap());

  Future<void> deleteTrainingLog(String id) => _training.doc(id).delete();

  CollectionReference<Map<String, dynamic>> get _barnTasks =>
      _db.collection('barn_tasks');

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
    return _barnTasks
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => BarnTask.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  Future<void> addBarnTask(BarnTask task) => _barnTasks.add(task.toMap());

  Future<void> completeBarnTask(String id) =>
      _barnTasks.doc(id).update({
        'isComplete': true,
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });
  
  Future<void> uncompleteBarnTask(String id) =>
    _barnTasks.doc(id).update({
      'isComplete': false,
      'completedAt': null,
    });

  Future<void> deleteBarnTask(String id) => _barnTasks.doc(id).delete();

  Future<Map<String, List<Map<String, dynamic>>>> fetchAllUserData() async {
    final results = <String, List<Map<String, dynamic>>>{};
    Future<List<Map<String, dynamic>>> fetch(
        CollectionReference<Map<String, dynamic>> ref,
        String field) async {
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
}