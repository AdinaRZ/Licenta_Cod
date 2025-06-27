/*
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'humidity_chart_screen.dart';
import 'temperature_chart_screen.dart';
import 'settings_screen.dart'; // îl poți crea tu sau lăsa deocamdată un Scaffold simplu

class MainTabsScreen extends StatefulWidget {
  final bool isDarkMode;
  final void Function(bool) onToggleTheme;

  const MainTabsScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _selectedIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const SensorsScreen(), // Vei crea acest ecran cu cele 2 grafice
      SettingsScreen(
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: 'Senzori',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setări',
          ),
        ],
      ),
    );
  }
}
*/
