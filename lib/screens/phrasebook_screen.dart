import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/phrasebook_data.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../theme.dart';

class PhrasebookScreen extends StatefulWidget {
  const PhrasebookScreen({super.key});
  @override
  State<PhrasebookScreen> createState() => _PhrasebookScreenState();
}

class _PhrasebookScreenState extends State<PhrasebookScreen> {
  String _category = 'All';
  String? _lastTapped;
  Timer? _tapClearTimer;
  String? _speakingPhrase;
  Timer? _speakClearTimer;

  @override
  void dispose() {
    _tapClearTimer?.cancel();
    _speakClearTimer?.cancel();
    super.dispose();
  }

  void _flashTap(String key) {
    setState(() => _lastTapped = key);
    _tapClearTimer?.cancel();
    _tapClearTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _lastTapped = null);
    });
  }

  Future<void> _speakPhrase(AppState state, Phrase p) async {
    final text = state.speechLanguage == 'fil' ? p.filipino : p.english;
    setState(() => _speakingPhrase = p.english);
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
      if (mounted && _speakingPhrase == p.english)
        setState(() => _speakingPhrase = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const cats = [
      'All',
      'Emergency',
      'Greetings',
      'Medical',
      'Travel',
      'Food',
      'School',
    ];

    final dynamicPhrases = List<Phrase>.from(phrasebookData);
    final safeName = state.userName.trim().isEmpty
        ? 'Jonathan'
        : state.userName.trim();
    dynamicPhrases.add(
      Phrase('I am $safeName', 'Ako si $safeName', 'Greetings'),
    );

    final filtered = _category == 'All'
        ? dynamicPhrases
        : dynamicPhrases.where((p) => p.category == _category).toList();
    final favorites = filtered
        .where((p) => state.phrasebookFavs.contains(p.english))
        .toList();
    final rest = filtered
        .where((p) => !state.phrasebookFavs.contains(p.english))
        .toList();
    final grouped = <String, List<Phrase>>{};
    for (final p in rest) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Phrasebook',
          style: AppText.header.copyWith(
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final active = c == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.blue
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppColors.blue
                              : (isDark ? Colors.white12 : AppColors.border),
                        ),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: active
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (favorites.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'FAVORITES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...favorites.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PhraseItem(
                          phrase: p,
                          fav: true,
                          isFlashing: _lastTapped == p.english,
                          isSpeaking: _speakingPhrase == p.english,
                          onTap: () => _flashTap(p.english),
                          onFav: () => state.togglePhrasebookFav(p.english),
                          onSpeak: () => _speakPhrase(state, p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  for (final cat in grouped.keys) ...[
                    Text(
                      cat.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.textSoft,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...grouped[cat]!.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PhraseItem(
                          phrase: p,
                          fav: false,
                          isFlashing: _lastTapped == p.english,
                          isSpeaking: _speakingPhrase == p.english,
                          onTap: () => _flashTap(p.english),
                          onFav: () => state.togglePhrasebookFav(p.english),
                          onSpeak: () => _speakPhrase(state, p),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhraseItem extends StatelessWidget {
  final Phrase phrase;
  final bool fav;
  final bool isFlashing;
  final bool isSpeaking;
  final VoidCallback onTap;
  final VoidCallback onFav;
  final VoidCallback onSpeak;
  const _PhraseItem({
    required this.phrase,
    required this.fav,
    required this.isFlashing,
    required this.isSpeaking,
    required this.onTap,
    required this.onFav,
    required this.onSpeak,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.blue.withOpacity(0.12),
        highlightColor: AppColors.blue.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isFlashing
                ? AppColors.blue.withOpacity(0.10)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFlashing
                  ? AppColors.blue
                  : (isDark ? Colors.white12 : AppColors.border),
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
                      phrase.english,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(phrase.filipino, style: AppText.small),
                  ],
                ),
              ),
              _SpeakButton(isSpeaking: isSpeaking, onTap: onSpeak),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onFav,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    fav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: fav ? AppColors.orange : AppColors.grey,
                    size: 22,
                  ),
                ),
              ),
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
                color: speaking
                    ? AppColors.blue
                    : Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: speaking ? AppColors.blue : AppColors.border,
                  width: speaking ? 2 : 1,
                ),
                boxShadow: speaking
                    ? [
                        BoxShadow(
                          color: AppColors.blue.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                speaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                size: 20,
                color: speaking
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          );
        },
      ),
    );
  }
}
