import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/horse.dart';
import '../services/firestore_service.dart';
import 'horse_detail_screen.dart';

class HorseListScreen extends StatefulWidget {
  const HorseListScreen({super.key});

  @override
  State<HorseListScreen> createState() => _HorseListScreenState();
}

class _HorseListScreenState extends State<HorseListScreen> {
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  final _disciplineCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _vetCtrl = TextEditingController();
  final _farrierCtrl = TextEditingController();

  bool _saving = false;
  String _search = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _disciplineCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _vetCtrl.dispose();
    _farrierCtrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameCtrl.clear();
    _breedCtrl.clear();
    _disciplineCtrl.clear();
    _ageCtrl.clear();
    _weightCtrl.clear();
    _vetCtrl.clear();
    _farrierCtrl.clear();
  }

  Future<void> _confirmDeleteHorse(Horse horse) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove horse?'),
        content: Text(
          'This will permanently delete ${horse.name} '
          'and all associated records. Cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<FirestoreService>().deleteHorse(horse.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${horse.name} removed.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing horse: $e')),
          );
        }
      }
    }
  }

  void _showAddHorseSheet() {
    _clearForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    const Icon(Icons.pets, color: Color(0xFF2F5233)),
                    const SizedBox(width: 8),
                    Text('Add a horse',
                        style: Theme.of(sheetCtx).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Basic Info section ──
                const _SectionLabel('Basic Information'),
                const SizedBox(height: 10),

                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Horse name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pets),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _breedCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Breed',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Thoroughbred, Quarter Horse',
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _disciplineCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Discipline / Goal',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Dressage, Trail, Show Jumping',
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age (years)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Care Team section ──
                const _SectionLabel('Care Team'),
                const SizedBox(height: 10),

                TextField(
                  controller: _vetCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Veterinarian name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_hospital),
                    hintText: 'e.g. Dr. Sarah Johnson',
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _farrierCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Farrier name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.build),
                    hintText: 'e.g. Mike Williams',
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save horse'),
                  onPressed: _saving
                      ? null
                      : () async {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a horse name.'),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => _saving = true);
                          final fs = context.read<FirestoreService>();
                          try {
                            final horse = Horse(
                              id: const Uuid().v4(),
                              ownerId: fs.uid,
                              name: name,
                              breed: _breedCtrl.text.trim(),
                              discipline: _disciplineCtrl.text.trim(),
                              ageYears: int.tryParse(_ageCtrl.text.trim()),
                              weightKg:
                                  double.tryParse(_weightCtrl.text.trim()),
                              vetName: _vetCtrl.text.trim().isEmpty
                                  ? null
                                  : _vetCtrl.text.trim(),
                              farrierName: _farrierCtrl.text.trim().isEmpty
                                  ? null
                                  : _farrierCtrl.text.trim(),
                              createdAt: DateTime.now(),
                            );
                            await fs.addHorse(horse);
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$name added!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _saving = false);
                            }
                          }
                        },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Cancel'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search horses...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Horse>>(
              stream: fs.streamHorsesWithOrphanCleanup(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allHorses = snapshot.data ?? [];
                final horses = _search.isEmpty
                    ? allHorses
                    : allHorses
                        .where((h) =>
                            h.name.toLowerCase().contains(_search) ||
                            h.breed.toLowerCase().contains(_search) ||
                            h.discipline.toLowerCase().contains(_search))
                        .toList();

                if (allHorses.isEmpty) {
                  return const Center(
                    child: Text(
                      'No horses yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                if (horses.isEmpty) {
                  return const Center(
                      child: Text('No horses match your search.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: horses.length,
                  itemBuilder: (context, i) {
                    final h = horses[i];
                    return Dismissible(
                      key: Key(h.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Remove horse?'),
                            content: Text(
                              'Delete ${h.name} and all records? '
                              'Cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        return confirmed ?? false;
                      },
                      onDismissed: (_) async {
                        await fs.deleteHorse(h.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${h.name} removed.'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, color: Colors.white, size: 28),
                            SizedBox(height: 4),
                            Text('Delete',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                const Color(0xFF2F5233).withValues(alpha: 0.15),
                            backgroundImage: h.photoUrl != null
                                ? NetworkImage(h.photoUrl!)
                                : null,
                            child: h.photoUrl == null
                                ? Text(
                                    h.name.isNotEmpty
                                        ? h.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2F5233),
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            h.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (h.breed.isNotEmpty)
                                Text(h.breed,
                                    style: const TextStyle(color: Colors.grey)),
                              if (h.discipline.isNotEmpty)
                                Text(
                                  h.discipline,
                                  style: const TextStyle(
                                    color: Color(0xFF2F5233),
                                    fontSize: 12,
                                  ),
                                ),
                              if (h.vetName != null || h.farrierName != null)
                                Text(
                                  [
                                    if (h.vetName != null) 'Vet: ${h.vetName}',
                                    if (h.farrierName != null)
                                      'Farrier: ${h.farrierName}',
                                  ].join(' · '),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (h.ageYears != null)
                                Chip(
                                  label: Text('${h.ageYears}y'),
                                  padding: EdgeInsets.zero,
                                  labelStyle: const TextStyle(fontSize: 11),
                                ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (val) {
                                  if (val == 'delete') {
                                    _confirmDeleteHorse(h);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Remove horse',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HorseDetailScreen(horse: h),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHorseSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Horse'),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Color(0xFF2F5233),
      ),
    );
  }
}
