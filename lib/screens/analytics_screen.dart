import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/horse.dart';
import '../models/care_models.dart';
import '../models/training_log.dart';
import '../services/firestore_service.dart';

class AnalyticsScreen extends StatelessWidget {
  final Horse horse;
  const AnalyticsScreen({super.key, required this.horse});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${horse.name} — Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BcsChart(horse: horse),
          const SizedBox(height: 20),
          _TrainingChart(horse: horse),
          const SizedBox(height: 20),
          _AppetiteChart(horse: horse),
          const SizedBox(height: 20),
          _WellnessSummary(horse: horse),
        ],
      ),
    );
  }
}

// ─── BCS Trend ───
class _BcsChart extends StatelessWidget {
  final Horse horse;
  const _BcsChart({required this.horse});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<WellnessLog>>(
      stream: fs.streamWellnessLogs(horse.id),
      builder: (context, snapshot) {
        final logs = (snapshot.data ?? []).reversed.take(20).toList();
        if (logs.length < 2) {
          return _ChartCard(
            title: 'Body Condition Score Trend',
            child: const Center(
              child: Text('Log at least 2 wellness check-ins to see trend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        final spots = <FlSpot>[];
        for (int i = 0; i < logs.length; i++) {
          spots.add(FlSpot(i.toDouble(), logs[i].bodyConditionScore.toDouble()));
        }
        return _ChartCard(
          title: 'Body Condition Score (last ${logs.length} logs)',
          child: LineChart(
            LineChartData(
              minY: 1,
              maxY: 9,
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx >= 0 && idx < logs.length && idx % 4 == 0) {
                        return Text(
                          DateFormat.Md().format(logs[idx].date),
                          style: const TextStyle(fontSize: 9),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF2F5233),
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF2F5233).withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Training Bar Chart ───
class _TrainingChart extends StatelessWidget {
  final Horse horse;
  const _TrainingChart({required this.horse});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<TrainingLog>>(
      stream: fs.streamTrainingLogs(horse.id),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return _ChartCard(
            title: 'Training Sessions by Type',
            child: const Center(
              child: Text('No training sessions logged yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        final typeCounts = <String, int>{};
        for (final l in logs) {
          typeCounts[l.type] = (typeCounts[l.type] ?? 0) + 1;
        }
        final entries = typeCounts.entries.toList();
        final maxY = typeCounts.values.reduce((a, b) => a > b ? a : b).toDouble() + 1;

        return _ChartCard(
          title: 'Sessions by Type (${logs.length} total)',
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx >= 0 && idx < entries.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            entries[idx].key.split(' ').first,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: entries.asMap().entries.map((e) {
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value.value.toDouble(),
                    color: const Color(0xFF2F5233),
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─── Appetite Pie Chart ───
class _AppetiteChart extends StatelessWidget {
  final Horse horse;
  const _AppetiteChart({required this.horse});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<WellnessLog>>(
      stream: fs.streamWellnessLogs(horse.id),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return const SizedBox();
        final good = logs.where((l) => l.appetite == 'Good').length;
        final reduced = logs.where((l) => l.appetite == 'Reduced').length;
        final none = logs.where((l) => l.appetite == 'None').length;
        final total = logs.length;

        return _ChartCard(
          title: 'Appetite Distribution (${logs.length} check-ins)',
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: [
                      if (good > 0)
                        PieChartSectionData(
                          value: good.toDouble(),
                          title: 'Good\n$good',
                          color: Colors.green,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                      if (reduced > 0)
                        PieChartSectionData(
                          value: reduced.toDouble(),
                          title: 'Low\n$reduced',
                          color: Colors.orange,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                      if (none > 0)
                        PieChartSectionData(
                          value: none.toDouble(),
                          title: 'None\n$none',
                          color: Colors.red,
                          radius: 60,
                          titleStyle: const TextStyle(
                              fontSize: 11, color: Colors.white),
                        ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend('Good', Colors.green,
                      '${(good / total * 100).round()}%'),
                  _Legend('Reduced', Colors.orange,
                      '${(reduced / total * 100).round()}%'),
                  _Legend('None', Colors.red,
                      '${(none / total * 100).round()}%'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  final String value;
  const _Legend(this.label, this.color, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label: $value', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Summary stats ───
class _WellnessSummary extends StatelessWidget {
  final Horse horse;
  const _WellnessSummary({required this.horse});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return StreamBuilder<List<WellnessLog>>(
      stream: fs.streamWellnessLogs(horse.id),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return const SizedBox();
        final flagged = logs.where((l) => l.flaggedForVet).length;
        final avgBcs = logs.map((l) => l.bodyConditionScore).reduce((a, b) => a + b) / logs.length;
        return _ChartCard(
          title: 'Wellness Summary',
          child: Column(
            children: [
              _StatRow('Total check-ins', '${logs.length}'),
              _StatRow('Avg body condition score', avgBcs.toStringAsFixed(1)),
              _StatRow('Flagged observations', '$flagged'),
              _StatRow('Last check-in',
                  logs.isNotEmpty ? DateFormat.yMMMd().format(logs.first.date) : '—'),
            ],
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}
