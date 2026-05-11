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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          record.carNumber.isEmpty ? '(차량번호없음)' : record.carNumber,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          record.carName.isEmpty ? '차종 미확인' : record.carName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          record.status.isEmpty
              ? record.tab.label
              : '${record.tab.label} · ${record.status}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
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
                      title: Text(
                        item.scheduleType.isEmpty
                            ? item.timeLabel
                            : '${item.scheduleType} · ${item.timeLabel}',
                      ),
                      subtitle: Text(
                        item.locationSummary.isEmpty
                            ? (item.detailText.isEmpty ? '-' : item.detailText)
                            : item.locationSummary,
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
        const SizedBox(height: 12),
        _SectionCard(
          title: '운행 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '임차인', value: record.customerName),
              _FieldLine(label: '고객번호', value: record.customerPhone),
              _FieldLine(label: '대여일', value: record.startAt),
              _FieldLine(label: '반납일', value: record.endAt),
              _FieldLine(label: '배차지', value: record.pickupLocation),
              _FieldLine(label: '주차지', value: record.parkingLocation),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '차량 관리 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '세차', value: record.carWash),
              _FieldLine(label: '실내세차', value: record.interiorWash),
              _FieldLine(label: '차량등록일', value: record.carRegisteredAt),
              _FieldLine(label: '차량검사일', value: record.carInspectionAt),
              _FieldLine(label: '차령만료일', value: record.carAgeExpiryAt),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '차량 번호 세부',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '차량번호(앞)', value: record.carNumberFront),
              _FieldLine(label: '차량번호(중)', value: record.carNumberMiddle),
              _FieldLine(label: '차량번호(네자리)', value: record.carNumberRear),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '메모 / 상태',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '상태액션', value: record.statusAction),
              _FieldLine(label: '비고', value: record.noteText),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          record.scheduleType.isEmpty ? '일정 디테일' : record.scheduleType,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          record.timeLabel.isEmpty ? '-' : record.timeLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '일정 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '일정번호', value: record.scheduleId),
              _FieldLine(label: '일정유형', value: record.scheduleType),
              _FieldLine(label: '일정시각', value: record.startAt),
              _FieldLine(label: '차량번호', value: record.carNumber),
              _FieldLine(label: '차종', value: record.carName),
              _FieldLine(label: '위치', value: record.locationSummary),
              _FieldLine(label: '상세정보', value: record.detailText),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '예약 연결',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LinkedFieldLine(
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
              _FieldLine(label: '예약ID', value: record.reservationId),
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

class _FieldLine extends StatelessWidget {
  const _FieldLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: ${value.isEmpty ? '-' : value}'),
    );
  }
}

class _LinkedFieldLine extends StatelessWidget {
  const _LinkedFieldLine({
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
    final display = value.isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Text(
          '$label: $display',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: enabled ? Theme.of(context).colorScheme.primary : null,
            decoration: enabled ? TextDecoration.underline : null,
            fontWeight: enabled ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}
