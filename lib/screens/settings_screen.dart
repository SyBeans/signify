import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'emergency_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('Settings', style: AppText.header),
          const SizedBox(height: 24),

          _section('LANGUAGE'),
          _Segmented(
            options: const ['ENG', 'BOTH', 'FIL'],
            current: s.displayLanguage == 'eng'
                ? 'ENG'
                : s.displayLanguage == 'fil'
                ? 'FIL'
                : 'BOTH',
            onChanged: (v) {
              s.setDisplayLanguage(
                v == 'ENG'
                    ? 'eng'
                    : v == 'FIL'
                    ? 'fil'
                    : 'both',
              );
            },
            title: 'Display language',
            subtitle: 'Text shown on screen',
          ),
          const SizedBox(height: 10),
          _Segmented(
            options: const ['ENG', 'FIL'],
            current: s.speechLanguage == 'fil' ? 'FIL' : 'ENG',
            onChanged: (v) => s.setSpeechLanguage(v == 'FIL' ? 'fil' : 'eng'),
            title: 'Speech language',
            subtitle: 'Voice used for output',
          ),
          const SizedBox(height: 24),

          _section('EMERGENCY'),
          _NavTile(
            title: 'Emergency Setup',
            subtitle: 'Name, contacts, and GPS for alerts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencySetupScreen()),
            ),
          ),
          const SizedBox(height: 24),

          _section('TRANSLATION'),
          _SwitchTile(
            title: 'Show emotion',
            subtitle: 'Display 😊 emotion icons',
            value: s.showEmotion,
            onChanged: s.setShowEmotion,
          ),
          const SizedBox(height: 10),
          _SwitchTile(
            title: 'Auto-speak',
            subtitle: 'Speak translations automatically',
            value: s.autoSpeak,
            onChanged: s.setAutoSpeak,
          ),
          const SizedBox(height: 10),
          _Segmented(
            options: const ['SLOW', 'NORMAL', 'FAST'],
            current: s.speechSpeed.toUpperCase(),
            onChanged: (v) => s.setSpeechSpeed(v.toLowerCase()),
            title: 'Speech speed',
          ),
          const SizedBox(height: 24),

          _section('APPEARANCE'),
          _SwitchTile(
            title: 'Dark mode',
            value: s.darkMode,
            onChanged: s.setDarkMode,
          ),
          const SizedBox(height: 10),
          _Segmented(
            options: const ['S', 'M', 'L'],
            current: s.textSize,
            onChanged: s.setTextSize,
            title: 'Text size',
          ),
          const SizedBox(height: 24),

          _section('DATA'),
          _NavTile(
            title: 'Clear history',
            onTap: () => _showClearHistoryDialog(context, s),
          ),
          const SizedBox(height: 10),
          _NavTile(
            title: 'About Signify',
            onTap: () {
              // Blank for now
            },
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, AppState s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text(
          'This will permanently delete all your saved translations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              s.clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('History cleared')));
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: AppText.label),
  );
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.small),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.green,
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> options;
  final String current;
  final ValueChanged<String> onChanged;
  final String title;
  final String? subtitle;
  const _Segmented({
    required this.options,
    required this.current,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppText.small),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: options.map((o) {
                final active = o == current;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.navyLight
                                  : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        o,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? (Theme.of(context).textTheme.bodyLarge?.color)
                              : AppColors.textSoft,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.small),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}
