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
    final items = ref.watch(tabListProvider(tab));
    final counts = ref.watch(tabCountsProvider);
    final count = counts[tab] ?? 0;

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
        for (final item in items)
          Card(
            child: InkWell(
              onTap: () => context.push('/reservation/${item.reservationId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.customerName} · ${item.carNumber} · ${item.locationSummary} · ${item.reservationId}',
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
    '신분증 미확보' => '신분증',
    '주소 미확보' => '주소',
    '준비 미완료' => '준비',
    '계약 미완료' => '계약',
    '반납 임박' => '임박',
    '반납완료 직전 미처리' => '미처리',
    '특이사항' => '특이',
    '준비 완료' => '완료',
    '이용 중' => '이용',
    '반납 완료' => '반납',
    _ => label,
  };
}
