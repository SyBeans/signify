import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class EmergencySetupScreen extends StatefulWidget {
  const EmergencySetupScreen({super.key});
  @override
  State<EmergencySetupScreen> createState() => _EmergencySetupScreenState();
}

class _EmergencySetupScreenState extends State<EmergencySetupScreen> {
  late TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AppState>().userName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Setup',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('YOUR NAME', style: AppText.label),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Included in every emergency SMS sent.',
            style: AppText.small,
          ),
          const SizedBox(height: 24),

          const Text('EMERGENCY CONTACTS · MAX 3', style: AppText.label),
          const SizedBox(height: 10),
          ...s.contacts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(c.phone, style: AppText.small),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('LOCATION', style: AppText.label),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _locRow('Include GPS location', s.includeGps, s.setIncludeGps),
                const Divider(height: 0),
                _locRow(
                  'Wait for accurate GPS',
                  s.waitAccurateGps,
                  s.setWaitAccurateGps,
                  subtitle: 'Up to 60 sec before sending',
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              s.setUserName(_name.text);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locRow(
    String title,
    bool val,
    ValueChanged<bool> onCh, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.small),
                ],
              ],
            ),
          ),
          Switch(value: val, onChanged: onCh, activeColor: AppColors.green),
        ],
      ),
    );
  }
}
