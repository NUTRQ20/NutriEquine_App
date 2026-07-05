import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/care_models.dart';
import '../services/firestore_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  static const Map<String, Color> _categoryColors = {
    'Vet': Colors.blue,
    'Farrier': Colors.green,
    'Dental': Colors.purple,
    'Deworm': Colors.orange,
    'Vaccine': Colors.teal,
    'Supplement Refill': Colors.red,
    'General': Colors.grey,
  };

  List<CareReminder> _getRemindersForDay(
      List<CareReminder> all, DateTime day) {
    return all
        .where((r) => isSameDay(r.dueDate, day))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<CareReminder>>(
      stream: fs.streamAllReminders(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final selected = _selectedDay != null
            ? _getRemindersForDay(all, _selectedDay!)
            : [];

        return Column(
          children: [
            TableCalendar<CareReminder>(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2028, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              eventLoader: (day) => _getRemindersForDay(all, day),
              calendarStyle: CalendarStyle(
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF2F5233),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF2F5233).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF2F5233),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            const Divider(),
            if (_selectedDay != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DateFormat.yMMMMd().format(_selectedDay!),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            Expanded(
              child: selected.isEmpty
                  ? Center(
                      child: Text(
                        _selectedDay == null
                            ? 'Tap a date to see reminders.'
                            : 'No reminders on this day.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView(
                      children: selected.map((r) {
                        final color =
                            _categoryColors[r.category] ?? Colors.grey;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.2),
                              child: Icon(Icons.event, color: color),
                            ),
                            title: Text(r.title),
                            subtitle: Text(r.category),
                            trailing: r.isComplete
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : Icon(
                                    r.isOverdue
                                        ? Icons.warning_amber
                                        : Icons.schedule,
                                    color: r.isOverdue
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}
