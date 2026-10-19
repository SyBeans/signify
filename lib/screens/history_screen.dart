import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
    final state = context.watch<AppState>();

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
        title: Text('History', style: AppText.header),
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
              decoration: InputDecoration(
                hintText: 'Search translations',
                hintStyle: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSoft),
                filled: true,
                fillColor: Colors.white,
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
                ? const Center(
                    child: Text('No history found', style: AppText.small),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // Emotion Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.bg,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(e.filipino, style: AppText.small),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('h:mm a').format(e.time),
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
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => TtsService.speak(
                                    e.english,
                                    speed: 'normal',
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.blue,
                                    size: 20,
                                  ),
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
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
