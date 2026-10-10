import 'package:flutter/material.dart';
import '../theme.dart';

class SignifyBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const SignifyBottomNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Home'),
    _NavItem(
      Icons.warning_amber_outlined,
      Icons.warning_amber,
      'Emergency',
      isEmergency: true,
    ),
    _NavItem(Icons.camera_alt_outlined, Icons.camera_alt, 'Translate'),
    _NavItem(Icons.menu_book_outlined, Icons.menu_book, 'Phrases'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final active = i == current;
            final color = active
                ? (item.isEmergency ? AppColors.red : AppColors.navy)
                : AppColors.grey;
            return InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active ? item.active : item.icon,
                      size: 22,
                      color: color,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData active;
  final String label;
  final bool isEmergency;
  const _NavItem(
    this.icon,
    this.active,
    this.label, {
    this.isEmergency = false,
  });
}
