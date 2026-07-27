import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/horse.dart';
import '../models/care_models.dart';
import '../models/training_log.dart';
import '../models/barn_task.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'analytics_screen.dart';
import 'shared_access_screen.dart';
import 'supplement_protocol_screen.dart';

class HorseDetailScreen extends StatelessWidget {
  final Horse horse;
  const HorseDetailScreen({super.key, required this.horse});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(horse.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Analytics',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AnalyticsScreen(horse: horse))),
            ),
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Team access',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SharedAccessScreen(horse: horse))),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Feed Plan'),
              Tab(text: 'Wellness'),
              Tab(text: 'Training'),
              Tab(text: 'Reminders'),
              Tab(text: 'Barn Tasks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(horse: horse),
            _FeedPlanTab(horse: horse),
            _WellnessTab(horse: horse),
            _TrainingTab(horse: horse),
            _RemindersTab(horse: horse),
            _BarnTasksTab(horse: horse),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── PROFILE TAB ───────────────────────────
class _ProfileTab extends StatelessWidget {
  final Horse horse;
  const _ProfileTab({required this.horse});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final storage = context.read<StorageService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor:
                    const Color(0xFF2F5233).withOpacity(0.15),
                backgroundImage: horse.photoUrl != null
                    ? NetworkImage(horse.photoUrl!)
                    : null,
                child: horse.photoUrl == null
                    ? Text(
                        horse.name.isNotEmpty
                            ? horse.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F5233)),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton.small(
                  heroTag: 'photo_fab_${horse.id}',
                  onPressed: () async {
                    try {
                      final url =
                          await storage.pickAndUploadHorsePhoto(horse.id);
                      if (url != null) {
                        await fs.updateHorsePhoto(horse.id, url);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Photo updated!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error uploading photo: $e')),
                        );
                      }
                    }
                  },
                  child: const Icon(Icons.camera_alt, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _InfoTile('Name', horse.name),
        _InfoTile(
            'Breed', horse.breed.isNotEmpty ? horse.breed : '--'),
        _InfoTile('Discipline',
            horse.discipline.isNotEmpty ? horse.discipline : '--'),
        _InfoTile('Age',
            horse.ageYears != null ? '${horse.ageYears} years' : '--'),
        _InfoTile('Weight',
            horse.weightKg != null ? '${horse.weightKg} kg' : '--'),
        _InfoTile('Vet', horse.vetName ?? '--'),
        _InfoTile('Farrier', horse.farrierName ?? '--'),
        if (horse.goals.isNotEmpty)
          _InfoTile('Goals', horse.goals.join(', ')),
        if (horse.allergies.isNotEmpty)
          _InfoTile('Allergies', horse.allergies.join(', ')),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.science_outlined),
          label: const Text('Get Supplement Protocol for this horse'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => Navigator.push(
           context,
          MaterialPageRoute(
          builder: (_) => SupplementProtocolScreen(
          horse: horse)),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Answer 3 questions to get a personalized NutriEquine supplement recommendation.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// Shared info tile widget used by _ProfileTab
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ─────────────────────────── FEED PLAN TAB ───────────────────────────
// ─────────────────────────── FEED PLAN TAB ───────────────────────────
class _FeedPlanTab extends StatefulWidget {
  final Horse horse;
  const _FeedPlanTab({required this.horse});
  @override
  State<_FeedPlanTab> createState() => _FeedPlanTabState();
}

class _FeedPlanTabState extends State<_FeedPlanTab> {
  // Track which entries were just marked given for instant UI feedback
  final Set<String> _justMarked = {};

  void _addFeedEntry(BuildContext context) {
    final itemCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    String timeOfDay = 'AM';
    bool isSupplement = true;
    final fs = context.read<FirestoreService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add feed / supplement',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(
                    labelText: 'Item name (e.g. NutriEquine GutCare)'),
              ),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(
                    labelText: 'Dosage (e.g. 1 scoop)'),
              ),
              TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Days of supply (for inventory tracking)'),
              ),
              DropdownButtonFormField<String>(
                value: timeOfDay,
                items: ['AM', 'Midday', 'PM']
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => timeOfDay = v ?? 'AM'),
                decoration:
                    const InputDecoration(labelText: 'Time of day'),
              ),
              SwitchListTile(
                value: isSupplement,
                onChanged: (v) =>
                    setSheetState(() => isSupplement = v),
                title: const Text('This is a NutriEquine supplement'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (itemCtrl.text.trim().isEmpty) return;
                  final days = int.tryParse(daysCtrl.text.trim());
                  final entry = FeedEntry(
                    id: const Uuid().v4(),
                    horseId: widget.horse.id,
                    ownerId: fs.uid,
                    itemName: itemCtrl.text.trim(),
                    dosage: dosageCtrl.text.trim(),
                    timeOfDay: timeOfDay,
                    isSupplement: isSupplement,
                    daysOfSupply: days,
                    daysRemaining: days,
                  );
                  await fs.addFeedEntry(entry);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return Scaffold(
      body: StreamBuilder<List<FeedEntry>>(
        stream: fs.streamFeedEntries(widget.horse.id),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No feed or supplement entries yet.\nTap + to add one.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView(
            children: entries.map((e) {
              final lowStock = e.isLowStock;
              final justMarked = _justMarked.contains(e.id);

              return Card(
                color: lowStock ? Colors.orange.shade50 : null,
                child: ListTile(
  leading: Icon(
    e.isSupplement ? Icons.science : Icons.grass,
    color: lowStock ? Colors.orange : null,
    size: 20,
  ),
  // Title — item name only
  title: Text(
    e.itemName,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  ),
  // Subtitle — dosage, time, duration on separate lines
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 2),
      // Dosage on its own line
      Text(
        e.dosage,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 2),
      // Time of day + last given
      Text(
        justMarked
            ? '${e.timeOfDay} · just given ✅'
            : '${e.timeOfDay}${e.lastGivenAt != null ? " · last given ${DateFormat.MMMd().add_jm().format(e.lastGivenAt!)}" : ""}',
        style: const TextStyle(fontSize: 12),
      ),
      // Days remaining / duration
      if (e.daysRemaining != null) ...[
        const SizedBox(height: 2),
        Text(
          '${e.daysRemaining} days remaining'
          '${lowStock ? " · REORDER SOON" : ""}',
          style: TextStyle(
            fontSize: 12,
            color: lowStock
                ? Colors.orange.shade800
                : Colors.grey,
            fontWeight: lowStock
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
      // Duration from daysOfSupply
      if (e.daysOfSupply != null) ...[
        const SizedBox(height: 2),
        Text(
          'Supply: ${e.daysOfSupply} days total',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    ],
  ),
  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          justMarked
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: justMarked
                              ? Colors.green
                              : null,
                        ),
                        tooltip: 'Mark given',
                        onPressed: () async {
                          // Instant UI feedback
                          setState(() =>
                              _justMarked.add(e.id));
                          await fs.markFeedGiven(e.id);
                          if (e.daysRemaining != null &&
                              e.daysRemaining! > 0) {
                            await fs.decrementDaysRemaining(
                                e.id, e.daysRemaining!);
                          }
                          if (e.isLowStock) {
                            await NotificationService()
                                .showInstantNotification(
                              id: e.id.hashCode,
                              title:
                                  'Low Stock: ${e.itemName}',
                              body:
                                  'Only ${e.daysRemaining} days remaining — time to reorder.',
                            );
                          }
                        },
                      ),
                      if (e.daysOfSupply != null)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reset inventory',
                          onPressed: () {
                            setState(() =>
                                _justMarked.remove(e.id));
                            fs.resetInventory(
                                e.id, e.daysOfSupply!);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () =>
                            fs.deleteFeedEntry(e.id),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addFeedEntry(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
// ─────────────────────────── WELLNESS TAB ───────────────────────────
class _WellnessTab extends StatelessWidget {
  final Horse horse;
  const _WellnessTab({required this.horse});

  static const _symptoms = [
    'Pawing',
    'Looking at flank',
    'Lack of energy',
    'Head shaking',
    'Girthiness',
    'Reluctance to work',
    'Excessive sweating',
    'Nasal discharge',
  ];

  void _addLog(BuildContext context) {
    String appetite = 'Good';
    String manure = 'Normal';
    double bcs = 5;
    final notesCtrl = TextEditingController();
    final envCtrl = TextEditingController();
    final actionCtrl = TextEditingController();
    final selectedSymptoms = <String>{};
    final fs = context.read<FirestoreService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Daily wellness check-in',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: appetite,
                  items: ['Good', 'Reduced', 'None']
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => appetite = v ?? 'Good'),
                  decoration:
                      const InputDecoration(labelText: 'Appetite'),
                ),
                DropdownButtonFormField<String>(
                  value: manure,
                  items: ['Normal', 'Loose', 'Hard', 'Mucus', 'Other']
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => manure = v ?? 'Normal'),
                  decoration:
                      const InputDecoration(labelText: 'Manure'),
                ),
                Text('Body condition score: ${bcs.round()} / 9'),
                Slider(
                  value: bcs,
                  min: 1,
                  max: 9,
                  divisions: 8,
                  label: bcs.round().toString(),
                  onChanged: (v) => setState(() => bcs = v),
                ),
                const Text('Observed symptoms:',
                    style:
                        TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: _symptoms
                      .map((s) => FilterChip(
                            label: Text(s),
                            selected: selectedSymptoms.contains(s),
                            onSelected: (v) => setState(() => v
                                ? selectedSymptoms.add(s)
                                : selectedSymptoms.remove(s)),
                          ))
                      .toList(),
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Behavior notes'),
                ),
                TextField(
                  controller: envCtrl,
                  decoration: const InputDecoration(
                      labelText:
                          'Environment / diet changes today'),
                ),
                TextField(
                  controller: actionCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Action taken'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final flagged = appetite == 'None' ||
                        manure == 'Loose' ||
                        selectedSymptoms.isNotEmpty;
                    await fs.addWellnessLog(WellnessLog(
                      id: const Uuid().v4(),
                      horseId: horse.id,
                      ownerId: fs.uid,
                      date: DateTime.now(),
                      appetite: appetite,
                      manure: manure,
                      bodyConditionScore: bcs.round(),
                      behaviorNotes:
                          notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                      environmentNotes:
                          envCtrl.text.trim().isEmpty
                              ? null
                              : envCtrl.text.trim(),
                      symptoms: selectedSymptoms.toList(),
                      flaggedForVet: flagged,
                      actionTaken: actionCtrl.text.trim(),
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (flagged && context.mounted) {
                      _showActionGuidance(context, appetite,
                          manure, selectedSymptoms.toList());
                    }
                  },
                  child: const Text('Save check-in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionGuidance(BuildContext context, String appetite,
      String manure, List<String> symptoms) {
    final List<String> steps = [
      'Monitor every 2 hours for the next 12 hours.',
      'Check water intake - dehydration worsens many conditions.',
      'Review any recent feed or environment changes.',
      'Check manure frequency - no manure for 12+ hours is urgent.',
    ];
    if (appetite == 'None') {
      steps.add(
          'Appetite loss with no manure or colic signs - call your vet now.');
    }
    if (manure == 'Loose') {
      steps.add(
          'Loose manure with no other symptoms - monitor for 24 hours. If persisting, call vet.');
    }
    if (symptoms.contains('Pawing') ||
        symptoms.contains('Looking at flank')) {
      steps.insert(0,
          'Possible colic signs observed - contact your vet immediately.');
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Observation-to-Action Guide'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'These flags were logged. Recommended next steps:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...steps.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('- '),
                      Expanded(child: Text(s)),
                    ],
                  ),
                )),
            const Divider(),
            const Text(
                'This guidance is informational only and does not replace veterinary diagnosis.',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return Scaffold(
      body: StreamBuilder<List<WellnessLog>>(
        stream: fs.streamWellnessLogs(horse.id),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(
                child: Text('No wellness logs yet.'));
          }
          return ListView(
            children: logs.map((l) {
              return Card(
                color: l.flaggedForVet
                    ? Colors.orange.shade50
                    : null,
                child: ListTile(
                  leading: Icon(
                    l.flaggedForVet
                        ? Icons.warning_amber
                        : Icons.check_circle_outline,
                    color: l.flaggedForVet
                        ? Colors.orange
                        : Colors.green,
                  ),
                  title: Text(
                      DateFormat.yMMMd().add_jm().format(l.date)),
                  subtitle: Text(
                    'Appetite: ${l.appetite} - Manure: ${l.manure} - BCS: ${l.bodyConditionScore}/9'
                    '${l.symptoms.isNotEmpty ? "\nSymptoms: ${l.symptoms.join(", ")}" : ""}'
                    '${l.behaviorNotes != null ? "\n${l.behaviorNotes}" : ""}',
                  ),
                  isThreeLine: l.symptoms.isNotEmpty ||
                      l.behaviorNotes != null,
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addLog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────── TRAINING TAB ───────────────────────────
class _TrainingTab extends StatelessWidget {
  final Horse horse;
  const _TrainingTab({required this.horse});

  void _addLog(BuildContext context) {
    String type = 'Flatwork';
    String intensity = 'Moderate';
    double rating = 3;
    final durationCtrl = TextEditingController(text: '45');
    final notesCtrl = TextEditingController();
    final trainerCtrl = TextEditingController();
    final fs = context.read<FirestoreService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Log training session',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  items: TrainingLog.types
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => type = v ?? 'Flatwork'),
                  decoration: const InputDecoration(
                      labelText: 'Session type'),
                ),
                DropdownButtonFormField<String>(
                  value: intensity,
                  items: TrainingLog.intensityLevels
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => intensity = v ?? 'Moderate'),
                  decoration: const InputDecoration(
                      labelText: 'Intensity'),
                ),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Duration (minutes)'),
                ),
                Text(
                    'Performance rating: ${rating.round()} / 5'),
                Slider(
                  value: rating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: rating.round().toString(),
                  onChanged: (v) => setState(() => rating = v),
                ),
                TextField(
                  controller: trainerCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Trainer name (optional)'),
                ),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Session notes'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await fs.addTrainingLog(TrainingLog(
                      id: const Uuid().v4(),
                      horseId: horse.id,
                      ownerId: fs.uid,
                      date: DateTime.now(),
                      type: type,
                      intensity: intensity,
                      durationMinutes: int.tryParse(
                              durationCtrl.text.trim()) ??
                          45,
                      performanceRating: rating.round(),
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      trainerName:
                          trainerCtrl.text.trim().isEmpty
                              ? null
                              : trainerCtrl.text.trim(),
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return Scaffold(
      body: StreamBuilder<List<TrainingLog>>(
        stream: fs.streamTrainingLogs(horse.id),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(
                child: Text('No training sessions yet.'));
          }
          return ListView(
            children: logs.map((l) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      '${l.performanceRating}*',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  title: Text(
                      '${l.type} - ${l.durationMinutes} min - ${l.intensity}'),
                  subtitle: Text(
                    DateFormat.yMMMd().format(l.date) +
                        (l.trainerName != null
                            ? ' - ${l.trainerName}'
                            : '') +
                        (l.notes != null ? '\n${l.notes}' : ''),
                  ),
                  isThreeLine: l.notes != null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        fs.deleteTrainingLog(l.id),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addLog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────── REMINDERS TAB ───────────────────────────
class _RemindersTab extends StatelessWidget {
  final Horse horse;
  const _RemindersTab({required this.horse});

  void _addReminder(BuildContext context) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Vet';
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    final fs = context.read<FirestoreService>();
    final notifs = context.read<NotificationService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add reminder',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Title')),
              DropdownButtonFormField<String>(
                value: category,
                items: [
                  'Vet', 'Farrier', 'Dental', 'Deworm',
                  'Vaccine', 'Supplement Refill', 'General'
                ]
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => category = v ?? 'Vet'),
                decoration: const InputDecoration(
                    labelText: 'Category'),
              ),
              TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Due: ${DateFormat.yMMMd().format(dueDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 730)),
                  );
                  if (picked != null)
                    setState(() => dueDate = picked);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final reminder = CareReminder(
                    id: const Uuid().v4(),
                    horseId: horse.id,
                    ownerId: fs.uid,
                    title: titleCtrl.text.trim(),
                    dueDate: dueDate,
                    category: category,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );
                  final docId = await fs.addReminder(reminder);
                  await notifs.scheduleReminderNotification(
                    id: docId.hashCode,
                    title: '${horse.name}: ${reminder.title}',
                    body:
                        '${reminder.category} reminder due tomorrow.',
                    scheduledDate: dueDate,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save reminder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return Scaffold(
      body: StreamBuilder<List<CareReminder>>(
        stream: fs.streamReminders(horse.id),
        builder: (context, snapshot) {
          final reminders = snapshot.data ?? [];
          if (reminders.isEmpty) {
            return const Center(
                child: Text('No reminders yet.'));
          }
          return ListView(
            children: reminders.map((r) {
              Color? cardColor;
              if (r.isOverdue) cardColor = Colors.red.shade50;
              if (r.isDueSoon)
                cardColor = Colors.yellow.shade50;
              return Card(
                color: cardColor,
                child: CheckboxListTile(
                  value: r.isComplete,
                  onChanged: (_) {
                    if (r.isComplete) {
                      fs.uncompleteReminder(r.id);
                    } else {
                      fs.completeReminder(r.id);
                    }
                  },
                  title: Text(
                    r.title,
                    style: TextStyle(
                      decoration: r.isComplete
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: r.isOverdue
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${r.category} - Due ${DateFormat.yMMMd().format(r.dueDate)}'
                    '${r.isOverdue ? " - OVERDUE" : r.isDueSoon ? " - DUE SOON" : ""}'
                    '${r.notes != null ? "\n${r.notes}" : ""}',
                    style: TextStyle(
                        color:
                            r.isOverdue ? Colors.red : null),
                  ),
                  isThreeLine: r.notes != null,
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => fs.deleteReminder(r.id),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addReminder(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────── BARN TASKS TAB ───────────────────────────
class _BarnTasksTab extends StatelessWidget {
  final Horse horse;
  const _BarnTasksTab({required this.horse});

  void _addTask(BuildContext context) {
    final titleCtrl = TextEditingController();
    final assignedCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Feeding';
    DateTime dueDate = DateTime.now();
    final fs = context.read<FirestoreService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Assign barn task',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Task title')),
              TextField(
                  controller: assignedCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Assigned to (name)')),
              DropdownButtonFormField<String>(
                value: category,
                items: BarnTask.categories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => category = v ?? 'Feeding'),
                decoration: const InputDecoration(
                    labelText: 'Category'),
              ),
              TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Due: ${DateFormat.yMMMd().format(dueDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate,
                    firstDate: DateTime.now()
                        .subtract(const Duration(days: 1)),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null)
                    setState(() => dueDate = picked);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  await fs.addBarnTask(BarnTask(
                    id: const Uuid().v4(),
                    horseId: horse.id,
                    ownerId: fs.uid,
                    title: titleCtrl.text.trim(),
                    category: category,
                    assignedTo: assignedCtrl.text.trim(),
                    dueDate: dueDate,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return Scaffold(
      body: StreamBuilder<List<BarnTask>>(
        stream: fs.streamBarnTasks(horse.id),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
                child: Text('No barn tasks assigned.'));
          }
          return ListView(
            children: tasks.map((t) {
              return Card(
                color: t.isOverdue && !t.isComplete
                    ? Colors.red.shade50
                    : null,
                child: CheckboxListTile(
                  value: t.isComplete,
                  onChanged: (_) {
                    if (t.isComplete) {
                      fs.uncompleteBarnTask(t.id);
                    } else {
                      fs.completeBarnTask(t.id);
                    }
                  },
                  title: Text(
                    t.title,
                    style: TextStyle(
                        decoration: t.isComplete
                            ? TextDecoration.lineThrough
                            : null),
                  ),
                  subtitle: Text(
                    '${t.category} - ${t.assignedTo.isNotEmpty ? "-> ${t.assignedTo}" : "Unassigned"} - ${DateFormat.yMMMd().format(t.dueDate)}'
                    '${t.isOverdue && !t.isComplete ? " - OVERDUE" : ""}'
                    '${t.notes != null ? "\n${t.notes}" : ""}',
                  ),
                  isThreeLine: t.notes != null,
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => fs.deleteBarnTask(t.id),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTask(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}