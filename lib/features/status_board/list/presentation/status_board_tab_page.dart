import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcar00_ops/data/models/external_reservation_link.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_client.dart';
import 'package:rentcar00_ops/features/reservations/detail/presentation/ims_return_input_dialog.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';
import 'package:rentcar00_ops/features/status_board/shared/presentation/status_board_car_select_dialog.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';
import 'package:rentcar00_ops/shared/utils/korean_holidays.dart';
import 'package:rentcar00_ops/shared/utils/ops_kst_datetime.dart';

class StatusBoardTabPage extends ConsumerWidget {
  const StatusBoardTabPage({super.key, required this.tab});

  final StatusBoardTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(statusBoardListProvider(tab));

    return itemsAsync.when(
      data: (items) {
        final sortedItems = _sortItems(tab, items);
        return RefreshIndicator(
          triggerMode: RefreshIndicatorTriggerMode.anywhere,
          onRefresh: () async {
            ref.invalidate(allStatusBoardRecordsProvider);
            await ref.read(allStatusBoardRecordsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
          ),
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
      case StatusBoardTab.general:
      case StatusBoardTab.longTerm:
        return [for (final item in items) _ServiceStatusCard(item: item)];
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
      final key = parsed == null ? '미확인 일정' : opsLocalDateKey(parsed);
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

    final cachedRecords = ref.read(allStatusBoardRecordsProvider).valueOrNull;
    final List<StatusBoardRecord> records =
        cachedRecords ?? await ref.read(allStatusBoardRecordsProvider.future);
    final cars = records.where((item) => !item.isScheduleEntry).toList()
      ..sort((a, b) => a.carNumber.compareTo(b.carNumber));

    if (!mounted) return;
    final form = await showDialog<_ScheduleCreateFormResult>(
      context: context,
      builder: (context) => _ScheduleCreateDialog(cars: cars),
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
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      onPressed: _submitting ? null : _openCreateSchedule,
      tooltip: '일정 생성',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _submitting
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.add),
    );
  }
}

class _ScheduleCreateDialog extends StatefulWidget {
  const _ScheduleCreateDialog({required this.cars});

  final List<StatusBoardRecord> cars;

  @override
  State<_ScheduleCreateDialog> createState() => _ScheduleCreateDialogState();
}

class _ScheduleCreateDialogState extends State<_ScheduleCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleTypes = const ['배차', '반납', '기타'];
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

  Future<void> _pickCar() async {
    StatusBoardRecord? initialCar;
    for (final car in widget.cars) {
      if (car.carNumber.trim() == _carNumberController.text.trim()) {
        initialCar = car;
        break;
      }
    }
    final result = await showDialog<StatusBoardCarSelectResult>(
      context: context,
      builder: (context) => StatusBoardCarSelectDialog(
        cars: widget.cars,
        initialCar: initialCar,
        allowNone: true,
      ),
    );
    if (result == null || !mounted) return;
    if (result.cleared) {
      setState(() {
        _carNumberController.clear();
        _carNameController.clear();
      });
      return;
    }
    final car = result.car;
    if (car == null) return;
    setState(() {
      _carNumberController.text = car.carNumber;
      _carNameController.text = car.carName;
    });
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
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.event_available_outlined, color: colorScheme.primary),
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
                    decoration: const InputDecoration(labelText: '일정유형'),
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
                  suffixIcon: IconButton(
                    tooltip: '차량 선택',
                    onPressed: widget.cars.isEmpty ? null : _pickCar,
                    icon: const Icon(Icons.directions_car_filled_outlined),
                  ),
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
        decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
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

class _ServiceStatusCard extends StatelessWidget {
  const _ServiceStatusCard({required this.item});

  final StatusBoardRecord item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final startAt = _parseFlexibleDateTime(item.startAt);
    final endAt = _parseFlexibleDateTime(item.endAt);
    final carName = item.carName.isEmpty ? '-' : item.carName;
    final customer = item.customerName.isEmpty ? '-' : item.customerName;
    final location = item.pickupLocation.isEmpty ? '-' : item.pickupLocation;

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
        onTap: () =>
            context.push('/board/${Uri.encodeComponent(item.recordId)}'),
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
                    child: _ServiceDateInfoCell(
                      label: _compactDateWithWeekdayFromDateTime(startAt),
                      time: _timeOnlyFromDateTime(startAt),
                      direction: _DateDirection.pickup,
                      color: startAt == null
                          ? colorScheme.onSurfaceVariant
                          : opsDateColor(startAt),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: _ServiceDateInfoCell(
                      label: _compactDateWithWeekdayFromDateTime(endAt),
                      time: _timeOnlyFromDateTime(endAt),
                      direction: _DateDirection.returning,
                      color: endAt == null
                          ? colorScheme.onSurfaceVariant
                          : opsDateColor(endAt),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceDateInfoCell extends StatelessWidget {
  const _ServiceDateInfoCell({
    required this.label,
    required this.time,
    required this.direction,
    required this.color,
  });

  final String label;
  final String time;
  final _DateDirection direction;
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
        _DateTimeDirectionLine(
          time: time,
          direction: direction,
          timeColor: timeColor,
        ),
      ],
    );
  }
}

enum _DateDirection { pickup, returning }

class _DateTimeDirectionLine extends StatelessWidget {
  const _DateTimeDirectionLine({
    required this.time,
    required this.direction,
    required this.timeColor,
  });

  final String time;
  final _DateDirection direction;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    final isPickup = direction == _DateDirection.pickup;
    final arrow = isPickup ? '↑' : '↓';
    final arrowColor = isPickup
        ? const Color(0xFF1976D2)
        : const Color(0xFFD32F2F);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: timeColor,
      height: 1.0,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            arrow,
            maxLines: 1,
            style: style?.copyWith(
              color: arrowColor,
              fontWeight: FontWeight.w900,
              fontSize: (style.fontSize ?? 12) + 3,
              height: 0.9,
            ),
          ),
          const SizedBox(width: 2),
          Text(time, maxLines: 1, style: style),
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
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ScheduleCard extends ConsumerStatefulWidget {
  const _ScheduleCard({required this.item});

  final StatusBoardRecord item;

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> {
  bool _submitting = false;

  StatusBoardRecord get item => widget.item;

  Future<void> _completeSchedule() async {
    if (_submitting) return;
    final scheduleRowId = _extractScheduleRawRowId(item.recordId);
    if (scheduleRowId == null) {
      _showScheduleSnackBar('일정 row id를 찾지 못했습니다.');
      return;
    }
    final scheduleType = item.scheduleType.trim().isEmpty
        ? '일정'
        : item.scheduleType.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.task_alt_rounded),
        title: Text('$scheduleType 완료 처리할까요?'),
        content: Text(
          item.reservationId.trim().isEmpty
              ? '이 일정을 완료 처리합니다.'
              : '이 일정을 완료 처리하고 연결된 예약/차량 상태를 함께 갱신합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('완료'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final isLinkedReturn =
          item.scheduleType.trim() == '반납' &&
          item.reservationId.trim().isNotEmpty;
      final externalLink = isLinkedReturn
          ? await ref.read(
              externalReservationLinkProvider(item.reservationId).future,
            )
          : null;
      ImsReturnInputResult? imsReturnInput;
      if (externalLink?.isActiveBinding == true) {
        if (!mounted) return;
        imsReturnInput = await showDialog<ImsReturnInputResult>(
          context: context,
          builder: (context) => const ImsReturnInputDialog(),
        );
        if (imsReturnInput == null) return;
      }
      await ref
          .read(supabaseOpsRepositoryProvider)
          .completeSchedule(
            scheduleRowId: scheduleRowId,
            scheduleType: item.scheduleType,
            reservationId: item.reservationId,
            carNumber: item.carNumber,
          );
      var imsMessage = '';
      if (externalLink?.isActiveBinding == true) {
        final contractId = _resolveScheduleListImsReturnContractId(
          externalLink!,
        );
        if (contractId.isEmpty) {
          imsMessage = ' IMS 반납완료는 실패했습니다(IMS 계약 ID 없음).';
        } else {
          try {
            final appEnv = ref.read(appEnvProvider);
            final imsResult =
                await ImsReservationClient(
                  baseUrl: appEnv.aiParserBaseUrl,
                ).completeReservationReturn(
                  contractId: contractId,
                  reservationId: item.reservationId,
                  doneAt: DateTime.now(),
                  returnGasCharge: imsReturnInput!.returnGasCharge,
                  drivenDistanceUponReturn:
                      imsReturnInput.drivenDistanceUponReturn,
                  fuelCost: imsReturnInput.fuelCost,
                );
            imsMessage = imsResult.isSuccess
                ? ' IMS도 반납완료 처리했습니다.'
                : ' IMS 반납완료는 실패했습니다(${imsResult.message.isEmpty ? imsResult.code : imsResult.message}).';
          } catch (error) {
            imsMessage = ' IMS 반납완료는 실패했습니다($error).';
          }
        }
      }
      ref.invalidate(allStatusBoardRecordsProvider);
      ref.invalidate(allReservationsProvider);
      _showScheduleSnackBar('일정완료 처리했습니다.$imsMessage');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showScheduleSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scheduleType = item.scheduleType.trim();
    final isPickup = scheduleType == '배차';
    final isReturn = scheduleType == '반납';
    final cardColor = isReturn
        ? const Color(0xFFFFEBEE)
        : isPickup
        ? const Color(0xFFE3F2FD)
        : const Color(0xFFF3F4F6);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF202124), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push('/schedule/${Uri.encodeComponent(item.recordId)}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _scheduleDateOnly(item),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _scheduleTimeOnly(item),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.carNumber.isEmpty ? '-' : item.carNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 5),
                        _ScheduleTypeInlineIcon(
                          scheduleType: item.scheduleType,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.locationSummary.isEmpty ? '-' : item.locationSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ScheduleCompleteButton(
                scheduleType: item.scheduleType,
                submitting: _submitting,
                onPressed: _completeSchedule,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTypeInlineIcon extends StatelessWidget {
  const _ScheduleTypeInlineIcon({required this.scheduleType});

  final String scheduleType;

  @override
  Widget build(BuildContext context) {
    final icon = _scheduleTypeIcon(scheduleType);
    final color = _scheduleTypeColor(context, scheduleType);
    return Icon(icon, size: 18, color: color);
  }
}

class _ScheduleCompleteButton extends StatelessWidget {
  const _ScheduleCompleteButton({
    required this.scheduleType,
    required this.submitting,
    required this.onPressed,
  });

  final String scheduleType;
  final bool submitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = scheduleType.trim().isEmpty ? '일정' : scheduleType.trim();
    final color = _scheduleTypeColor(context, scheduleType);
    return SizedBox(
      width: 58,
      height: 48,
      child: FilledButton(
        onPressed: submitting ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isRepair = item.status.trim() == '수리중';
    final foregroundColor = isRepair ? Colors.white : null;
    final secondaryColor = isRepair
        ? Colors.white70
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => context.push('/board/${Uri.encodeComponent(item.recordId)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isRepair ? const Color(0xFF333842) : null,
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: isRepair
                        ? Colors.white24
                        : Theme.of(context).dividerColor,
                  ),
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
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Text(
                item.carName.isEmpty ? '-' : item.carName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: secondaryColor,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _WashStatusIcon(
                    active: _isActive(item.carWash),
                    icon: Icons.local_car_wash_rounded,
                    semanticLabel: '외부 세차',
                  ),
                  const SizedBox(width: 4),
                  _WashStatusIcon(
                    active: _isActive(item.interiorWash),
                    icon: Icons.airline_seat_recline_normal_rounded,
                    semanticLabel: '내부 세차',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (isRepair) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  '배차불가',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                item.parkingLocation.isEmpty ? '-' : item.parkingLocation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: textTheme.bodySmall?.copyWith(
                  color: isRepair ? Colors.white : null,
                  fontWeight: isRepair ? FontWeight.w800 : null,
                  height: 1.1,
                ),
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
          SizedBox(width: 68, child: Text('차종', style: textStyle)),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('세차', style: textStyle),
            ),
          ),
          const SizedBox(width: 6),
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
    final color = active ? Colors.blue.shade700 : Colors.grey.shade400;
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

DateTime? _parseFlexibleDate(String value) {
  final parsed = opsParseKstDateTime(value);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _parseFlexibleDateTime(String value) {
  return opsParseKstDateTime(value);
}

String _compactDateWithWeekdayFromDateTime(DateTime? value) {
  if (value == null) return '-';
  return opsFormatKstCompactDateWithWeekday(value);
}

String _timeOnlyFromDateTime(DateTime? value) {
  if (value == null) return '-';
  return opsFormatKstTime(value);
}

String _scheduleTimeOnly(StatusBoardRecord item) {
  final parsed = item.sortAt ?? _parseFlexibleDate(item.startAt);
  if (parsed == null) return item.timeLabel;
  return opsFormatKstTime(parsed);
}

String _scheduleDateOnly(StatusBoardRecord item) {
  final parsed = item.sortAt ?? _parseFlexibleDate(item.startAt);
  if (parsed == null) return '-';
  final kst = opsAsKstWallTime(parsed);
  return '${kst.month}/${kst.day}(${opsKoreanWeekday(kst)})';
}

IconData _scheduleTypeIcon(String type) {
  final normalized = type.trim();
  if (normalized == '반납') return Icons.arrow_downward;
  if (normalized == '기타') return Icons.priority_high_rounded;
  return Icons.arrow_upward;
}

Color _scheduleTypeColor(BuildContext context, String type) {
  final normalized = type.trim();
  if (normalized == '반납') return const Color(0xFFD32F2F);
  if (normalized == '배차') return const Color(0xFF1976D2);
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

String? _extractScheduleRawRowId(String recordId) {
  final trimmed = recordId.trim();
  const prefix = 'schedule:';
  if (trimmed.startsWith(prefix) && trimmed.length > prefix.length) {
    return trimmed.substring(prefix.length);
  }
  if (trimmed.isNotEmpty && !trimmed.contains(':')) return trimmed;
  return null;
}

String _resolveScheduleListImsReturnContractId(ExternalReservationLink link) {
  final candidates = [
    link.externalDetailId,
    link.reservationRefId,
    link.lastResultJson['contractId']?.toString() ?? '',
    link.lastResultJson['contract_id']?.toString() ?? '',
    link.lastResultJson['id']?.toString() ?? '',
  ];
  for (final candidate in candidates) {
    final trimmed = candidate.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _scheduleHeaderLabel(DateTime value) {
  final kst = opsAsKstWallTime(value);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${kst.year}.${two(kst.month)}.${two(kst.day)}(${opsKoreanWeekday(kst)})';
}

Color? _scheduleHeaderColor(BuildContext context, DateTime? value) {
  if (value == null) return null;
  return opsDateColor(value);
}

String _formatScheduleEditorDateTime(DateTime value) {
  return opsFormatKstDateTime(value);
}

DateTime? _tryParseScheduleDateTime(String value) {
  return opsParseKstDateTime(value);
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
