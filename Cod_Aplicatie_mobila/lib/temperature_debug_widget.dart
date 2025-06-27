//cod pentru o zi anume

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'main.dart';

class TemperatureChartScreen extends StatefulWidget {
  const TemperatureChartScreen({super.key});

  @override
  State<TemperatureChartScreen> createState() => _TemperatureChartScreenState();
}

class _TemperatureChartScreenState extends State<TemperatureChartScreen> {
  List<FlSpot> chartData = [];
  bool _isLoading = false;
  DateTime selectedDate = DateTime(2025, 5, 14);
  final String codCasa = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final dateKey = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final ref = rtdb.child("case/$codCasa/istoric_temperatura_interior/$dateKey");
    final snapshot = await ref.get();

    if (snapshot.exists && snapshot.value is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<FlSpot> spots = [];

      for (final entry in data.entries) {
        final parts = entry.key.split(":");
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final v = double.tryParse(entry.value.toString()) ?? 0.0;
          spots.add(FlSpot((h * 60 + m).toDouble(), v));
        }
      }

      spots.sort((a, b) => a.x.compareTo(b.x));

      setState(() {
        chartData = spots;
        _isLoading = false;
      });
    } else {
      setState(() {
        chartData = [];
        _isLoading = false;
      });
    }
  }

  Widget _buildChart() {
    if (chartData.isEmpty) {
      return const Center(child: Text("Nu există date."));
    }

    return SizedBox(
      height: 320,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: LineChart(
          LineChartData(
            minY: 10,
            maxY: 35,
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
                  interval: 180,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${(value / 60).floor().toString().padLeft(2, '0')}:00', style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text("${value.toInt()}°C", style: const TextStyle(fontSize: 13), textAlign: TextAlign.right),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: chartData,
                isCurved: true,
                barWidth: 2.5,
                color: Colors.orange,
                belowBarData: BarAreaData(show: true, color: Colors.orange.withOpacity(0.2)),
                dotData: FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Grafic Temperatură Firebase")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Data: ${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}"),
            const SizedBox(height: 16),
            _buildChart(),
          ],
        ),
      ),
    );
  }
}