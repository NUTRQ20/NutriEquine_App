import 'package:flutter/material.dart';

class SupplementProtocolScreen extends StatefulWidget {
  const SupplementProtocolScreen({super.key});
  @override
  State<SupplementProtocolScreen> createState() =>
      _SupplementProtocolScreenState();
}

class _SupplementProtocolScreenState
    extends State<SupplementProtocolScreen> {
  int _step = 0;
  String? _discipline;
  int? _ageYears;
  final Set<String> _goals = {};
  _Protocol? _result;

  final _ageCtrl = TextEditingController();

  static const _disciplines = [
    'Pleasure / Trail',
    'Dressage',
    'Show Jumping',
    'Eventing',
    'Western / Reining',
    'Racing',
    'Breeding',
    'Retired / Companion',
  ];

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
        notes:
            'Give consistently at the same time daily. Works best when fed with a small amount of hay to buffer stomach acid.',
        monitor: 'Appetite, manure consistency, girthiness, behavior during girthing',
      ));
    }

    if (_goals.any((g) => g.contains('Joint'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine FlexSupport',
        dosage: '2 scoops daily',
        timing: 'AM feed',
        duration: '60–90 days to assess effect',
        notes:
            'Joint supplements take time. Evaluate after 60 days for changes in stride and willingness to work.',
        monitor:
            'Stride length, stiffness after rest, willingness on circles',
      ));
    }

    if (_goals.any((g) => g.contains('Coat'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine CoatShine',
        dosage: '1 scoop daily',
        timing: 'Any meal',
        duration: '90 days (hoof improvement takes 6–12 months)',
        notes:
            'Biotin, zinc, copper and omega-3s. Coat response visible at 60–90 days; hoof wall changes take much longer.',
        monitor: 'Coat sheen, hoof wall hardness, hoof growth rate',
      ));
    }

    if (_goals.any((g) => g.contains('Performance'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine RecoveryBlend',
        dosage: '2 scoops post-exercise',
        timing: 'Within 1 hour of hard work',
        duration: 'Ongoing during training season',
        notes:
            'Electrolytes, quality protein and antioxidants. Give after cooling down; always ensure fresh water is available.',
        monitor: 'Recovery time, muscle soreness signs, topline condition',
      ));
    }

    if (_goals.any((g) => g.contains('Senior')) ||
        (_ageYears != null && _ageYears! >= 18)) {
      recs.add(_SupplementRec(
        name: 'NutriEquine SeniorVital',
        dosage: '2 scoops daily',
        timing: 'Split AM and PM',
        duration: 'Long-term / ongoing',
        notes:
            'Designed for horses 15+. Addresses reduced protein absorption, dental challenges, and immune changes common in senior horses.',
        monitor: 'Body condition score monthly, topline, water intake, coat quality',
      ));
    }

    if (_goals.any((g) => g.contains('Stress'))) {
      recs.add(_SupplementRec(
        name: 'NutriEquine CalmMag',
        dosage: '1 scoop daily',
        timing: 'Morning feed',
        duration: '30 days trial',
        notes:
            'Magnesium-based calming support. Not sedating. Evaluate after 30 days for changes in focus and behavior.',
        monitor:
            'Spookiness, focus during work, box-walking or weaving behavior',
      ));
    }

    if (recs.isEmpty) {
      recs.add(_SupplementRec(
        name: 'NutriEquine DailyFoundation',
        dosage: '1 scoop daily',
        timing: 'Any meal',
        duration: 'Ongoing',
        notes:
            'A comprehensive daily vitamin-mineral supplement suitable for most horses on hay-based diets.',
        monitor: 'Overall condition, energy, coat quality',
      ));
    }

    setState(() => _result = _Protocol(
          discipline: _discipline ?? 'General',
          goals: _goals.toList(),
          recommendations: recs,
        ));
    _next();
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
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildDisciplineStep();
      case 1:
        return _buildAgeStep();
      case 2:
        return _buildGoalsStep();
      case 3:
        return _buildResultStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDisciplineStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Step 1 of 3',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Text('What is your horse\'s primary discipline?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: _disciplines
                .map((d) => RadioListTile<String>(
                      value: d,
                      groupValue: _discipline,
                      title: Text(d),
                      onChanged: (v) => setState(() => _discipline = v),
                    ))
                .toList(),
          ),
        ),
        FilledButton(
          onPressed: _discipline != null ? _next : null,
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildAgeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Step 2 of 3',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Text('How old is your horse?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age in years',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _ageYears = int.tryParse(v)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _next,
          child: const Text('Next'),
        ),
        TextButton(
          onPressed: _next,
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _buildGoalsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Step 3 of 3',
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
        Text('For a ${_result!.discipline} horse',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: _result!.recommendations.map((r) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      _ProtocolRow('Dosage', r.dosage),
                      _ProtocolRow('Timing', r.timing),
                      _ProtocolRow('Duration', r.duration),
                      const Divider(),
                      Text(r.notes,
                          style: const TextStyle(color: Colors.grey)),
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
          'This protocol is educational and not a veterinary diagnosis. Consult your vet before starting any new supplement, especially if your horse has existing health conditions.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Add these to my horse\'s feed plan'),
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
                      fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Protocol {
  final String discipline;
  final List<String> goals;
  final List<_SupplementRec> recommendations;
  _Protocol(
      {required this.discipline,
      required this.goals,
      required this.recommendations});
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
