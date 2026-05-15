import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outboxEntriesAsync = ref.watch(outboxEntriesProvider);
    final env = ref.watch(appEnvProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('운영 진단')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Google Sheets import/sync는 운영 기준에서 제거되었습니다.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(env.projectName),
              subtitle: Text('${env.projectRef} · ${env.supabaseUrl}'),
              trailing: const Text('Supabase 연결'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'outbox preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          outboxEntriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('현재 outbox 항목이 없습니다.'),
                  ),
                );
              }
              return Column(
                children: [
                  for (final entry in entries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${entry.reservationId} · ${entry.actionKey}'),
                            const SizedBox(height: 8),
                            for (final line in entry.previewLines)
                              Text('• $line'),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('outbox 데이터를 불러오지 못했습니다.\n$error'),
          ),
        ],
      ),
    );
  }
}
