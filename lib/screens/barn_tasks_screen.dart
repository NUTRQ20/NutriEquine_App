import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/barn_task.dart';
import '../services/firestore_service.dart';

class BarnTasksScreen extends StatelessWidget {
  const BarnTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<BarnTask>>(
      stream: fs.streamAllBarnTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data ?? [];
        final pending = tasks.where((t) => !t.isComplete).toList();
        final done = tasks.where((t) => t.isComplete).toList();

        if (tasks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.checklist, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No barn tasks yet.'),
                  Text(
                    'Assign tasks from inside each horse\'s detail screen → Barn Tasks tab.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          children: [
            if (pending.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('PENDING',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12)),
              ),
              ...pending.map((t) => _TaskCard(task: t, fs: fs)),
            ],
            if (done.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('COMPLETED',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12)),
              ),
              ...done.map((t) => _TaskCard(task: t, fs: fs)),
            ],
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final BarnTask task;
  final FirestoreService fs;
  const _TaskCard({required this.task, required this.fs});

  static const Map<String, IconData> _categoryIcons = {
    'Feeding': Icons.grass,
    'Turnout': Icons.wb_sunny,
    'Blanketing': Icons.bed,
    'Medications': Icons.medication,
    'Stall Check': Icons.search,
    'Grooming': Icons.brush,
    'Farrier Prep': Icons.build,
    'Vet Prep': Icons.local_hospital,
    'General': Icons.checklist,
  };

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue;
    return Card(
      color: overdue ? Colors.red.shade50 : null,
      child: CheckboxListTile(
        value: task.isComplete,
        onChanged: (_) => fs.completeBarnTask(task.id),
        title: Text(
          task.title,
          style: TextStyle(
              decoration:
                  task.isComplete ? TextDecoration.lineThrough : null,
              fontWeight: overdue ? FontWeight.bold : null),
        ),
        subtitle: Text(
          '${task.category} · ${task.assignedTo.isNotEmpty ? "→ ${task.assignedTo}" : "Unassigned"}\nDue ${DateFormat.yMMMd().format(task.dueDate)}'
          '${overdue ? " · OVERDUE" : ""}'
          '${task.notes != null ? "\n${task.notes}" : ""}',
        ),
        isThreeLine: true,
        secondary: Icon(
          _categoryIcons[task.category] ?? Icons.checklist,
          color: overdue ? Colors.red : null,
        ),
      ),
    );
  }
}
