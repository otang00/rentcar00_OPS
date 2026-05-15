import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_summary.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/shared/utils/korean_holidays.dart';

class ReservationTabPage extends ConsumerWidget {
  const ReservationTabPage({super.key, required this.tab});

  final ReservationTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tabListProvider(tab));

    return itemsAsync.when(
      data: (items) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('현재 이 탭에 표시할 실데이터가 없습니다.'),
                ),
              )
            else
              for (final item in items) _ReservationStatusCard(item: item),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('탭 데이터를 불러오지 못했습니다.\n$error')),
    );
  }
}

class _ReservationStatusCard extends StatelessWidget {
  const _ReservationStatusCard({required this.item});

  final ReservationSummary item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    Widget cell(
      String value, {
      required int flex,
      bool alignEnd = false,
      bool emphasize = false,
      Color? color,
    }) {
      return Expanded(
        flex: flex,
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style:
                (emphasize
                        ? textTheme.titleSmall
                        : (flex <= 3
                              ? textTheme.titleSmall
                              : textTheme.bodyMedium))
                    ?.copyWith(
                      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                      color: color,
                    ),
          ),
        ),
      );
    }

    final carName = item.carName.isEmpty ? '-' : item.carName;
    final customer = item.customerName.isEmpty ? '-' : item.customerName;
    final location = item.locationSummary.isEmpty ? '-' : item.locationSummary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/reservation/${item.reservationId}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      item.carNumber.isEmpty ? '(차량번호없음)' : item.carNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: _ReservationDateInfoCell(
                      label: _compactDateWithWeekday(item.startAt),
                      time: _timeOnlyFromDate(item.startAt),
                      color: opsDateColor(item.startAt),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _ReservationDateInfoCell(
                      label: _compactDateWithWeekday(item.endAt),
                      time: _timeOnlyFromDate(item.endAt),
                      color: opsDateColor(item.endAt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  cell(customer, flex: 3, emphasize: true),
                  const SizedBox(width: 4),
                  cell(carName, flex: 3),
                  const SizedBox(width: 4),
                  cell(
                    location,
                    flex: 2,
                    alignEnd: true,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
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
    );
  }
}

class _ReservationDateInfoCell extends StatelessWidget {
  const _ReservationDateInfoCell({
    required this.label,
    required this.time,
    required this.color,
  });

  final String label;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final timeColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: timeColor,
          ),
        ),
      ],
    );
  }
}

String _compactDateWithWeekday(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final yy = (local.year % 100).toString().padLeft(2, '0');
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '$yy.${two(local.month)}.${two(local.day)}(${weekdays[local.weekday - 1]})';
}

String _timeOnlyFromDate(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
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
