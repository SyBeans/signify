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
            onPressed: () async {
              // Save user name
              s.setUserName(_name.text);

              // Contacts are saved immediately when edited,
              // but we ensure everything is synced before popping.
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

  // Dialog for Adding/Editing/Deleting a contact
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
                  // Delete logic
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
                if (name.isEmpty || phone.isEmpty) return; // Basic validation

                final newList = List<Contact>.from(s.contacts);
                if (isEditing) {
                  // Edit logic
                  final idx = newList.indexOf(contact);
                  newList[idx] = Contact(name: name, phone: phone);
                } else {
                  // Add logic
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
