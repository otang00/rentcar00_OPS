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

class StatusBoardScheduleFab extends ConsumerStatefulWidget {
  const StatusBoardScheduleFab({super.key});

  @override
  ConsumerState<StatusBoardScheduleFab> createState() =>
      _StatusBoardScheduleFabState();
}

class _StatusBoardScheduleFabState
    extends ConsumerState<StatusBoardScheduleFab> {
  bool _submitting = false;

  Future<void> _openCreateSchedule() async {
    if (_submitting) return;

    final form = await showDialog<_ScheduleCreateFormResult>(
      context: context,
      builder: (context) => const _ScheduleCreateDialog(),
    );
    if (form == null) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(supabaseOpsRepositoryProvider)
          .createScheduleOnly(
            scheduleType: form.scheduleType,
            scheduleAt: form.scheduleAt,
            carNumber: form.carNumber,
            carName: form.carName,
            locationText: form.locationText,
            detailText: form.detailText,
          );
      if (!mounted) return;
      ref.invalidate(allStatusBoardRecordsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 생성했습니다.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _submitting ? null : _openCreateSchedule,
      tooltip: '일정 생성',
      child: _submitting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add),
    );
  }
}

class _ScheduleCreateDialog extends StatefulWidget {
  const _ScheduleCreateDialog();

  @override
  State<_ScheduleCreateDialog> createState() => _ScheduleCreateDialogState();
}

class _ScheduleCreateDialogState extends State<_ScheduleCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleTypes = const ['배차', '반납'];
  late String _scheduleType;
  late final TextEditingController _scheduleAtController;
  late final TextEditingController _carNumberController;
  late final TextEditingController _carNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    _scheduleType = _scheduleTypes.first;
    _scheduleAtController = TextEditingController(
      text: _formatScheduleEditorDateTime(initial),
    );
    _carNumberController = TextEditingController();
    _carNameController = TextEditingController();
    _locationController = TextEditingController();
    _detailController = TextEditingController();
  }

  @override
  void dispose() {
    _scheduleAtController.dispose();
    _carNumberController.dispose();
    _carNameController.dispose();
    _locationController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial =
        _tryParseScheduleDateTime(_scheduleAtController.text.trim()) ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _scheduleAtController.text = _formatScheduleEditorDateTime(combined);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('일정 생성'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue: _scheduleType,
                    decoration: const InputDecoration(
                      labelText: '일정유형',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final type in _scheduleTypes)
                        DropdownMenuItem(value: type, child: Text(type)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _scheduleType = value);
                    },
                  ),
                ),
                _ScheduleDialogTextField(
                  controller: _scheduleAtController,
                  label: '일정시각',
                  validator: _scheduleDateTimeValidator,
                  readOnly: true,
                  onTap: _pickDateTime,
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                _ScheduleDialogTextField(
                  controller: _carNumberController,
                  label: '차량번호',
                ),
                _ScheduleDialogTextField(
                  controller: _carNameController,
                  label: '차종',
                ),
                _ScheduleDialogTextField(
                  controller: _locationController,
                  label: '위치',
                ),
                _ScheduleDialogTextField(
                  controller: _detailController,
                  label: '상세정보',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final scheduleAt = _tryParseScheduleDateTime(
              _scheduleAtController.text.trim(),
            );
            if (scheduleAt == null) return;
            Navigator.of(context).pop(
              _ScheduleCreateFormResult(
                scheduleType: _scheduleType,
                scheduleAt: scheduleAt,
                carNumber: _carNumberController.text.trim(),
                carName: _carNameController.text.trim(),
                locationText: _locationController.text.trim(),
                detailText: _detailController.text.trim(),
              ),
            );
          },
          child: const Text('생성'),
        ),
      ],
    );
  }
}

class _ScheduleDialogTextField extends StatelessWidget {
  const _ScheduleDialogTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ScheduleCreateFormResult {
  const _ScheduleCreateFormResult({
    required this.scheduleType,
    required this.scheduleAt,
    required this.carNumber,
    required this.carName,
    required this.locationText,
    required this.detailText,
  });

  final String scheduleType;
  final DateTime scheduleAt;
  final String carNumber;
  final String carName;
  final String locationText;
  final String detailText;
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

String _formatScheduleEditorDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

DateTime? _tryParseScheduleDateTime(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T')) ??
      DateTime.tryParse(raw);
}

String? _scheduleDateTimeValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '필수 입력입니다.';
  }
  if (_tryParseScheduleDateTime(value) == null) {
    return '예: 2026-05-11 10:00';
  }
  return null;
}
