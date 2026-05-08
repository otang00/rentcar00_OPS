import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class ReservationTabPage extends ConsumerWidget {
  const ReservationTabPage({super.key, required this.tab});

  final ReservationTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tabListProvider(tab));
    final countsAsync = ref.watch(tabCountsProvider);

    return itemsAsync.when(
      data: (items) {
        final count = countsAsync.valueOrNull?[tab] ?? items.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${tab.label} $count건',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              tab.emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('현재 이 탭에 표시할 실데이터가 없습니다.'),
                ),
              ),
            for (final item in items)
              Card(
                child: InkWell(
                  onTap: () =>
                      context.push('/reservation/${item.reservationId}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.customerName.isEmpty ? '(고객명없음)' : item.customerName} · ${item.carNumber} · ${item.locationSummary.isEmpty ? '(위치없음)' : item.locationSummary} · ${item.reservationId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.timeLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(width: 6),
                        for (final badge in item.primaryBadges.take(2)) ...[
                          _CompactBadge(label: _badgeAbbr(badge)),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('탭 데이터를 불러오지 못했습니다.\n$error')),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

String _badgeAbbr(String label) {
  return switch (label) {
    '고객명 미확인' => '고객',
    '연락처 미확인' => '연락처',
    '위치 미확인' => '위치',
    '예약취소' => '취소',
    '반납 완료' => '완료',
    '오늘배차' => '오늘',
    '확인 필요' => '확인',
    _ => label,
  };
}
