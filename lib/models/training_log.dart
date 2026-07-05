class TrainingLog {
  final String id;
  final String horseId;
  final String ownerId;
  final DateTime date;
  final String type; // Flatwork, Jumping, Trail, Conditioning, Rest, Show, Lesson
  final int durationMinutes;
  final String intensity; // Light, Moderate, Hard
  final int performanceRating; // 1-5
  final List<String> exercises;
  final String? notes;
  final String? trainerName;

  TrainingLog({
    required this.id,
    required this.horseId,
    required this.ownerId,
    required this.date,
    required this.type,
    required this.durationMinutes,
    required this.intensity,
    required this.performanceRating,
    this.exercises = const [],
    this.notes,
    this.trainerName,
  });

  factory TrainingLog.fromMap(String id, Map<String, dynamic> map) {
    return TrainingLog(
      id: id,
      horseId: map['horseId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
          map['date'] ?? DateTime.now().millisecondsSinceEpoch),
      type: map['type'] ?? 'Flatwork',
      durationMinutes: map['durationMinutes'] ?? 30,
      intensity: map['intensity'] ?? 'Moderate',
      performanceRating: map['performanceRating'] ?? 3,
      exercises: List<String>.from(map['exercises'] ?? []),
      notes: map['notes'],
      trainerName: map['trainerName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'ownerId': ownerId,
      'date': date.millisecondsSinceEpoch,
      'type': type,
      'durationMinutes': durationMinutes,
      'intensity': intensity,
      'performanceRating': performanceRating,
      'exercises': exercises,
      'notes': notes,
      'trainerName': trainerName,
    };
  }

  static const List<String> types = [
    'Flatwork',
    'Jumping',
    'Trail Ride',
    'Conditioning',
    'Lesson',
    'Show',
    'Groundwork',
    'Rest Day',
  ];

  static const List<String> intensityLevels = ['Light', 'Moderate', 'Hard'];
}
