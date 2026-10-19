import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/tts_service.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _filter = 'Today'; // Today, This week, Favorites, By emotion

  final _searchController = TextEditingController();

  // Speaking state
  int? _speakingId;
  Timer? _speakClearTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _speakClearTimer?.cancel();
    super.dispose();
  }

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

  // Bulletproof time formatter to replace intl
  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _speakEntry(AppState state, TranslationEntry entry) async {
    final text = state.speechLanguage == 'fil' ? entry.filipino : entry.english;
    final id = entry.id ?? entry.time.millisecondsSinceEpoch;
    setState(() => _speakingId = id);

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
      if (mounted && _speakingId == id) {
        setState(() => _speakingId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter logic
    var filtered = state.history.where((e) {
      final matchesSearch =
          e.english.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.filipino.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_filter == 'Today') {
        final now = DateTime.now();
        return e.time.year == now.year &&
            e.time.month == now.month &&
            e.time.day == now.day;
      } else if (_filter == 'This week') {
        final now = DateTime.now();
        final diff = now.difference(e.time).inDays;
        return diff <= 7;
      } else if (_filter == 'Favorites') {
        return e.isFavorite;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: AppText.header.copyWith(
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.red),
            onPressed: () => state.clearHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: 'Search translations',
                hintStyle: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSoft),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildChip('Today'),
                _buildChip('This week'),
                _buildChip('Favorites'),
                _buildChip('By emotion'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No history found',
                      style: AppText.small.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      final isSpeaking =
                          _speakingId ==
                          (e.id ?? e.time.millisecondsSinceEpoch);

                      return Container(
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
                            // Emotion Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.navyLight
                                    : AppColors.bg,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _emoji(e.emotion),
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Text
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.english,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(e.filipino, style: AppText.small),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTime(e.time),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSoft,
                                        ),
                                      ),
                                      const Text(
                                        ' · ',
                                        style: TextStyle(
                                          color: AppColors.textSoft,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        '${(e.confidence * 100).toStringAsFixed(0)}% confidence',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Actions
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => state.toggleHistoryFav(e),
                                  child: Icon(
                                    e.isFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: e.isFavorite
                                        ? AppColors.orange
                                        : AppColors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SpeakButton(
                                  isSpeaking: isSpeaking,
                                  onTap: () => _speakEntry(state, e),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final active = _filter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.blue : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.blue
                : (isDark ? Colors.white12 : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white
                : (Theme.of(context).textTheme.bodyLarge?.color ??
                      AppColors.textDark),
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
              width: 32,
              height: 32,
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
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                speaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: speaking
                    ? Colors.white
                    : (Theme.of(context).textTheme.bodyLarge?.color ??
                          AppColors.textDark),
              ),
            ),
          );
        },
      ),
    );
  }
}
