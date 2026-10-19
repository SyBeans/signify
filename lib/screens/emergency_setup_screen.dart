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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _name,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('EMERGENCY CONTACTS · MAX 3', style: AppText.label),
              if (s.contacts.length < 3)
                GestureDetector(
                  onTap: () => _showContactDialog(context, s, null),
                  child: const Text(
                    '+ Add Contact',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (s.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No contacts added yet.', style: AppText.small),
              ),
            ),

          ...s.contacts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _showContactDialog(context, s, c),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
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
          ),
          const SizedBox(height: 24),

          const Text('LOCATION', style: AppText.label),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                _locRow('Include GPS location', s.includeGps, s.setIncludeGps),
                Divider(
                  height: 0,
                  color: isDark ? Colors.white12 : AppColors.border,
                ),
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
              backgroundColor: isDark ? AppColors.blue : AppColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              s.setUserName(_name.text);
              await s.saveContacts(s.contacts);
              if (context.mounted) Navigator.pop(context);
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

  void _showContactDialog(BuildContext context, AppState s, Contact? contact) {
    final isEditing = contact != null;
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Contact' : 'Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Mom',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+63 912 345 6789',
                ),
              ),
            ],
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () async {
                  final newList = List<Contact>.from(s.contacts)
                    ..remove(contact);
                  await s.saveContacts(newList);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty) return;
                final newList = List<Contact>.from(s.contacts);
                if (isEditing) {
                  newList[newList.indexOf(contact)] = Contact(
                    name: name,
                    phone: phone,
                  );
                } else {
                  newList.add(Contact(name: name, phone: phone));
                }
                await s.saveContacts(newList);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        );
      },
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
