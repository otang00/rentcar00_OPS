import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class ReservationDetailPage extends ConsumerWidget {
  const ReservationDetailPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync = ref.watch(
      reservationDetailProvider(reservationId),
    );

    return Scaffold(
      appBar: AppBar(title: Text('예약 상세 · $reservationId')),
      body: reservationAsync.when(
        data: (reservation) {
          if (reservation == null) {
            return const Center(child: Text('예약 정보를 찾을 수 없습니다.'));
          }
          return _ReservationDetailBody(reservationId: reservationId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('예약 상세를 불러오지 못했습니다.\n$error')),
      ),
    );
  }
}

class _ReservationDetailBody extends ConsumerWidget {
  const _ReservationDetailBody({required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationAsync = ref.watch(
      reservationDetailProvider(reservationId),
    );
    final actionsAsync = ref.watch(reservationActionsProvider(reservationId));
    final logsAsync = ref.watch(actionLogsProvider(reservationId));
    final outboxPreviewAsync = ref.watch(outboxPreviewProvider(reservationId));

    return reservationAsync.when(
      data: (reservation) {
        if (reservation == null) {
          return const Center(child: Text('예약 정보를 찾을 수 없습니다.'));
        }

        final actions = actionsAsync.valueOrNull ?? const [];
        final logs = logsAsync.valueOrNull ?? const [];
        final outboxPreview = outboxPreviewAsync.valueOrNull ?? const [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${reservation.customerName.isEmpty ? '(고객명없음)' : reservation.customerName} · ${reservation.carNumber}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${reservation.reservationNumber} · ${reservation.customerPhone}',
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '예약 정보',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('생년월일: ${_displayValue(reservation.customerBirthDate)}'),
                  Text('소개처: ${_displayValue(reservation.referralSource)}'),
                  Text('가격: ${_displayValue(reservation.paymentAmount)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '상태 요약',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('탭: ${reservation.tab.label}'),
                  Text('status: ${reservation.statusKey}'),
                  Text('배차: ${_formatDateTime(reservation.startAt)}'),
                  Text('반납: ${_formatDateTime(reservation.endAt)}'),
                  Text('위치: ${reservation.locationSummary}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final badge in reservation.primaryBadges)
                        Chip(label: Text(badge)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '액션 영역',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('현재는 Supabase read-only 단계입니다.'),
                  const SizedBox(height: 12),
                  if (actions.isEmpty) const Text('이 탭은 조회 중심입니다.'),
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.tonal(
                        onPressed: null,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(action.label),
                                const SizedBox(height: 4),
                                Text(
                                  '${action.description}${action.createsOutbox ? ' · outbox 예정' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '체크 상태',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in reservation.checkPayload.entries)
                    Chip(label: Text('${entry.key}: ${entry.value}')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'outbox dry-run',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final line in outboxPreview) Text('• $line')],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '업무 로그',
              child: logs.isEmpty
                  ? const Text('아직 실행 로그가 없습니다.')
                  : Column(
                      children: [
                        for (final log in logs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(log.label),
                            subtitle: Text(
                              '${_formatDateTime(log.executedAt)} · ${log.note}',
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _SectionCard(title: '메모', child: Text(reservation.noteText)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('예약 정보를 불러오지 못했습니다.\n$error')),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.month)}/${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

String _displayValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}
