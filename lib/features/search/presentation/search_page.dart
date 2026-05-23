import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_summary.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider).trim();
    final schedulesAsync = ref.watch(filteredScheduleRecordsProvider);
    final vehiclesAsync = ref.watch(filteredVehicleRecordsProvider);
    final reservationsAsync = ref.watch(filteredReservationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: RefreshIndicator(
        triggerMode: RefreshIndicatorTriggerMode.anywhere,
        onRefresh: () async {
          ref.invalidate(allStatusBoardRecordsProvider);
          ref.invalidate(allReservationsProvider);
          await Future.wait([
            ref.read(allStatusBoardRecordsProvider.future),
            ref.read(allReservationsProvider.future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '일정 / 차량 / 예약 검색',
                hintText: '고객명, 차량번호, 예약번호, 위치, 비고',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 16),
            _AsyncSearchSection<StatusBoardRecord>(
              title: '차량',
              query: query,
              itemsAsync: vehiclesAsync,
              emptyText: '차량 검색 결과가 없습니다.',
              itemBuilder: (context, item) => _VehicleResultCard(item: item),
            ),
            const SizedBox(height: 16),
            _AsyncSearchSection<StatusBoardRecord>(
              title: '일정',
              query: query,
              itemsAsync: schedulesAsync,
              emptyText: '일정 검색 결과가 없습니다.',
              itemBuilder: (context, item) => _ScheduleResultCard(item: item),
            ),
            const SizedBox(height: 16),
            _AsyncSearchSection<ReservationSummary>(
              title: '예약',
              query: query,
              itemsAsync: reservationsAsync,
              emptyText: '예약 검색 결과가 없습니다.',
              itemBuilder: (context, item) =>
                  _ReservationResultCard(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncSearchSection<T> extends StatelessWidget {
  const _AsyncSearchSection({
    required this.title,
    required this.query,
    required this.itemsAsync,
    required this.emptyText,
    required this.itemBuilder,
  });

  final String title;
  final String query;
  final AsyncValue<List<T>> itemsAsync;
  final String emptyText;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return itemsAsync.when(
      data: (items) {
        final visibleItems = query.isEmpty ? items.take(5).toList() : items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ${items.length}건',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(query.isEmpty ? '$title 데이터가 없습니다.' : emptyText),
                ),
              )
            else ...[
              for (final item in visibleItems) itemBuilder(context, item),
              if (query.isEmpty && items.length > visibleItems.length)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    '검색어를 입력하면 전체 결과를 볼 수 있습니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$title 데이터를 불러오지 못했습니다.\n$error'),
        ),
      ),
    );
  }
}

class _ScheduleResultCard extends StatelessWidget {
  const _ScheduleResultCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    final type = item.scheduleType.isEmpty ? '일정' : item.scheduleType;
    final title = '${item.timeLabel.isEmpty ? '-' : item.timeLabel} · $type';
    final subtitle = [
      item.carNumber,
      item.carName,
      item.customerName,
      item.locationSummary,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return _SearchResultCard(
      icon: Icons.event_note_outlined,
      title: title,
      subtitle: subtitle.isEmpty ? '-' : subtitle,
      trailingIcon: item.reservationId.isEmpty ? null : Icons.link,
      onTap: () =>
          context.push('/schedule/${Uri.encodeComponent(item.recordId)}'),
    );
  }
}

class _VehicleResultCard extends StatelessWidget {
  const _VehicleResultCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      item.carName,
      item.status,
      item.customerName,
      item.locationSummary,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return _SearchResultCard(
      icon: Icons.directions_car_filled_outlined,
      title: item.carNumber.isEmpty ? '(차량번호없음)' : item.carNumber,
      subtitle: subtitle.isEmpty ? '-' : subtitle,
      onTap: () => context.push('/board/${Uri.encodeComponent(item.recordId)}'),
    );
  }
}

class _ReservationResultCard extends StatelessWidget {
  const _ReservationResultCard({required this.item});

  final ReservationSummary item;

  @override
  Widget build(BuildContext context) {
    final title = [
      item.customerName.isEmpty ? '(고객명없음)' : item.customerName,
      item.carNumber,
    ].where((value) => value.trim().isNotEmpty).join(' · ');

    return _SearchResultCard(
      icon: Icons.assignment_outlined,
      title: title,
      subtitle:
          '${item.reservationNumber.isEmpty ? item.reservationId : item.reservationNumber} · ${item.tab.label} · ${item.timeLabel}',
      onTap: () => context.push('/reservation/${item.reservationId}'),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: colorScheme.outline),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
