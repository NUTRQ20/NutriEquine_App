class Horse {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final String discipline;
  final int? ageYears;        // nullable — not every horse has age set
  final double? weightKg;     // nullable — not every horse has weight set
  final List<String> goals;
  final List<String> allergies;
  final String? vetName;
  final String? farrierName;
  final String? photoUrl;
  final List<String> sharedWith;
  final DateTime createdAt;

  Horse({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.discipline,
    this.ageYears,             // optional — no required, no default needed
    this.weightKg,             // optional — no required, no default needed
    this.goals = const [],     // optional with default
    this.allergies = const [], // optional with default
    this.vetName,
    this.farrierName,
    this.photoUrl,
    this.sharedWith = const [],
    required this.createdAt,
  });

  factory Horse.fromMap(String id, Map<String, dynamic> map) {
    return Horse(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      breed: map['breed'] ?? '',
      discipline: map['discipline'] ?? '',
      ageYears: map['ageYears'] != null
          ? (map['ageYears'] as num).toInt()
          : null,
      weightKg: map['weightKg'] != null
          ? (map['weightKg'] as num).toDouble()
          : null,
      goals: List<String>.from(map['goals'] ?? []),
      allergies: List<String>.from(map['allergies'] ?? []),
      vetName: map['vetName'],
      farrierName: map['farrierName'],
      photoUrl: map['photoUrl'],
      sharedWith: List<String>.from(map['sharedWith'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] ??
              DateTime.now().millisecondsSinceEpoch),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'discipline': discipline,
      'ageYears': ageYears,
      'weightKg': weightKg,
      'goals': goals,
      'allergies': allergies,
      'vetName': vetName,
      'farrierName': farrierName,
      'photoUrl': photoUrl,
      'sharedWith': sharedWith,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}