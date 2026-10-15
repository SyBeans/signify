import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'emergency_screen.dart';
import 'phrasebook_screen.dart';
import 'history_screen.dart' show HistoryScreen;

class HomeScreen extends StatelessWidget {
  /// Called when user taps the "Start Translation" hero card.
  final VoidCallback? onStartTranslation;

  const HomeScreen({super.key, this.onStartTranslation});

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

          // Hero card (tappable)
          _HeroCard(
            onTap:
                onStartTranslation ??
                () {
                  // Fallback: navigate to Translate tab via MainShell
                  DefaultTabController.maybeOf(context);
                },
          ),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
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
              const _HandLandmarkIllustration(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 21-landmark hand illustration matching MediaPipe's topology.
/// Same purple accent as the original, now shaped like an actual hand.
class _HandLandmarkIllustration extends StatelessWidget {
  const _HandLandmarkIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 100,
      child: CustomPaint(painter: _HandLandmarkPainter()),
    );
  }
}

class _HandLandmarkPainter extends CustomPainter {
  // MediaPipe 21-landmark hand topology, normalized within a 0..1 box.
  // (x, y) coordinates laid out to look like an upright right hand.
  static const List<List<double>> _points = [
    // 0 wrist
    [0.50, 0.95],
    // 1-4 thumb
    [0.28, 0.86],
    [0.14, 0.75],
    [0.06, 0.62],
    [0.02, 0.48],
    // 5-8 index
    [0.38, 0.55],
    [0.34, 0.40],
    [0.31, 0.27],
    [0.28, 0.14],
    // 9-12 middle
    [0.53, 0.50],
    [0.53, 0.32],
    [0.53, 0.18],
    [0.53, 0.05],
    // 13-16 ring
    [0.68, 0.55],
    [0.71, 0.40],
    [0.73, 0.28],
    [0.76, 0.15],
    // 17-20 pinky
    [0.80, 0.64],
    [0.86, 0.54],
    [0.90, 0.44],
    [0.94, 0.34],
  ];

  // Bone connections (MediaPipe HAND_CONNECTIONS)
  static const List<List<int>> _connections = [
    // Palm (wrist to base of each finger)
    [0, 1],
    [0, 5],
    [0, 17],
    [5, 9],
    [9, 13],
    [13, 17],
    // Thumb
    [1, 2], [2, 3], [3, 4],
    // Index
    [5, 6], [6, 7], [7, 8],
    // Middle
    [9, 10], [10, 11], [11, 12],
    // Ring
    [13, 14], [14, 15], [15, 16],
    // Pinky
    [17, 18], [18, 19], [19, 20],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Convert normalized to screen coords
    List<Offset> pts() =>
        _points.map((p) => Offset(p[0] * w, p[1] * h)).toList(growable: false);

    final offsets = pts();

    // Bones
    final bonePaint = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final c in _connections) {
      canvas.drawLine(offsets[c[0]], offsets[c[1]], bonePaint);
    }

    // Glow behind dots
    final glow = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Joints
    final jointPaint = Paint()..color = const Color(0xFFA78BFA);
    final tipPaint = Paint()..color = const Color(0xFFC4B5FD);

    // Finger tips are 4, 8, 12, 16, 20. Wrist is 0.
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
