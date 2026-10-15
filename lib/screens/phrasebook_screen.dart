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
  final Set<String> _favs = {};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cats = [
      'All',
      'Emergency',
      'Greetings',
      'Medical',
      'Travel',
      'Food',
      'School',
    ];
    final filtered = _category == 'All'
        ? phrasebookData
        : phrasebookData.where((p) => p.category == _category).toList();

    final grouped = <String, List<Phrase>>{};
    for (final p in filtered) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Phrasebook', style: AppText.header),
        backgroundColor: AppColors.bg,
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
                        color: active ? AppColors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.blue : AppColors.border,
                        ),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: active ? Colors.white : AppColors.textDark,
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
                          fav: _favs.contains(p.english),
                          onFav: () => setState(() {
                            _favs.contains(p.english)
                                ? _favs.remove(p.english)
                                : _favs.add(p.english);
                          }),
                          onSpeak: () => TtsService.speak(
                            state.speechLanguage == 'fil'
                                ? p.filipino
                                : p.english,
                            lang: state.speechLanguage,
                            speed: state.speechSpeed,
                          ),
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
  final VoidCallback onFav;
  final VoidCallback onSpeak;

  const _PhraseItem({
    required this.phrase,
    required this.fav,
    required this.onFav,
    required this.onSpeak,
  });

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phrase.english,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(phrase.filipino, style: AppText.small),
              ],
            ),
          ),
          InkWell(
            onTap: onSpeak,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFav,
            child: Icon(
              fav ? Icons.star_rounded : Icons.star_border_rounded,
              color: fav ? AppColors.orange : AppColors.grey,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
