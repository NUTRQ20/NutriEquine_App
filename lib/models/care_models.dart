class FeedEntry {
  final String id;
  final String horseId;
  final String ownerId;
  final String itemName;
  final String dosage;
  final String timeOfDay; // AM / PM / Midday
  final bool isSupplement;
  final int? daysOfSupply;   // total days when full
  final int? daysRemaining;  // countdown
  final DateTime? lastGivenAt;
  final bool refillAlertSent;

  FeedEntry({
    required this.id,
    required this.horseId,
    required this.ownerId,
    required this.itemName,
    required this.dosage,
    required this.timeOfDay,
    this.isSupplement = true,
    this.daysOfSupply,
    this.daysRemaining,
    this.lastGivenAt,
    this.refillAlertSent = false,
  });

  bool get isLowStock => daysRemaining != null && daysRemaining! <= 7;

  factory FeedEntry.fromMap(String id, Map<String, dynamic> map) {
    return FeedEntry(
      id: id,
      horseId: map['horseId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      itemName: map['itemName'] ?? '',
      dosage: map['dosage'] ?? '',
      timeOfDay: map['timeOfDay'] ?? 'AM',
      isSupplement: map['isSupplement'] ?? true,
      daysOfSupply: map['daysOfSupply'],
      daysRemaining: map['daysRemaining'],
      lastGivenAt: map['lastGivenAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastGivenAt'])
          : null,
      refillAlertSent: map['refillAlertSent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'ownerId': ownerId,
      'itemName': itemName,
      'dosage': dosage,
      'timeOfDay': timeOfDay,
      'isSupplement': isSupplement,
      'daysOfSupply': daysOfSupply,
      'daysRemaining': daysRemaining,
      'lastGivenAt': lastGivenAt?.millisecondsSinceEpoch,
      'refillAlertSent': refillAlertSent,
    };
  }
}

class WellnessLog {
  final String id;
  final String horseId;
  final String ownerId;
  final DateTime date;
  final String appetite; // Good / Reduced / None
  final String manure;   // Normal / Loose / Hard / Other
  final int bodyConditionScore; // 1-9 Henneke
  final double? waterIntakeLiters;
  final String? behaviorNotes;
  final String? environmentNotes;
  final List<String> symptoms; // list of observed symptoms
  final bool flaggedForVet;
  final String actionTaken; // what the owner did

  WellnessLog({
    required this.id,
    required this.horseId,
    required this.ownerId,
    required this.date,
    required this.appetite,
    required this.manure,
    required this.bodyConditionScore,
    this.waterIntakeLiters,
    this.behaviorNotes,
    this.environmentNotes,
    this.symptoms = const [],
    this.flaggedForVet = false,
    this.actionTaken = '',
  });

  factory WellnessLog.fromMap(String id, Map<String, dynamic> map) {
    return WellnessLog(
      id: id,
      horseId: map['horseId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
          map['date'] ?? DateTime.now().millisecondsSinceEpoch),
      appetite: map['appetite'] ?? 'Good',
      manure: map['manure'] ?? 'Normal',
      bodyConditionScore: map['bodyConditionScore'] ?? 5,
      waterIntakeLiters: (map['waterIntakeLiters'] as num?)?.toDouble(),
      behaviorNotes: map['behaviorNotes'],
      environmentNotes: map['environmentNotes'],
      symptoms: List<String>.from(map['symptoms'] ?? []),
      flaggedForVet: map['flaggedForVet'] ?? false,
      actionTaken: map['actionTaken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'ownerId': ownerId,
      'date': date.millisecondsSinceEpoch,
      'appetite': appetite,
      'manure': manure,
      'bodyConditionScore': bodyConditionScore,
      'waterIntakeLiters': waterIntakeLiters,
      'behaviorNotes': behaviorNotes,
      'environmentNotes': environmentNotes,
      'symptoms': symptoms,
      'flaggedForVet': flaggedForVet,
      'actionTaken': actionTaken,
    };
  }
}

class CareReminder {
  final String id;
  final String horseId;
  final String ownerId;
  final String title;
  final DateTime dueDate;
  final String category; // Vet, Farrier, Dental, Deworm, Vaccine, Supplement Refill
  final bool isComplete;
  final String? notes;
  final bool notificationScheduled;

  CareReminder({
    required this.id,
    required this.horseId,
    required this.ownerId,
    required this.title,
    required this.dueDate,
    required this.category,
    this.isComplete = false,
    this.notes,
    this.notificationScheduled = false,
  });

  bool get isOverdue =>
      !isComplete && dueDate.isBefore(DateTime.now());

  bool get isDueSoon =>
      !isComplete &&
      dueDate.isAfter(DateTime.now()) &&
      dueDate.difference(DateTime.now()).inDays <= 3;

  factory CareReminder.fromMap(String id, Map<String, dynamic> map) {
    return CareReminder(
      id: id,
      horseId: map['horseId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(
          map['dueDate'] ?? DateTime.now().millisecondsSinceEpoch),
      category: map['category'] ?? 'General',
      isComplete: map['isComplete'] ?? false,
      notes: map['notes'],
      notificationScheduled: map['notificationScheduled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'ownerId': ownerId,
      'title': title,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'category': category,
      'isComplete': isComplete,
      'notes': notes,
      'notificationScheduled': notificationScheduled,
    };
  }
}
