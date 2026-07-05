import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

/// Shows all Firebase data for the current user in a readable format.
/// Great for debugging, verifying data is saving, and showing clients
/// what's stored in the database.
class FirebaseDataScreen extends StatefulWidget {
  const FirebaseDataScreen({super.key});
  @override
  State<FirebaseDataScreen> createState() => _FirebaseDataScreenState();
}

class _FirebaseDataScreenState extends State<FirebaseDataScreen> {
  Map<String, List<Map<String, dynamic>>>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final fs = context.read<FirestoreService>();
      final data = await fs.fetchAllUserData();
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static const Map<String, IconData> _collectionIcons = {
    'horses': Icons.pets,
    'feed_entries': Icons.grass,
    'wellness_logs': Icons.favorite,
    'care_reminders': Icons.notifications,
    'training_logs': Icons.directions_run,
    'barn_tasks': Icons.checklist,
  };

  static const Map<String, Color> _collectionColors = {
    'horses': Color(0xFF2F5233),
    'feed_entries': Colors.orange,
    'wellness_logs': Colors.pink,
    'care_reminders': Colors.blue,
    'training_logs': Colors.purple,
    'barn_tasks': Colors.teal,
  };

  static const Map<String, String> _collectionLabels = {
    'horses': 'Horses',
    'feed_entries': 'Feed & Supplements',
    'wellness_logs': 'Wellness Logs',
    'care_reminders': 'Care Reminders',
    'training_logs': 'Training Sessions',
    'barn_tasks': 'Barn Tasks',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Data Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading Firebase data...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: $_error',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Summary cards row
                    _SummaryRow(data: _data!),
                    const SizedBox(height: 16),
                    // Each collection
                    ..._collectionLabels.keys.map((collection) {
                      final docs = _data![collection] ?? [];
                      return _CollectionCard(
                        collection: collection,
                        label: _collectionLabels[collection]!,
                        icon: _collectionIcons[collection]!,
                        color: _collectionColors[collection]!,
                        docs: docs,
                      );
                    }),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'This screen shows all data stored in your Firebase Firestore database. Data updates in real time as you use the app.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Summary row with count chips ───
class _SummaryRow extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> data;
  const _SummaryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Database Summary',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip('Horses', data['horses']?.length ?? 0,
                    const Color(0xFF2F5233)),
                _CountChip('Feed entries',
                    data['feed_entries']?.length ?? 0, Colors.orange),
                _CountChip('Wellness logs',
                    data['wellness_logs']?.length ?? 0, Colors.pink),
                _CountChip('Reminders',
                    data['care_reminders']?.length ?? 0, Colors.blue),
                _CountChip('Training logs',
                    data['training_logs']?.length ?? 0, Colors.purple),
                _CountChip('Barn tasks',
                    data['barn_tasks']?.length ?? 0, Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text('$count',
            style:
                const TextStyle(color: Colors.white, fontSize: 11)),
      ),
      label: Text(label),
    );
  }
}

// ─── Expandable collection card ───
class _CollectionCard extends StatefulWidget {
  final String collection;
  final String label;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> docs;
  const _CollectionCard({
    required this.collection,
    required this.label,
    required this.icon,
    required this.color,
    required this.docs,
  });
  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header — always visible
          ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.color.withOpacity(0.15),
              child: Icon(widget.icon, color: widget.color),
            ),
            title: Text(widget.label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${widget.docs.length} record${widget.docs.length != 1 ? "s" : ""}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.docs.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.docs.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(_expanded
                    ? Icons.expand_less
                    : Icons.expand_more),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          // Expandable document list
          if (_expanded) ...[
            const Divider(height: 1),
            if (widget.docs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No records yet.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...widget.docs.map((doc) => _DocTile(
                    doc: doc,
                    collection: widget.collection,
                    color: widget.color,
                  )),
          ],
        ],
      ),
    );
  }
}

// ─── Single document tile ───
class _DocTile extends StatefulWidget {
  final Map<String, dynamic> doc;
  final String collection;
  final Color color;
  const _DocTile(
      {required this.doc,
      required this.collection,
      required this.color});
  @override
  State<_DocTile> createState() => _DocTileState();
}

class _DocTileState extends State<_DocTile> {
  bool _showRaw = false;

  String _getTitle() {
    final doc = widget.doc;
    switch (widget.collection) {
      case 'horses':
        return doc['name'] ?? 'Unnamed horse';
      case 'feed_entries':
        return '${doc['itemName'] ?? '?'} — ${doc['dosage'] ?? '?'} (${doc['timeOfDay'] ?? '?'})';
      case 'wellness_logs':
        final ts = doc['date'];
        final date = ts != null
            ? DateFormat.yMMMd()
                .format(DateTime.fromMillisecondsSinceEpoch(ts))
            : '?';
        return 'Check-in: $date';
      case 'care_reminders':
        return doc['title'] ?? 'Unnamed reminder';
      case 'training_logs':
        final ts = doc['date'];
        final date = ts != null
            ? DateFormat.yMMMd()
                .format(DateTime.fromMillisecondsSinceEpoch(ts))
            : '?';
        return '${doc['type'] ?? '?'} — $date';
      case 'barn_tasks':
        return doc['title'] ?? 'Unnamed task';
      default:
        return doc['_id'] ?? 'Document';
    }
  }

  String _getSubtitle() {
    final doc = widget.doc;
    switch (widget.collection) {
      case 'horses':
        return '${doc['breed'] ?? '—'} · ${doc['discipline'] ?? '—'}';
      case 'feed_entries':
        final days = doc['daysRemaining'];
        return 'isSupplement: ${doc['isSupplement']} · Days left: ${days ?? "not tracked"}';
      case 'wellness_logs':
        return 'Appetite: ${doc['appetite']} · Manure: ${doc['manure']} · BCS: ${doc['bodyConditionScore']}';
      case 'care_reminders':
        final ts = doc['dueDate'];
        final date = ts != null
            ? DateFormat.yMMMd()
                .format(DateTime.fromMillisecondsSinceEpoch(ts))
            : '?';
        return '${doc['category']} · Due: $date · Done: ${doc['isComplete']}';
      case 'training_logs':
        return '${doc['intensity']} · ${doc['durationMinutes']}min · Rating: ${doc['performanceRating']}/5';
      case 'barn_tasks':
        return 'Category: ${doc['category']} · Assigned: ${doc['assignedTo'] ?? "—"} · Done: ${doc['isComplete']}';
      default:
        return doc['_id'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Text(_getTitle(),
              style: const TextStyle(fontSize: 13)),
          subtitle: Text(_getSubtitle(),
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: TextButton(
            onPressed: () =>
                setState(() => _showRaw = !_showRaw),
            child: Text(_showRaw ? 'Hide' : 'Raw',
                style: TextStyle(
                    color: widget.color, fontSize: 11)),
          ),
        ),
        if (_showRaw)
          Container(
            margin:
                const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.doc.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}
