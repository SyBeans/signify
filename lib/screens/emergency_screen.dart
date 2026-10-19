import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../theme.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  static const _phrases = [
    ['I need help!', 'Kailangan ko ng tulong!'],
    ['Call a doctor!', 'Tumawag ng doktor!'],
    ["There's an emergency!", 'May emergency!'],
    ['Call the police!', 'Tumawag ng pulis!'],
  ];

  final TextEditingController _noteController = TextEditingController();

  String? _lastTapped;
  Timer? _tapClearTimer;
  String? _speakingPhrase;
  Timer? _speakClearTimer;

  @override
  void dispose() {
    _noteController.dispose();
    _tapClearTimer?.cancel();
    _speakClearTimer?.cancel();
    super.dispose();
  }

  void _flashTap(String key) {
    setState(() => _lastTapped = key);
    _tapClearTimer?.cancel();
    _tapClearTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _lastTapped = null);
    });
  }

  Future<void> _speakPhrase(AppState state, String en, String fil) async {
    final text = state.speechLanguage == 'fil' ? fil : en;
    setState(() => _speakingPhrase = en);
    final estimated = Duration(
      milliseconds: (text.length * 80).clamp(1500, 8000),
    );

    await TtsService.speak(
      text,
      lang: state.speechLanguage,
      speed: state.speechSpeed,
    );

    _speakClearTimer?.cancel();
    _speakClearTimer = Timer(estimated, () {
      if (mounted && _speakingPhrase == en)
        setState(() => _speakingPhrase = null);
    });
  }

  String _buildSmsBody(AppState state, String note) {
    final base = '🚨 EMERGENCY!\n${state.userName} needs help!';
    if (note.isEmpty) return base;
    return '$base\nNote: $note';
  }

  void _showSendDialog(AppState state) {
    final note = _noteController.text.trim();
    final smsBody = _buildSmsBody(state, note);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Send emergency alert?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SMS will be sent to:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 6),
              ...state.contacts.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${c.name}  (${c.phone})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Message preview:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$smsBody\n📍 Location: https://maps.google.com/?q=…',
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _onMockSend(state, note.isNotEmpty);
            },
            child: const Text('SEND NOW'),
          ),
        ],
      ),
    );
  }

  void _onMockSend(AppState state, bool hadNote) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.red,
        duration: const Duration(seconds: 3),
        content: Text(
          '🚨 Demo: SMS queued to ${state.contacts.length} contacts${hadNote ? ' (with note)' : ''}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.red,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Red top banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              color: AppColors.red,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (Navigator.canPop(context))
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      const Text(
                        'WORKS WITHOUT CAMERA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Emergency',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
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
                          'ONLINE — READY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── White content ──
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Big alert card ──
                    Material(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showSendDialog(state),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SEND EMERGENCY ALERT',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'SMS + location to 3 emergency contacts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Optional note ──
                    const Text(
                      'NOTE (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: 'Add context (e.g. where you are)',
                        hintStyle: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        counterStyle: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 10,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.red,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── GPS progress ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.textSoft,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ACQUIRING GPS LOCATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                '8m accuracy',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              value: 0.8,
                              minHeight: 5,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Contacts ──
                    Row(
                      children: state.contacts.map((c) {
                        final initial = c.name.isNotEmpty
                            ? c.name[0].toUpperCase()
                            : '?';
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: c == state.contacts.last ? 0 : 8,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      color: AppColors.pinkSoft,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.pink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.phone,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'OR SPEAK A PHRASE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ..._phrases.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EmergencyPhrase(
                          en: p[0],
                          fil: p[1],
                          isFlashing: _lastTapped == p[0],
                          isSpeaking: _speakingPhrase == p[0],
                          onTap: () => _flashTap(p[0]),
                          onSpeak: () => _speakPhrase(state, p[0], p[1]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyPhrase extends StatelessWidget {
  final String en;
  final String fil;
  final bool isFlashing;
  final bool isSpeaking;
  final VoidCallback onTap;
  final VoidCallback onSpeak;

  const _EmergencyPhrase({
    required this.en,
    required this.fil,
    required this.isFlashing,
    required this.isSpeaking,
    required this.onTap,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.red.withOpacity(0.10),
        highlightColor: AppColors.red.withOpacity(0.05),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isFlashing ? AppColors.red.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFlashing ? AppColors.red : AppColors.border,
              width: isFlashing ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      en,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(fil, style: AppText.small),
                  ],
                ),
              ),
              _SpeakButton(isSpeaking: isSpeaking, onTap: onSpeak),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakButton extends StatefulWidget {
  final bool isSpeaking;
  final VoidCallback onTap;
  const _SpeakButton({required this.isSpeaking, required this.onTap});
  @override
  State<_SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<_SpeakButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isSpeaking) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SpeakButton old) {
    super.didUpdateWidget(old);
    if (widget.isSpeaking && !old.isSpeaking) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSpeaking && old.isSpeaking) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speaking = widget.isSpeaking;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = speaking ? 1.0 + 0.15 * _pulseController.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: speaking ? AppColors.red : AppColors.redSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: speaking ? AppColors.red : AppColors.redSoft,
                  width: speaking ? 2 : 1,
                ),
                boxShadow: speaking
                    ? [
                        BoxShadow(
                          color: AppColors.red.withOpacity(0.45),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                speaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                size: 20,
                color: speaking ? Colors.white : AppColors.red,
              ),
            ),
          );
        },
      ),
    );
  }
}
