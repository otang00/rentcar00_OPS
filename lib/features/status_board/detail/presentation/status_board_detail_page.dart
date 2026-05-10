import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class StatusBoardDetailPage extends ConsumerWidget {
  const StatusBoardDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(statusBoardDetailProvider(recordId));

    return Scaffold(
      appBar: AppBar(title: const Text('현황판 상세')),
      body: recordAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('현황판 정보를 찾을 수 없습니다.'));
          }
          return _StatusBoardDetailBody(recordId: recordId, record: record);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('현황판 상세를 불러오지 못했습니다.\n$error')),
      ),
    );
  }
}

class _StatusBoardDetailBody extends ConsumerWidget {
  const _StatusBoardDetailBody({required this.recordId, required this.record});

  final String recordId;
  final StatusBoardRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedSchedulesAsync = ref.watch(relatedSchedulesProvider(recordId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${record.carNumber.isEmpty ? '(차량번호없음)' : record.carNumber} · ${record.carName.isEmpty ? '차종 미확인' : record.carName}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          record.status.isEmpty
              ? record.tab.label
              : '${record.tab.label} · ${record.status}',
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '기본 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '임차인', value: record.customerName),
              _FieldLine(label: '고객번호', value: record.customerPhone),
              _FieldLine(label: '대여일', value: record.startAt),
              _FieldLine(label: '반납일', value: record.endAt),
              _FieldLine(label: '배차지', value: record.pickupLocation),
              _FieldLine(label: '주차지', value: record.parkingLocation),
              if (record.scheduleType.isNotEmpty)
                _FieldLine(label: '일정유형', value: record.scheduleType),
              if (record.detailText.isNotEmpty)
                _FieldLine(label: '상세정보', value: record.detailText),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '차량 관리',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLine(label: '세차', value: record.carWash),
              _FieldLine(label: '실내세차', value: record.interiorWash),
              _FieldLine(label: '상태액션', value: record.statusAction),
              _FieldLine(label: '비고', value: record.noteText),
            ],
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
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('일정 정보를 불러오지 못했습니다.\n$error'),
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
