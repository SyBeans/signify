import 'package:flutter/material.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'emergency_screen.dart';
import 'translate_screen.dart';
import 'phrasebook_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      EmergencyScreen(),
      TranslateScreen(),
      PhrasebookScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: screens),
      bottomNavigationBar: SignifyBottomNav(
        current: _i,
        onTap: (v) => setState(() => _i = v),
      ),
    );
  }
}
