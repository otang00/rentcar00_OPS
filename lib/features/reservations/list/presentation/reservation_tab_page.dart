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
                      vertical: 9,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text: item.carNumber,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                    TextSpan(
                                      text:
                                          '  ${item.carName.isEmpty ? (item.reservationNumber.isEmpty ? '차량명 미확인' : item.reservationNumber) : item.carName}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _DateTimeLabel(timeLabel: item.timeLabel),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.locationSummary.isEmpty
                              ? '(주소없음)'
                              : item.locationSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (item.primaryBadges.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final badge in item.primaryBadges)
                                _StatusIconChip(label: badge),
                            ],
                          ),
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

Color _dateColorForLabel(BuildContext context, String label) {
  if (label.contains('(토)')) {
    return Colors.blue;
  }
  if (label.contains('(일)')) {
    return Colors.red;
  }
  return Theme.of(context).colorScheme.primary;
}

class _DateTimeLabel extends StatelessWidget {
  const _DateTimeLabel({required this.timeLabel});

  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final parts = timeLabel.split(' ');
    final dateText = parts.isNotEmpty ? parts.first : timeLabel;
    final timeText = parts.length > 1 ? parts.last : '';
    final color = _dateColorForLabel(context, timeLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          dateText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (timeText.isNotEmpty)
          Text(
            timeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _StatusIconChip extends StatelessWidget {
  const _StatusIconChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final token = _iconToken(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(token.icon, size: 12, color: token.color),
          const SizedBox(width: 3),
          Text(
            token.text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color? color, String text}) _iconToken(String label) {
  return switch (label) {
    '확인 필요' => (icon: Icons.error_outline, color: Colors.red, text: '확인'),
    '특이사항' => (
      icon: Icons.priority_high_rounded,
      color: Colors.red,
      text: '특이',
    ),
    '반납완료 직전 미처리' => (
      icon: Icons.assignment_late_outlined,
      color: Colors.red,
      text: '반납전',
    ),
    '신분증 미확보' => (
      icon: Icons.badge_outlined,
      color: Colors.orange,
      text: '신분증',
    ),
    '주소 미확보' => (
      icon: Icons.home_work_outlined,
      color: Colors.orange,
      text: '주소',
    ),
    '고객명 미확인' => (
      icon: Icons.person_off_outlined,
      color: Colors.orange,
      text: '고객',
    ),
    '연락처 미확인' => (
      icon: Icons.phone_disabled_outlined,
      color: Colors.orange,
      text: '연락처',
    ),
    '위치 미확인' => (
      icon: Icons.location_off_outlined,
      color: Colors.orange,
      text: '위치',
    ),
    '준비 미완료' => (
      icon: Icons.hourglass_bottom_outlined,
      color: Colors.orange,
      text: '준비',
    ),
    '계약 미완료' => (
      icon: Icons.description_outlined,
      color: Colors.orange,
      text: '계약',
    ),
    '반납 임박' => (
      icon: Icons.event_busy_outlined,
      color: Colors.blue,
      text: '임박',
    ),
    '연장·이슈' => (icon: Icons.update_outlined, color: Colors.blue, text: '연장'),
    '예약취소' => (icon: Icons.block_outlined, color: Colors.red, text: '취소'),
    '반납 완료' => (icon: Icons.task_alt_outlined, color: Colors.green, text: '완료'),
    '오늘배차' => (
      icon: Icons.local_shipping_outlined,
      color: Colors.blue,
      text: '오늘',
    ),
    '이상 없음' => (
      icon: Icons.check_circle_outline,
      color: Colors.green,
      text: '정상',
    ),
    _ => (icon: Icons.info_outline, color: null, text: label),
  };
}
