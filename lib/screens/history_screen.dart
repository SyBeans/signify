import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('History', style: AppText.header)),
      body: state.history.isEmpty
          ? const Center(child: Text('No history yet', style: AppText.small))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: state.history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = state.history[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.english,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(e.filipino, style: AppText.small),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            e.emotion,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blue,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${e.time.hour}:${e.time.minute.toString().padLeft(2, '0')}',
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
