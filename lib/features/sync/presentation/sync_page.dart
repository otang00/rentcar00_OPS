import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(syncRunsProvider);
    final outboxEntriesAsync = ref.watch(outboxEntriesProvider);
    final env = ref.watch(appEnvProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync / Dry-run')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '실제 Google Sheets write는 비활성화 상태입니다.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(env.projectName),
              subtitle: Text('${env.projectRef} · ${env.supabaseUrl}'),
              trailing: const Text('Supabase 연결 완료'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '최근 sync/dry-run',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          runsAsync.when(
            data: (runs) => Column(
              children: [
                for (final item in runs)
                  Card(
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text('${item.status} · ${item.note}'),
                      trailing: Text(_formatDateTime(item.executedAt)),
                    ),
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('sync 이력을 불러오지 못했습니다.\n$error'),
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

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}
