import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/care_models.dart';
import '../models/training_log.dart';
import '../models/barn_task.dart';
import '../services/firestore_service.dart';

class CalendarEvent {
  final String title;
  final String type;
  final Color color;
  final IconData icon;
  final bool isComplete;

  const CalendarEvent({
    required this.title,
    required this.type,
    required this.color,
    required this.icon,
    this.isComplete = false,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Single source of truth for the allowed date range —
  // both the year picker and TableCalendar's firstDay/lastDay
  // read from these so they can never drift out of sync again.
  static const int _minYear = 2000;
  static const int _maxYear = 2050;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<CareReminder> _reminders = [];
  List<TrainingLog> _trainingSessions = [];
  List<BarnTask> _barnTasks = [];

  DateTime _normalize(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalized = _normalize(day);
    final events = <CalendarEvent>[];

    for (final r in _reminders) {
      if (_normalize(r.dueDate) == normalized) {
        events.add(CalendarEvent(
          title: r.title,
          type: 'reminder',
          color: _reminderColor(r.category),
          icon: _reminderIcon(r.category),
          isComplete: r.isComplete,
        ));
      }
    }
    for (final t in _trainingSessions) {
      if (_normalize(t.date) == normalized) {
        events.add(CalendarEvent(
          title: '${t.type} - ${t.durationMinutes}min',
          type: 'training',
          color: Colors.purple,
          icon: Icons.directions_run,
          isComplete: true,
        ));
      }
    }
    for (final b in _barnTasks) {
      if (_normalize(b.dueDate) == normalized) {
        events.add(CalendarEvent(
          title: b.title,
          type: 'barn_task',
          color: Colors.teal,
          icon: Icons.checklist,
          isComplete: b.isComplete,
        ));
      }
    }
    return events;
  }

  Color _reminderColor(String cat) {
    switch (cat) {
      case 'Vet': return Colors.blue;
      case 'Farrier': return Colors.green;
      case 'Dental': return Colors.deepPurple;
      case 'Deworm': return Colors.orange;
      case 'Vaccine': return Colors.teal;
      case 'Supplement Refill': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _reminderIcon(String cat) {
    switch (cat) {
      case 'Vet': return Icons.local_hospital;
      case 'Farrier': return Icons.build;
      case 'Dental': return Icons.medical_services;
      case 'Deworm': return Icons.medication;
      case 'Vaccine': return Icons.vaccines;
      case 'Supplement Refill': return Icons.refresh;
      default: return Icons.event;
    }
  }

  // ── Month picker ─────────────────────────────────────
  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Month',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Fixed height grid — no overflow possible
                SizedBox(
                  height: 200,
                  child: GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.0,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    children: List.generate(12, (i) {
                      final month = i + 1;
                      final isSel =
                          _focusedDay.month == month;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _focusedDay = DateTime(
                                _focusedDay.year,
                                month,
                                1);
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF2F5233)
                                : Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              DateFormat.MMM().format(
                                  DateTime(2024, month)),
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSel
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Year picker ───────────────────────────────────────
  // Uses Dialog with explicit pixel dimensions
  // to guarantee no overflow on any screen size.
  void _showYearPicker() {
    final years = List.generate(
        _maxYear - _minYear + 1, (i) => _minYear + i);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          // Fixed size dialog — completely avoids overflow
          child: SizedBox(
            width: 240,
            height: 380,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: 16),
                  child: Text(
                    'Select Year',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Expanded fills the remaining fixed height
                Expanded(
                  child: ListView.builder(
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      final year = years[index];
                      final isSel =
                          _focusedDay.year == year;
                      return ListTile(
                        selected: isSel,
                        selectedColor:
                            const Color(0xFF2F5233),
                        selectedTileColor:
                            const Color(0xFF2F5233)
                                .withValues(alpha: 0.1),
                        title: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                            color: isSel
                                ? const Color(0xFF2F5233)
                                : null,
                          ),
                        ),
                        trailing: isSel
                            ? const Icon(
                                Icons.check,
                                color: Color(0xFF2F5233),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _focusedDay = DateTime(
                                year,
                                _focusedDay.month,
                                1);
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return StreamBuilder<List<CareReminder>>(
      stream: fs.streamAllReminders(),
      builder: (context, reminderSnap) {
        if (reminderSnap.hasData) {
          _reminders = reminderSnap.data!;
        }
        return StreamBuilder<List<TrainingLog>>(
          stream: fs.streamAllTrainingLogs(),
          builder: (context, trainingSnap) {
            if (trainingSnap.hasData) {
              _trainingSessions = trainingSnap.data!;
            }
            return StreamBuilder<List<BarnTask>>(
              stream: fs.streamAllBarnTasks(),
              builder: (context, taskSnap) {
                if (taskSnap.hasData) {
                  _barnTasks = taskSnap.data!;
                }

                final selectedEvents =
                    _selectedDay != null
                        ? _getEventsForDay(_selectedDay!)
                        : <CalendarEvent>[];

                return Column(
                  children: [
                    // Legend
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          _LegendChip(
                              'Reminders', Colors.blue),
                          _LegendChip(
                              'Training', Colors.purple),
                          _LegendChip(
                              'Barn Tasks', Colors.teal),
                        ],
                      ),
                    ),

                    // Calendar
                    TableCalendar<CalendarEvent>(
                      firstDay:
                          DateTime.utc(_minYear, 1, 1),
                      lastDay:
                          DateTime.utc(_maxYear, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (sel, foc) {
                        setState(() {
                          _selectedDay = sel;
                          _focusedDay = foc;
                        });
                      },
                      onPageChanged: (foc) =>
                          setState(() => _focusedDay = foc),
                      eventLoader: _getEventsForDay,
                      // Always render 6 week-rows so the
                      // calendar's height never changes
                      // between months/years — this is what
                      // prevents the "overflowed by infinity
                      // pixels" error when jumping to a year
                      // whose focused month needs a 6th row.
                      sixWeekMonthsEnforced: true,
                      calendarFormat:
                          CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Month',
                      },
                      calendarBuilders: CalendarBuilders(
                        headerTitleBuilder:
                            (context, day) {
                          return Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              // Month button
                              GestureDetector(
                                onTap: _showMonthPicker,
                                child: Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: const Color(
                                            0xFF2F5233)
                                        .withValues(
                                            alpha: 0.1),
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat.MMMM()
                                            .format(day),
                                        style:
                                            const TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          color: Color(
                                              0xFF2F5233),
                                        ),
                                      ),
                                      const Icon(
                                        Icons
                                            .arrow_drop_down,
                                        color: Color(
                                            0xFF2F5233),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Year button
                              GestureDetector(
                                onTap: _showYearPicker,
                                child: Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: const Color(
                                            0xFF2F5233)
                                        .withValues(
                                            alpha: 0.1),
                                    borderRadius:
                                        BorderRadius
                                            .circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormat.y()
                                            .format(day),
                                        style:
                                            const TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          color: Color(
                                              0xFF2F5233),
                                        ),
                                      ),
                                      const Icon(
                                        Icons
                                            .arrow_drop_down,
                                        color: Color(
                                            0xFF2F5233),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        markerBuilder:
                            (context, date, events) {
                          if (events.isEmpty) return null;
                          return Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children:
                                events.take(3).map((e) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets
                                    .symmetric(
                                    horizontal: 1),
                                decoration: BoxDecoration(
                                  color: e.color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFF2F5233)
                              .withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration:
                            const BoxDecoration(
                          color: Color(0xFF2F5233),
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),

                    const Divider(height: 1),

                    if (_selectedDay != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            16, 8, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            DateFormat.yMMMMd()
                                .format(_selectedDay!),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall,
                          ),
                        ),
                      ),

                    Expanded(
                      child: selectedEvents.isEmpty
                          ? Center(
                              child: Text(
                                _selectedDay == null
                                    ? 'Tap a date to see events.'
                                    : 'No events on this day.',
                                style: const TextStyle(
                                    color: Colors.grey),
                              ),
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.all(8),
                              children: selectedEvents
                                  .map((e) => Card(
                                        child: ListTile(
                                          leading:
                                              CircleAvatar(
                                            backgroundColor:
                                                e.color
                                                    .withValues(
                                                        alpha:
                                                            0.2),
                                            child: Icon(
                                                e.icon,
                                                color:
                                                    e.color),
                                          ),
                                          title: Text(
                                            e.title,
                                            style:
                                                TextStyle(
                                              decoration: e
                                                      .isComplete
                                                  ? TextDecoration
                                                      .lineThrough
                                                  : null,
                                            ),
                                          ),
                                          subtitle: Text(
                                            e.type
                                                .replaceAll(
                                                    '_',
                                                    ' ')
                                                .toUpperCase(),
                                            style:
                                                const TextStyle(
                                                    fontSize:
                                                        11),
                                          ),
                                          trailing: e
                                                  .isComplete
                                              ? const Icon(
                                                  Icons
                                                      .check_circle,
                                                  color: Colors
                                                      .green)
                                              : null,
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
