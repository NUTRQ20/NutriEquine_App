class BarnTask {
  final String id;
  final String horseId;
  final String ownerId;
  final String title;
  final String category; // Feeding, Turnout, Blanketing, Meds, Stall Check, Grooming
  final String assignedTo; // name or email of staff
  final DateTime dueDate;
  final bool isComplete;
  final String? notes;
  final DateTime? completedAt;

  BarnTask({
    required this.id,
    required this.horseId,
    required this.ownerId,
    required this.title,
    required this.category,
    required this.assignedTo,
    required this.dueDate,
    this.isComplete = false,
    this.notes,
    this.completedAt,
  });

  bool get isOverdue =>
      !isComplete && dueDate.isBefore(DateTime.now());

  factory BarnTask.fromMap(String id, Map<String, dynamic> map) {
    return BarnTask(
      id: id,
      horseId: map['horseId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'General',
      assignedTo: map['assignedTo'] ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(
          map['dueDate'] ?? DateTime.now().millisecondsSinceEpoch),
      isComplete: map['isComplete'] ?? false,
      notes: map['notes'],
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'ownerId': ownerId,
      'title': title,
      'category': category,
      'assignedTo': assignedTo,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'isComplete': isComplete,
      'notes': notes,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  static const List<String> categories = [
    'Feeding',
    'Turnout',
    'Blanketing',
    'Medications',
    'Stall Check',
    'Grooming',
    'Farrier Prep',
    'Vet Prep',
    'General',
  ];
}
