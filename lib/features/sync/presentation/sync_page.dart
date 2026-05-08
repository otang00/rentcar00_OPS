import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(syncRunsProvider);
    final outboxEntries = ref.watch(outboxEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync / Dry-run')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '실제 Google Sheets write는 비활성화 상태입니다.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text('최근 sync/dry-run', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in runs)
            Card(
              child: ListTile(
                title: Text(item.title),
                subtitle: Text('${item.status} · ${item.note}'),
                trailing: Text(_formatDateTime(item.executedAt)),
              ),
            ),
          const SizedBox(height: 16),
          Text('outbox preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in outboxEntries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.reservationId} · ${entry.actionKey}'),
                    const SizedBox(height: 8),
                    for (final line in entry.previewLines) Text('• $line'),
                  ],
                ),
              ),
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
