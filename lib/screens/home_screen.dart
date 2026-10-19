import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'history_screen.dart' show HistoryScreen;

class HomeScreen extends StatelessWidget {
  final VoidCallback? onStartTranslation;
  final VoidCallback? onOpenEmergency;
  final VoidCallback? onOpenPhrasebook;

  const HomeScreen({
    super.key,
    this.onStartTranslation,
    this.onOpenEmergency,
    this.onOpenPhrasebook,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Text(
                'SIGNIFY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.green.withOpacity(0.2)
                      : AppColors.greenSoft,
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
                    Text(
                      'MODEL READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark
                            ? AppColors.green
                            : const Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _HeroCard(onTap: onStartTranslation ?? () {}),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Emergency',
                  color: AppColors.red,
                  bg: isDark
                      ? AppColors.red.withOpacity(0.15)
                      : AppColors.redSoft,
                  onTap: onOpenEmergency ?? () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.menu_book_rounded,
                  label: 'Phrasebook',
                  color:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      AppColors.textDark,
                  bg: Theme.of(context).cardColor,
                  onTap: onOpenPhrasebook ?? () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickTile(
                  icon: Icons.access_time_rounded,
                  label: 'History',
                  color:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      AppColors.textDark,
                  bg: Theme.of(context).cardColor,
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

          if (state.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No recent translations.\nGo to Translate and save a sentence!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSoft),
                ),
              ),
            )
          else
            ...state.history
                .take(5)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: _RecentItem(
                        entry: e,
                        formattedTime: _formatTime(e.time),
                      ),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.navyLight
                : AppColors.navy, // Lighter navy for dark mode
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
              const _HandLandmarkIllustration(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandLandmarkIllustration extends StatelessWidget {
  const _HandLandmarkIllustration();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80,
    height: 100,
    child: CustomPaint(painter: _HandLandmarkPainter()),
  );
}

class _HandLandmarkPainter extends CustomPainter {
  static const List<List<double>> _points = [
    [0.50, 0.95],
    [0.28, 0.86],
    [0.14, 0.75],
    [0.06, 0.62],
    [0.02, 0.48],
    [0.38, 0.55],
    [0.34, 0.40],
    [0.31, 0.27],
    [0.28, 0.14],
    [0.53, 0.50],
    [0.53, 0.32],
    [0.53, 0.18],
    [0.53, 0.05],
    [0.68, 0.55],
    [0.71, 0.40],
    [0.73, 0.28],
    [0.76, 0.15],
    [0.80, 0.64],
    [0.86, 0.54],
    [0.90, 0.44],
    [0.94, 0.34],
  ];
  static const List<List<int>> _connections = [
    [0, 1],
    [0, 5],
    [0, 17],
    [5, 9],
    [9, 13],
    [13, 17],
    [1, 2],
    [2, 3],
    [3, 4],
    [5, 6],
    [6, 7],
    [7, 8],
    [9, 10],
    [10, 11],
    [11, 12],
    [13, 14],
    [14, 15],
    [15, 16],
    [17, 18],
    [18, 19],
    [19, 20],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final offsets = _points
        .map((p) => Offset(p[0] * w, p[1] * h))
        .toList(growable: false);
    final bonePaint = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final c in _connections)
      canvas.drawLine(offsets[c[0]], offsets[c[1]], bonePaint);
    final glow = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final jointPaint = Paint()..color = const Color(0xFFA78BFA);
    final tipPaint = Paint()..color = const Color(0xFFC4B5FD);
    const tips = {4, 8, 12, 16, 20};
    for (int i = 0; i < offsets.length; i++) {
      final isTip = tips.contains(i);
      final r = isTip ? 3.5 : 2.2;
      canvas.drawCircle(offsets[i], r + 1.5, glow);
      canvas.drawCircle(offsets[i], r, isTip ? tipPaint : jointPaint);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            border: bg == Theme.of(context).cardColor
                ? Border.all(color: isDark ? Colors.white12 : AppColors.border)
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
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
  final String formattedTime;
  const _RecentItem({required this.entry, required this.formattedTime});
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.pink.withOpacity(0.2)
                  : AppColors.pinkSoft,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.filipino,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            formattedTime,
            style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }
}
