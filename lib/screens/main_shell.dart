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

  void _goToTab(int index) {
    if (index < 0 || index > 4) return;
    setState(() => _i = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      // Home needs callbacks to jump to other tabs
      HomeScreen(
        onStartTranslation: () => _goToTab(2), // Translate
        onOpenEmergency: () => _goToTab(1), // Emergency
        onOpenPhrasebook: () => _goToTab(3), // Phrasebook
      ),
      const EmergencyScreen(),
      TranslateScreen(isActive: _i == 2),
      const PhrasebookScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _i, children: screens),
      bottomNavigationBar: SignifyBottomNav(current: _i, onTap: _goToTab),
    );
  }
}
