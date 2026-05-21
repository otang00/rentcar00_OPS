import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/data/models/action_log_entry.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/utils/ops_kst_datetime.dart';

class ActionLogPage extends ConsumerWidget {
  const ActionLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStaffAsync = ref.watch(currentStaffAccountProvider);
    final logsAsync = ref.watch(allActionLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('작업로그')),
      body: currentStaffAsync.when(
        data: (staff) {
          if (staff?.isAdmin != true) {
            return const Center(child: Text('관리자만 접근할 수 있습니다.'));
          }

          return RefreshIndicator(
            triggerMode: RefreshIndicatorTriggerMode.anywhere,
            onRefresh: () async {
              ref.invalidate(allActionLogsProvider);
              await ref.read(allActionLogsProvider.future);
            },
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [Text('아직 기록된 작업로그가 없습니다.')],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _ActionLogCard(log: logs[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('작업로그를 불러오지 못했습니다.\n$error'),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('관리자 권한을 확인하지 못했습니다.\n$error'),
          ),
        ),
      ),
    );
  }
}

class _ActionLogCard extends StatelessWidget {
  const _ActionLogCard({required this.log});

  final ActionLogEntry log;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    log.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                _ResultChip(status: log.resultStatus),
              ],
            ),
            const SizedBox(height: 8),
            _InfoLine(icon: Icons.person_outline, text: log.actorDisplayName),
            _InfoLine(
              icon: Icons.schedule_outlined,
              text: opsFormatKstDateTime(log.executedAt),
            ),
            _InfoLine(icon: Icons.link_outlined, text: log.targetSummary),
            if (log.note.trim().isNotEmpty)
              _InfoLine(icon: Icons.notes_outlined, text: log.note.trim()),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(child: Text(text.isEmpty ? '-' : text)),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim();
    final ok = normalized.isEmpty || normalized == 'success';
    final color = ok ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ok ? '성공' : normalized,
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.w800),
      ),
    );
  }
}
