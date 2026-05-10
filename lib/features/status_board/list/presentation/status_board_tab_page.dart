import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';

class StatusBoardTabPage extends ConsumerWidget {
  const StatusBoardTabPage({super.key, required this.tab});

  final StatusBoardTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(statusBoardListProvider(tab));
    final countsAsync = ref.watch(statusBoardCountsProvider);

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
            for (final item in items) _BoardListCard(item: item),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('현황판 데이터를 불러오지 못했습니다.\n$error')),
    );
  }
}

class _BoardListCard extends StatelessWidget {
  const _BoardListCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    final title = item.carName.isEmpty ? '차종 미확인' : item.carName;
    final subtitle = item.customerName.isEmpty
        ? (item.status.isEmpty ? '-' : item.status)
        : item.customerName;

    return Card(
      child: InkWell(
        onTap: () =>
            context.push('/board/${Uri.encodeComponent(item.recordId)}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.carNumber.isEmpty ? '(차량번호없음)' : item.carNumber,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$title · $subtitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.tab.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (item.timeLabel.isNotEmpty)
                        Text(
                          item.timeLabel,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.person_outline,
                text: item.customerName.isEmpty ? '(임차인없음)' : item.customerName,
              ),
              if (item.locationSummary.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: item.locationSummary,
                ),
              ],
              if (item.startAt.isNotEmpty || item.endAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoLine(
                  icon: Icons.schedule_outlined,
                  text: _periodText(item),
                ),
              ],
              if (item.primaryBadges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final badge in item.primaryBadges)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(badge),
                      ),
                  ],
                ),
              ],
              if (item.noteText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.noteText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _periodText(StatusBoardRecord item) {
    if (item.startAt.isEmpty && item.endAt.isEmpty) return '-';
    if (item.startAt.isEmpty) return item.endAt;
    if (item.endAt.isEmpty) return item.startAt;
    return '${item.startAt} ~ ${item.endAt}';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
