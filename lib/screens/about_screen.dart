import 'package:flutter/material.dart';
import '../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _team = <_TeamMember>[
    _TeamMember(
      name: 'Vincent Tayros',
      role: 'Lead Developer',
      icon: Icons.code_rounded,
      accent: AppColors.blue,
    ),
    _TeamMember(
      name: 'Charity Galarion',
      role: 'Project Manager',
      icon: Icons.assignment_turned_in_rounded,
      accent: AppColors.green,
    ),
    _TeamMember(
      name: 'Jonathan Jotojot',
      role: 'QA · Database & Tester',
      icon: Icons.bug_report_rounded,
      accent: AppColors.orange,
    ),
    _TeamMember(
      name: 'Mark Hundson',
      role: 'System Analyst',
      icon: Icons.analytics_rounded,
      accent: AppColors.pink,
    ),
    _TeamMember(
      name: 'Kent Joseph Mabanag',
      role: 'UI/UX & Documentation',
      icon: Icons.palette_rounded,
      accent: AppColors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('About Signify')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _hero(),
            const SizedBox(height: 22),
            _sectionLabel('ABOUT THE PROJECT'),
            const SizedBox(height: 8),
            _card(context, child: _aboutBody(context)),
            const SizedBox(height: 22),
            _sectionLabel('MODELS'),
            const SizedBox(height: 8),
            _card(context, child: _modelsBody()),
            const SizedBox(height: 22),
            _sectionLabel('THE TEAM'),
            const SizedBox(height: 8),
            ..._team.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _teamTile(context, m),
              ),
            ),
            const SizedBox(height: 22),
            _sectionLabel('CAPSTONE'),
            const SizedBox(height: 8),
            _card(context, child: _capstoneBody(context)),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '© 2026 Signify Team · All rights reserved',
                style: AppText.small,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyLight],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🆕 App icon from assets
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Colors.white.withOpacity(0.08),
                  child: const Icon(
                    Icons.sign_language_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Signify',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'An Offline AI-Based Filipino Sign Language Recognition and Translation Mobile Application',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green.withOpacity(0.4)),
            ),
            child: const Text(
              'VERSION 2.0',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutBody(BuildContext context) {
    return Text(
      'Signify is an offline AI-powered mobile application that translates '
      'Filipino Sign Language (FSL) gestures into text and speech in '
      'real-time. It is designed for deaf and hard-of-hearing individuals '
      'to communicate with hearing people — without requiring an internet '
      'connection or a human interpreter.\n\n'
      'Using the device camera, the app captures the user\'s signing, '
      'analyzes hand movements with MediaPipe, reads facial expressions '
      'for emotional context, and produces English and Filipino output '
      'with automatic sentence building and emergency SMS alerts.',
      style: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }

  Widget _modelsBody() {
    return Column(
      children: [
        _kvRow('Sign Recognition', 'v5 · FSL-105 + Team + REST · 95.58%'),
        const Divider(height: 20),
        _kvRow('Emotion Recognition', 'v12.3 · 4-class · 86.33%'),
        const Divider(height: 20),
        _kvRow('Hand & Face Tracking', 'MediaPipe Landmarker · Face Mesh'),
        const Divider(height: 20),
        _kvRow('Runtime', 'TensorFlow Lite · Fully Offline'),
      ],
    );
  }

  Widget _kvRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
          ),
        ),
      ],
    );
  }

  Widget _capstoneBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capstone Project',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'A final-year undergraduate capstone project addressing '
          'communication accessibility for the Filipino deaf and '
          'hard-of-hearing community.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AppColors.textSoft,
          ),
        ),
      ],
    );
  }

  Widget _teamTile(BuildContext context, _TeamMember m) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: m.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(m.icon, color: m.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.role,
                  style: TextStyle(
                    fontSize: 12,
                    color: m.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(t, style: AppText.label),
  );

  Widget _card(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: child,
    );
  }
}

class _TeamMember {
  final String name;
  final String role;
  final IconData icon;
  final Color accent;
  const _TeamMember({
    required this.name,
    required this.role,
    required this.icon,
    required this.accent,
  });
}
