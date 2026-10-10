import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'emergency_screen.dart';
import 'phrasebook_screen.dart';
import 'history_screen.dart' show HistoryScreen;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Header
          Row(
            children: [
              const Text(
                'SIGNIFY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'MODEL READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Hero card
          _HeroCard(onTap: () {}),
          const SizedBox(height: 16),

          // Quick tiles
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Emergency',
                  color: AppColors.red,
                  bg: AppColors.redSoft,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.menu_book_rounded,
                  label: 'Phrasebook',
                  color: AppColors.textDark,
                  bg: Colors.white,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PhrasebookScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.access_time_rounded,
                  label: 'History',
                  color: AppColors.textDark,
                  bg: Colors.white,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'RECENT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 12),

          ...state.history
              .take(5)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentItem(entry: e),
                ),
              ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TAP TO BEGIN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Start Translation',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Point the camera and sign —\ntext and speech appear instantly.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _DotsIllustration(),
          ],
        ),
      ),
    );
  }
}

class _DotsIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 90,
      child: CustomPaint(painter: _DotsPainter()),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final dot = Paint()..color = const Color(0xFFA78BFA);
    final pts = <Offset>[
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.15, size.height * 0.35),
      Offset(size.width * 0.85, size.height * 0.35),
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.85, size.height * 0.75),
      Offset(size.width * 0.5, size.height * 0.95),
    ];
    for (final p in pts) {
      canvas.drawCircle(p, 6, glow);
      canvas.drawCircle(p, 3, dot);
    }
    final line = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(pts[1], pts[0], line);
    canvas.drawLine(pts[2], pts[0], line);
    canvas.drawLine(pts[1], pts[3], line);
    canvas.drawLine(pts[2], pts[4], line);
    canvas.drawLine(pts[3], pts[5], line);
    canvas.drawLine(pts[4], pts[5], line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: bg == Colors.white
                ? Border.all(color: AppColors.border)
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final TranslationEntry entry;
  const _RecentItem({required this.entry});

  String _emoji(String emo) {
    switch (emo.toLowerCase()) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😢';
      case 'surprise':
        return '😲';
      case 'urgent':
        return '🚨';
      default:
        return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.pinkSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _emoji(entry.emotion),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.english,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.filipino,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.time.hour}:${entry.time.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }
}
