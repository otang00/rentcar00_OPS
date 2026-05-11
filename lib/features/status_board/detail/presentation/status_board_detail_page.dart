import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/app/router/app_routes.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class StatusBoardDetailPage extends ConsumerWidget {
  const StatusBoardDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(statusBoardDetailProvider(recordId));

    return Scaffold(
      appBar: AppBar(title: const Text('상세')),
      body: recordAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('정보를 찾을 수 없습니다.'));
          }
          if (record.isScheduleEntry) {
            return _ScheduleDetailBody(record: record);
          }
          return _VehicleDetailBody(recordId: recordId, record: record);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('상세를 불러오지 못했습니다.\n$error')),
      ),
    );
  }
}

class _VehicleDetailBody extends ConsumerWidget {
  const _VehicleDetailBody({required this.recordId, required this.record});

  final String recordId;
  final StatusBoardRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedSchedulesAsync = ref.watch(relatedSchedulesProvider(recordId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(
          record.carNumber.isEmpty ? '(차량번호없음)' : record.carNumber,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          record.carName.isEmpty ? '차종 미확인' : record.carName,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            record.status.isEmpty
                ? record.tab.label
                : '${record.tab.label} · ${record.status}',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Related 일정',
          child: relatedSchedulesAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Text('연결된 일정이 없습니다.');
              }
              return Column(
                children: [
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        item.scheduleType.isEmpty
                            ? item.timeLabel
                            : '${item.scheduleType} · ${item.timeLabel}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        item.locationSummary.isEmpty
                            ? (item.detailText.isEmpty ? '-' : item.detailText)
                            : item.locationSummary,
                        style: textTheme.bodyMedium?.copyWith(height: 1.3),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/schedule/${Uri.encodeComponent(item.recordId)}',
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('일정 정보를 불러오지 못했습니다.\n$error'),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '운행 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(
                label: '임차인',
                value: record.customerName,
                emphasize: true,
              ),
              _FieldBlock(label: '고객번호', value: record.customerPhone),
              _FieldBlock(label: '대여일', value: record.startAt),
              _FieldBlock(label: '반납일', value: record.endAt),
              _FieldBlock(label: '배차지', value: record.pickupLocation),
              _FieldBlock(label: '주차지', value: record.parkingLocation),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '차량 관리 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(label: '세차', value: record.carWash),
              _FieldBlock(label: '실내세차', value: record.interiorWash),
              _FieldBlock(label: '차량등록일', value: record.carRegisteredAt),
              _FieldBlock(label: '차량검사일', value: record.carInspectionAt),
              _FieldBlock(label: '차령만료일', value: record.carAgeExpiryAt),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '차량 번호 세부',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(
                label: '차량번호(앞)',
                value: record.carNumberFront,
                emphasize: true,
              ),
              _FieldBlock(
                label: '차량번호(중)',
                value: record.carNumberMiddle,
                emphasize: true,
              ),
              _FieldBlock(
                label: '차량번호(네자리)',
                value: record.carNumberRear,
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '메모 / 상태',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(label: '상태액션', value: record.statusAction),
              _FieldBlock(label: '비고', value: record.noteText, multiline: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleDetailBody extends StatelessWidget {
  const _ScheduleDetailBody({required this.record});

  final StatusBoardRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text(
          record.scheduleType.isEmpty ? '일정 디테일' : record.scheduleType,
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          record.timeLabel.isEmpty ? '-' : record.timeLabel,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            record.carNumber.isEmpty ? '차량번호 미확인' : record.carNumber,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '일정 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldBlock(
                label: '일정번호',
                value: record.scheduleId,
                emphasize: true,
              ),
              _FieldBlock(label: '일정유형', value: record.scheduleType),
              _FieldBlock(label: '일정시각', value: record.startAt),
              _FieldBlock(
                label: '차량번호',
                value: record.carNumber,
                emphasize: true,
              ),
              _FieldBlock(label: '차종', value: record.carName),
              _FieldBlock(label: '위치', value: record.locationSummary),
              _FieldBlock(
                label: '상세정보',
                value: record.detailText,
                multiline: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '예약 연결',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LinkedFieldBlock(
                label: '예약번호',
                value: record.reservationNumber,
                enabled: record.reservationId.isNotEmpty,
                onTap: record.reservationId.isNotEmpty
                    ? () => context.push(
                        AppRoutes.reservationDetail.replaceFirst(
                          ':reservationId',
                          Uri.encodeComponent(record.reservationId),
                        ),
                      )
                    : null,
              ),
              _FieldBlock(label: '예약ID', value: record.reservationId),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = value.isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            display,
            maxLines: multiline ? null : 2,
            overflow: multiline ? null : TextOverflow.ellipsis,
            style: (emphasize ? textTheme.titleMedium : textTheme.bodyLarge)
                ?.copyWith(
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  height: 1.3,
                ),
          ),
        ],
      ),
    );
  }
}

class _LinkedFieldBlock extends StatelessWidget {
  const _LinkedFieldBlock({
    required this.label,
    required this.value,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final display = value.isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              display,
              style: textTheme.titleMedium?.copyWith(
                color: enabled ? colorScheme.primary : null,
                decoration: enabled ? TextDecoration.underline : null,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
