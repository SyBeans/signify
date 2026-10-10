import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../theme.dart';

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({super.key});

  static const _emotionMap = {
    'Positive': ('😊', AppColors.emoPositive),
    'Negative': ('😢', AppColors.emoNegative),
    'Surprise': ('😲', AppColors.emoSurprise),
    'Neutral': ('😐', AppColors.emoNeutral),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final emo = state.currentEmotion;
    final emoData = _emotionMap[emo] ?? _emotionMap['Neutral']!;

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                          'DETECTING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Hand / Face / Emotion chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _detectChip('HAND'),
                  const SizedBox(width: 8),
                  _detectChip('FACE'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoData.$1, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          emo.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: emoData.$2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Camera preview
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corner brackets
                    ..._corners(),
                    const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_outlined,
                            color: Colors.white24,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Camera preview',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '(TFLite models plug in here)',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hand landmarks hint
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: Icon(
                        Icons.back_hand_outlined,
                        color: AppColors.green.withOpacity(0.5),
                        size: 60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Top-3 predictions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _predChip('Doctor', 87, primary: true),
                  const SizedBox(width: 8),
                  _predChip('Nurse', 6),
                  const SizedBox(width: 8),
                  _predChip('Help', 4),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Confidence
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONFIDENCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.87,
                      minHeight: 5,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(AppColors.green),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sentence builder card
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SENTENCE BUILDER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Word chip
                    if (state.sentence.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (state.sentence.last['en'] ?? '').toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(state.lastSignConfidence * 100).toStringAsFixed(0)}% confidence',
                            style: AppText.small,
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Sentence preview
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            state.sentence.isEmpty
                                ? const Text(
                                    'Start signing to build a sentence…',
                                    style: TextStyle(color: AppColors.textSoft),
                                  )
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        for (
                                          int i = 0;
                                          i < state.sentence.length;
                                          i++
                                        )
                                          TextSpan(
                                            text: i == state.sentence.length - 1
                                                ? '${state.sentence[i]['en']} '
                                                : '${state.sentence[i]['en']} ',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textDark,
                                              backgroundColor:
                                                  i == state.sentence.length - 1
                                                  ? AppColors.greenSoft
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(height: 8),
                            if (state.sentence.isNotEmpty)
                              Text(
                                state.filipinoSentence,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (state.sentence.isNotEmpty)
                              Row(
                                children: [
                                  Text(
                                    emoData.$1,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    emo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: emoData.$2,
                                    ),
                                  ),
                                  const Text(
                                    '  ·  grammatical marker: none',
                                    style: AppText.small,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Row(
                      children: [
                        _iconBtn(
                          Icons.arrow_back,
                          Colors.white,
                          border: true,
                          onTap: state.backspace,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => TtsService.speak(
                              state.speechLanguage == 'fil'
                                  ? state.filipinoSentence
                                  : state.englishSentence,
                              lang: state.speechLanguage,
                              speed: state.speechSpeed,
                            ),
                            icon: const Icon(Icons.volume_up, size: 18),
                            label: const Text(
                              'Speak Sentence',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          Icons.copy_rounded,
                          AppColors.textDark,
                          border: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 8),
                        _iconBtn(
                          Icons.delete_outline_rounded,
                          AppColors.red,
                          bg: AppColors.redSoft,
                          onTap: state.clearSentence,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detectChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.green.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
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
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.green,
          ),
        ),
      ],
    ),
  );

  Widget _predChip(String label, int pct, {bool primary = false}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primary ? AppColors.blue : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $pct%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _iconBtn(
    IconData icon,
    Color color, {
    Color? bg,
    bool border = false,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: border ? Border.all(color: AppColors.border) : null,
      ),
      child: Icon(icon, color: color, size: 20),
    ),
  );

  List<Widget> _corners() {
    final style = Paint()
      ..color = AppColors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    return [
      Positioned(
        top: 12,
        left: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, topLeft: true)),
        ),
      ),
      Positioned(
        top: 12,
        right: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, topRight: true)),
        ),
      ),
      Positioned(
        bottom: 12,
        left: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, bottomLeft: true)),
        ),
      ),
      Positioned(
        bottom: 12,
        right: 12,
        child: SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(painter: _CornerPainter(style, bottomRight: true)),
        ),
      ),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Paint paintStyle;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter(
    this.paintStyle, {
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path();
    if (topLeft) {
      p.moveTo(0, s.height);
      p.lineTo(0, 0);
      p.lineTo(s.width, 0);
    }
    if (topRight) {
      p.moveTo(0, 0);
      p.lineTo(s.width, 0);
      p.lineTo(s.width, s.height);
    }
    if (bottomLeft) {
      p.moveTo(0, 0);
      p.lineTo(0, s.height);
      p.lineTo(s.width, s.height);
    }
    if (bottomRight) {
      p.moveTo(s.width, 0);
      p.lineTo(s.width, s.height);
      p.lineTo(0, s.height);
    }
    canvas.drawPath(p, paintStyle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
