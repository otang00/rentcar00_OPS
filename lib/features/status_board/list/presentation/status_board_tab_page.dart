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

    return itemsAsync.when(
      data: (items) {
        final sortedItems = _sortItems(tab, items);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            if (sortedItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('현재 이 탭에 표시할 실데이터가 없습니다.'),
                ),
              )
            else
              ..._buildTabContent(context, sortedItems),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('현황판 데이터를 불러오지 못했습니다.\n$error')),
    );
  }

  List<Widget> _buildTabContent(
    BuildContext context,
    List<StatusBoardRecord> items,
  ) {
    switch (tab) {
      case StatusBoardTab.idle:
        return _buildIdleContent(context, items);
      case StatusBoardTab.insurance:
        return [for (final item in items) _InsuranceCard(item: item)];
      case StatusBoardTab.general:
        return [_GeneralTable(items: items)];
      case StatusBoardTab.longTerm:
        return [_LongTermTable(items: items)];
      case StatusBoardTab.schedule:
        return _buildScheduleContent(context, items);
    }
  }

  List<Widget> _buildIdleContent(
    BuildContext context,
    List<StatusBoardRecord> items,
  ) {
    final groups = <String, List<StatusBoardRecord>>{};
    for (final item in items) {
      final key = item.carName.isEmpty ? '차종 미확인' : item.carName;
      groups.putIfAbsent(key, () => []).add(item);
    }

    return [
      for (var index = 0; index < groups.entries.length; index++) ...[
        Container(
          decoration: _tableDecoration(context),
          child: Column(
            children: [
              if (index == 0) const _IdleGridHeader(),
              _IdleGroupHeader(
                label: groups.entries.elementAt(index).key,
                count: groups.entries.elementAt(index).value.length,
                isFirst: index == 0,
              ),
              for (
                var i = 0;
                i < groups.entries.elementAt(index).value.length;
                i++
              )
                _IdleDataRow(
                  item: groups.entries.elementAt(index).value[i],
                  showDivider:
                      i < groups.entries.elementAt(index).value.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  List<Widget> _buildScheduleContent(
    BuildContext context,
    List<StatusBoardRecord> items,
  ) {
    final groups = <String, List<StatusBoardRecord>>{};
    for (final item in items) {
      final parsed = item.sortAt;
      final key = parsed == null
          ? '미확인 일정'
          : '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(item);
    }

    return [
      for (final entry in groups.entries) ...[
        _ScheduleDateHeader(dateKey: entry.key, firstItem: entry.value.first),
        for (final item in entry.value) _ScheduleCard(item: item),
        const SizedBox(height: 8),
      ],
    ];
  }

  List<StatusBoardRecord> _sortItems(
    StatusBoardTab tab,
    List<StatusBoardRecord> items,
  ) {
    final sorted = [...items];
    int compareText(String a, String b) => a.compareTo(b);

    switch (tab) {
      case StatusBoardTab.idle:
        sorted.sort((a, b) {
          final byName = compareText(a.carName, b.carName);
          if (byName != 0) return byName;
          return compareText(a.carNumber, b.carNumber);
        });
      case StatusBoardTab.insurance:
      case StatusBoardTab.general:
        sorted.sort((a, b) {
          final aTime = a.sortAt ?? DateTime(2999);
          final bTime = b.sortAt ?? DateTime(2999);
          final byTime = aTime.compareTo(bTime);
          if (byTime != 0) return byTime;
          return compareText(a.carNumber, b.carNumber);
        });
      case StatusBoardTab.longTerm:
        sorted.sort((a, b) {
          final aTime = a.sortAt ?? DateTime(2999);
          final bTime = b.sortAt ?? DateTime(2999);
          final byTime = aTime.compareTo(bTime);
          if (byTime != 0) return byTime;
          return compareText(a.carNumber, b.carNumber);
        });
      case StatusBoardTab.schedule:
        sorted.sort((a, b) {
          final aTime = a.sortAt ?? DateTime(2999);
          final bTime = b.sortAt ?? DateTime(2999);
          return aTime.compareTo(bTime);
        });
    }

    return sorted;
  }
}

class _InsuranceCard extends StatelessWidget {
  const _InsuranceCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push('/board/${Uri.encodeComponent(item.recordId)}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.pickupLocation.isEmpty ? '(배차지없음)' : item.pickupLocation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (item.noteText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.noteText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                item.carNumber.isEmpty ? '(차량번호없음)' : item.carNumber,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.carName.isEmpty ? '(차종없음)' : item.carName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _fullDate(item.startAt),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                'GO TO DETAILS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneralTable extends StatelessWidget {
  const _GeneralTable({required this.items});

  final List<StatusBoardRecord> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tableDecoration(context),
      child: Column(
        children: [
          const _TableHeader(
            columns: [
              _HeaderColumn('차량번호', flex: 3),
              _HeaderColumn('차종', flex: 2),
              _HeaderColumn('대여', flex: 2, alignEnd: true),
              _HeaderColumn('반납', flex: 2, alignEnd: true),
            ],
          ),
          for (var i = 0; i < items.length; i++)
            _GeneralTableRow(item: items[i], showDivider: i < items.length - 1),
        ],
      ),
    );
  }
}

class _LongTermTable extends StatelessWidget {
  const _LongTermTable({required this.items});

  final List<StatusBoardRecord> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _tableDecoration(context),
      child: Column(
        children: [
          const _TableHeader(
            columns: [
              _HeaderColumn('차량번호', flex: 3),
              _HeaderColumn('차종', flex: 2),
              _HeaderColumn('반납년월일', flex: 3, alignEnd: true),
              _HeaderColumn('임차인', flex: 3),
            ],
          ),
          for (var i = 0; i < items.length; i++)
            _LongTermTableRow(
              item: items[i],
              showDivider: i < items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ScheduleDateHeader extends StatelessWidget {
  const _ScheduleDateHeader({required this.dateKey, required this.firstItem});

  final String dateKey;
  final StatusBoardRecord firstItem;

  @override
  Widget build(BuildContext context) {
    final parsed = firstItem.sortAt;
    final color = _scheduleHeaderColor(context, parsed);
    final label = parsed == null ? dateKey : _scheduleHeaderLabel(parsed);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () =>
            context.push('/schedule/${Uri.encodeComponent(item.recordId)}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  item.timeLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.carNumber} · ${item.scheduleType}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.locationSummary.isEmpty ? '-' : item.locationSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleDataRow extends StatelessWidget {
  const _IdleDataRow({required this.item, required this.showDivider});

  final StatusBoardRecord item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push('/board/${Uri.encodeComponent(item.recordId)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                item.carNumber.isEmpty ? '(차량번호없음)' : item.carNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: Text(
                item.carName.isEmpty ? '-' : item.carName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _WashStatusIcon(
                    active: _isActive(item.carWash),
                    icon: Icons.local_car_wash_rounded,
                    semanticLabel: '외부 세차',
                  ),
                  _WashStatusIcon(
                    active: _isActive(item.interiorWash),
                    icon: Icons.airline_seat_recline_normal_rounded,
                    semanticLabel: '내부 세차',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.parkingLocation.isEmpty ? '-' : item.parkingLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: textTheme.bodySmall?.copyWith(height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleGridHeader extends StatelessWidget {
  const _IdleGridHeader();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          SizedBox(width: 112, child: Text('차량번호', style: textStyle)),
          const SizedBox(width: 8),
          SizedBox(width: 82, child: Text('차종', style: textStyle)),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Center(child: Text('세차', style: textStyle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('주차지', style: textStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _IdleGroupHeader extends StatelessWidget {
  const _IdleGroupHeader({
    required this.label,
    required this.count,
    required this.isFirst,
  });

  final String label;
  final int count;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: isFirst
            ? null
            : const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          top: isFirst
              ? BorderSide.none
              : BorderSide(color: Theme.of(context).dividerColor),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        '$label ($count)',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});

  final List<_HeaderColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              flex: column.flex,
              child: Align(
                alignment: column.alignEnd
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Text(
                  column.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeneralTableRow extends StatelessWidget {
  const _GeneralTableRow({required this.item, required this.showDivider});

  final StatusBoardRecord item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final returnDue = item.endAt.isNotEmpty;
    return InkWell(
      onTap: () => context.push('/board/${Uri.encodeComponent(item.recordId)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.carNumber,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(flex: 2, child: Text(item.carName)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _shortDate(item.startAt),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (returnDue)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.arrow_downward,
                          size: 14,
                          color: Color(0xFF8B1E1E),
                        ),
                      ),
                    Text(
                      _shortDate(item.endAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8B1E1E),
                        fontWeight: FontWeight.w800,
                        decoration: returnDue
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LongTermTableRow extends StatelessWidget {
  const _LongTermTableRow({required this.item, required this.showDivider});

  final StatusBoardRecord item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isEmphasized = _isPastDate(item.endAt);
    return InkWell(
      onTap: () => context.push('/board/${Uri.encodeComponent(item.recordId)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.carNumber,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(flex: 2, child: Text(item.carName)),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _fullDate(item.endAt),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isEmphasized ? const Color(0xFF8B1E1E) : null,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  item.customerName.isEmpty ? '-' : item.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderColumn {
  const _HeaderColumn(this.label, {required this.flex, this.alignEnd = false});

  final String label;
  final int flex;
  final bool alignEnd;
}

class _WashStatusIcon extends StatelessWidget {
  const _WashStatusIcon({
    required this.active,
    required this.icon,
    required this.semanticLabel,
  });

  final bool active;
  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green.shade700 : Colors.grey.shade400;
    return Tooltip(
      message: semanticLabel,
      child: Icon(icon, size: 16, color: color),
    );
  }
}

BoxDecoration _tableDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Theme.of(context).dividerColor),
  );
}

bool _isActive(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'true' ||
      normalized == 'y' ||
      normalized == 'yes' ||
      normalized == '1';
}

bool _isPastDate(String value) {
  final parsed = _parseFlexibleDate(value);
  if (parsed == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return parsed.isBefore(today);
}

DateTime? _parseFlexibleDate(String value) {
  if (value.isEmpty) return null;
  var normalized = value.trim();
  if (normalized.isEmpty) return null;
  normalized = normalized.replaceAll('.', '-').replaceAll('/', '-');
  normalized = normalized.replaceAll(RegExp(r'-+'), '-');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'-$'), '');
  if (normalized.length >= 10) {
    return DateTime.tryParse(normalized.substring(0, 10));
  }
  return DateTime.tryParse(normalized);
}

String _shortDate(String value) {
  if (value.isEmpty) return '-';
  if (value.length >= 10 && value.contains('-')) {
    return value.substring(5, 10);
  }
  if (value.length >= 10 && value.contains('.')) {
    return value.substring(5, 10);
  }
  return value;
}

String _fullDate(String value) {
  if (value.isEmpty) return '-';
  if (value.length >= 10 && value.contains('-')) {
    return value.substring(0, 10).replaceAll('-', '.');
  }
  return value;
}

String _scheduleHeaderLabel(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final weekday = weekdays[value.weekday - 1];
  return '${value.year}.${two(value.month)}.${two(value.day)}($weekday)';
}

Color? _scheduleHeaderColor(BuildContext context, DateTime? value) {
  if (value == null) return null;
  if (value.weekday == DateTime.sunday) {
    return const Color(0xFFB3261E);
  }
  if (value.weekday == DateTime.saturday) {
    return Colors.blue.shade700;
  }
  return Theme.of(context).textTheme.titleMedium?.color;
}
