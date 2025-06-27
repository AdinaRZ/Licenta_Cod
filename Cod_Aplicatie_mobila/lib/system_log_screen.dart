import 'package:flutter/material.dart';

class SystemLogScreen extends StatelessWidget {
  final List<String> systemLog;

  const SystemLogScreen({Key? key, required this.systemLog}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jurnalul sistemului'),
        backgroundColor: const Color(0xFFa1c4fd),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: systemLog.length,
            itemBuilder: (context, index) {
              return Text(
                '• ${systemLog[index]}',
                style: const TextStyle(fontSize: 14),
              );
            },
          ),
        ),
      ),
    );
  }
}