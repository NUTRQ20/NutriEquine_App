import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../models/horse.dart';
import '../services/firestore_service.dart';
import '../models/care_models.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

class SupplementProtocolScreen extends StatefulWidget {
  final Horse? horse;
  const SupplementProtocolScreen({super.key, this.horse});
  @override
  State<SupplementProtocolScreen> createState() =>
      _SupplementProtocolScreenState();
}

class _SupplementProtocolScreenState
    extends State<SupplementProtocolScreen> {
  int _step = 0;
final Set<String> _goals = {};
_Protocol? _result;
  bool get _isLoggedIn =>
      FirebaseAuth.instance.currentUser != null;

  static const _goalOptions = [
    '🫁 Gut health & ulcer prevention',
    '🦵 Joint & mobility support',
    '✨ Coat, hoof & skin quality',
    '⚡ Performance & recovery',
    '🐎 Senior horse support',
    '🧘 Stress & calming',
    '⚖️ Weight management',
    '🛡️ Immune support',
  ];

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  void _generateProtocol() {
    final recs = <_SupplementRec>[];
    if (_goals.any((g) => g.contains('Gut'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine GutCare',
        dosage: '1 scoop twice daily with feed',
        timing: 'AM and PM',
        duration: '90 days minimum',
        notes: 'Give consistently at the same time daily. '
            'Works best when fed with a small amount of hay.',
        monitor: 'Appetite, manure consistency, girthiness',
      ));
    }
    if (_goals.any((g) => g.contains('Joint'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine FlexSupport',
        dosage: '2 scoops daily',
        timing: 'AM feed',
        duration: '60–90 days to assess effect',
        notes: 'Evaluate after 60 days for changes in stride.',
        monitor:
            'Stride length, stiffness after rest, willingness on circles',
      ));
    }
    if (_goals.any((g) => g.contains('Coat'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine CoatShine',
        dosage: '1 scoop daily',
        timing: 'Any meal',
        duration: '90 days (hoof improvement 6–12 months)',
        notes: 'Biotin, zinc, copper and omega-3s.',
        monitor: 'Coat sheen, hoof wall hardness',
      ));
    }
    if (_goals.any((g) => g.contains('Performance'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine RecoveryBlend',
        dosage: '2 scoops post-exercise',
        timing: 'Within 1 hour of hard work',
        duration: 'Ongoing during training season',
        notes: 'Always ensure fresh water is available.',
        monitor: 'Recovery time, muscle soreness, topline',
      ));
    }
    if (_goals.any((g) => g.contains('Senior'))){
      recs.add(_SupplementRec(
        name: 'NutriEquine SeniorVital',
        dosage: '2 scoops daily',
        timing: 'Split AM and PM',
        duration: 'Long-term / ongoing',
        notes: 'Designed for horses 15+.',
        monitor: 'BCS monthly, topline, water intake',
      ));
    }
    if (_goals.any((g) => g.contains('Stress'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine CalmMag',
        dosage: '1 scoop daily',
        timing: 'Morning feed',
        duration: '30 days trial',
        notes: 'Magnesium-based. Not sedating.',
        monitor: 'Spookiness, focus during work',
      ));
    }
    if (recs.isEmpty) {
      recs.add(_SupplementRec(
        name: 'NutriEquine DailyFoundation',
        dosage: '1 scoop daily',
        timing: 'Any meal',
        duration: 'Ongoing',
        notes: 'Comprehensive daily vitamin-mineral supplement.',
        monitor: 'Overall condition, energy, coat quality',
      ));
    }
    setState(() => _result = _Protocol(
    goals: _goals.toList(),
      recommendations: recs,
));
    _next();
  }

Future<void> _addToFeedPlan(
    BuildContext context) async {
  if (widget.horse == null || _result == null) return;

  final fs = context.read<FirestoreService>();
  int added = 0;

  for (final rec in _result!.recommendations) {
    // Parse timing to AM/PM/Midday
    String timeOfDay = 'AM';
    if (rec.timing.toLowerCase().contains('pm')) {
      timeOfDay = 'PM';
    } else if (rec.timing.toLowerCase().contains('midday') ||
        rec.timing.toLowerCase().contains('noon')) {
      timeOfDay = 'Midday';
    }

    // Parse days from duration string
// e.g. "90 days minimum" → 90
// e.g. "60–90 days" → 60
int? parsedDays;
final durationText = rec.duration.toLowerCase();
final match = RegExp(r'\d+').firstMatch(durationText);
if (match != null) {
  parsedDays = int.tryParse(match.group(0) ?? '');
}

final entry = FeedEntry(
  id: const Uuid().v4(),
  horseId: widget.horse!.id,
  ownerId: fs.uid,
  itemName: rec.name,
  dosage: rec.dosage,
  timeOfDay: timeOfDay,
  isSupplement: true,
  daysOfSupply: parsedDays,
  daysRemaining: parsedDays,
);

    await fs.addFeedEntry(entry);
    added++;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$added supplements added to '
          "${widget.horse!.name}'s feed plan!",
        ),
        backgroundColor: Colors.green,
      ),
    );
    // Pop back to horse profile
    Navigator.pop(context);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplement Protocol'),
        leading: _step > 0 && _result == null
            ? BackButton(onPressed: _back)
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoggedIn ? _buildStep() : _buildLoginPrompt(),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Sign in required',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Please sign in to access the supplement protocol quiz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
            onPressed: () =>
                Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (_) => const LoginScreen()),
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
  switch (_step) {
    case 0: return _buildGoalsStep();
    case 1: return _buildResultStep();
    default: return const SizedBox();
  }
}

  Widget _buildGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Step 1 of 1',
    style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Text('What are your primary health goals?',
            style: Theme.of(context).textTheme.titleLarge),
        const Text('Select all that apply.'),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: _goalOptions
                .map((g) => CheckboxListTile(
                      value: _goals.contains(g),
                      title: Text(g),
                      onChanged: (v) => setState(() =>
                          v! ? _goals.add(g) : _goals.remove(g)),
                    ))
                .toList(),
          ),
        ),
        FilledButton(
          onPressed: _generateProtocol,
          child: const Text('Generate my protocol'),
        ),
      ],
    );
  }

  Widget _buildResultStep() {
    if (_result == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Personalized Protocol',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: _result!.recommendations.map((r) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      _ProtocolRow('Dosage', r.dosage),
                      _ProtocolRow('Timing', r.timing),
                      _ProtocolRow('Duration', r.duration),
                      const Divider(),
                      Text(r.notes,
                          style: const TextStyle(
                              color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Monitor: ${r.monitor}',
                          style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Text(
          'Educational only — not a veterinary diagnosis. '
          'Consult your vet before starting any new supplement.',
          style:
              TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (widget.horse != null)
  FilledButton.icon(
    icon: const Icon(Icons.add),
    label: Text(
        "Add to ${widget.horse!.name}'s feed plan"),
    onPressed: () => _addToFeedPlan(context),
  )
else
  FilledButton(
    onPressed: () => Navigator.pop(context),
    child: const Text('Done'),
  ),
      ],
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProtocolRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Protocol {
  final List<String> goals;
  final List<_SupplementRec> recommendations;
  _Protocol({
    required this.goals,
    required this.recommendations,
  });
}

class _SupplementRec {
  final String name;
  final String dosage;
  final String timing;
  final String duration;
  final String notes;
  final String monitor;
  _SupplementRec({
    required this.name,
    required this.dosage,
    required this.timing,
    required this.duration,
    required this.notes,
    required this.monitor,
  });
}