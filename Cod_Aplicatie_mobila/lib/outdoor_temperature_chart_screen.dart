import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main.dart';

enum OutdoorTempViewType { day, week, month }

class OutdoorTemperatureChartScreen extends StatefulWidget {
  const OutdoorTemperatureChartScreen({super.key});

  @override
  State<OutdoorTemperatureChartScreen> createState() => _OutdoorTemperatureChartScreenState();
}

class _OutdoorTemperatureChartScreenState extends State<OutdoorTemperatureChartScreen> {
  DateTime selectedDate = DateTime.now();
  OutdoorTempViewType selectedView = OutdoorTempViewType.day;
  String? codCasa;
  List<FlSpot> chartData = [];
  bool _isLoading = false;

  double? minTemp;
  double? maxTemp;

  @override
  void initState() {
    super.initState();
    _initializeChart();
  }

  Future<void> _loadCodCasa() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('utilizatori').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('codCasa')) {
        codCasa = userDoc['codCasa'];
      }
    }
  }

  Future<void> _initializeChart() async {
    await _loadCodCasa();
    if (codCasa != null) {
      _fetchData();
    }
  }

  String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    if (codCasa == null) return;
    final List<FlSpot> spots = [];

    if (selectedView == OutdoorTempViewType.day) {
      final dateKey = _formatDateKey(selectedDate);
      final snapshot = await rtdb.child("case/$codCasa/istoric_temperatura_exterior/$dateKey").get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        for (final entry in data.entries) {
          final parts = entry.key.split(":");
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            final v = double.tryParse(entry.value.toString()) ?? 0.0;
            spots.add(FlSpot((h * 60 + m).toDouble(), v));
          }
        }
      }

    } else {
      final int days = selectedView == OutdoorTempViewType.week
          ? 7
          : DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
      final DateTime startDate = selectedView == OutdoorTempViewType.week
          ? selectedDate.subtract(const Duration(days: 6))
          : DateTime(selectedDate.year, selectedDate.month, 1);

      for (int i = 0; i < days; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final dateKey = _formatDateKey(currentDate);
        final snapshot = await rtdb.child("case/$codCasa/istoric_temperatura_exterior/$dateKey").get();

        if (snapshot.exists && snapshot.value is Map) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          final values = data.values.map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
          if (values.isNotEmpty) {
            final avg = values.reduce((a, b) => a + b) / values.length;
            spots.add(FlSpot((i + 1).toDouble(), avg));
          }
        }
      }
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    if (spots.isNotEmpty) {
      minTemp = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxTemp = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    } else {
      minTemp = null;
      maxTemp = null;
    }

    setState(() {
      chartData = spots;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      _fetchData();
    }
  }

  Widget _buildChart(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return const Center(child: Text("Nu există date."));
    }

    final double yMin = (minTemp! - 1).floorToDouble();
    final double yMax = (maxTemp! + 1).ceilToDouble();

    return SizedBox(
      height: 320,
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax,
          gridData: FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(color: Colors.grey, width: 1),
              bottom: BorderSide(color: Colors.grey, width: 1),
              right: BorderSide(color: Colors.grey, width: 1),
              top: BorderSide(color: Colors.transparent),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: selectedView == OutdoorTempViewType.day ? 180 : 1,
                // getTitlesWidget: (value, meta) {
                //   if (selectedView == OutdoorTempViewType.day) {
                //     return Text('${(value / 60).floor().toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 10));
                //   } else {
                //     if ([1, 5, 10, 15, 20, 25, 30].contains(value.toInt())) {
                //       return Text('Zi ${value.toInt()}', style: const TextStyle(fontSize: 10));
                //     }
                //     return const SizedBox.shrink(); // ascunde restul
                //
                //   }
                // },
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                },

              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text("${value.toInt()}°C", style: const TextStyle(fontSize: 12)),
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 2.5,
              color: Colors.pinkAccent,
              belowBarData: BarAreaData(show: true, color: Colors.pinkAccent.withOpacity(0.2)),
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Grafic Temperatură Exterior Firebase")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              readOnly: true,
              controller: TextEditingController(
                text: "${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}",
              ),
              decoration: const InputDecoration(
                labelText: 'Selectează data',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() => selectedView = OutdoorTempViewType.day);
                    _fetchData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedView == OutdoorTempViewType.day ? Colors.pinkAccent : Colors.grey,
                  ),
                  child: const Text("Zi"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => selectedView = OutdoorTempViewType.week);
                    _fetchData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedView == OutdoorTempViewType.week ? Colors.pinkAccent : Colors.grey,
                  ),
                  child: const Text("Săptămână"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => selectedView = OutdoorTempViewType.month);
                    _fetchData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedView == OutdoorTempViewType.month ? Colors.pinkAccent : Colors.grey,
                  ),
                  child: const Text("Lună"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildChart(chartData),
          ],
        ),
      ),
    );
  }
}