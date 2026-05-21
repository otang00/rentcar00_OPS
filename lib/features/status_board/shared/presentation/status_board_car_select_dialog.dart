import 'package:flutter/material.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';

String statusBoardCarDisplayLabel(StatusBoardRecord car) {
  final name = car.carName.trim();
  return name.isEmpty ? car.carNumber : '${car.carNumber} · $name';
}

class StatusBoardCarSelectResult {
  const StatusBoardCarSelectResult.selected(this.car) : cleared = false;
  const StatusBoardCarSelectResult.none() : car = null, cleared = true;

  final StatusBoardRecord? car;
  final bool cleared;
}

class StatusBoardCarSelectDialog extends StatefulWidget {
  const StatusBoardCarSelectDialog({
    super.key,
    required this.cars,
    this.initialCar,
    this.allowNone = false,
  });

  final List<StatusBoardRecord> cars;
  final StatusBoardRecord? initialCar;
  final bool allowNone;

  @override
  State<StatusBoardCarSelectDialog> createState() =>
      _StatusBoardCarSelectDialogState();
}

class _StatusBoardCarSelectDialogState
    extends State<StatusBoardCarSelectDialog> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<StatusBoardRecord> _filteredCars(String query) {
    final raw = query.trim().toLowerCase();
    final digits = raw.replaceAll(RegExp(r'\D+'), '');
    if (raw.isEmpty) return widget.cars;
    return widget.cars.where((car) {
      final number = car.carNumber.toLowerCase();
      final name = car.carName.toLowerCase();
      final numberDigits = car.carNumber.replaceAll(RegExp(r'\D+'), '');
      return number.contains(raw) ||
          name.contains(raw) ||
          (digits.isNotEmpty && numberDigits.endsWith(digits));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final filtered = _filteredCars(_queryController.text);

    return AlertDialog(
      title: const Text('차량 선택'),
      content: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '차량번호 / 뒤4자리 / 차종 검색',
                prefixIcon: Icon(Icons.search_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (widget.allowNone) ...[
              ListTile(
                dense: true,
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('선택안함'),
                subtitle: const Text('차량 없이 일정만 생성/수정'),
                onTap: () => Navigator.of(
                  context,
                ).pop(const StatusBoardCarSelectResult.none()),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final car = filtered[index];
                        final selected =
                            widget.initialCar?.recordId == car.recordId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            car.carNumber,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (car.carName.trim().isNotEmpty) car.carName,
                              if (car.status.trim().isNotEmpty) car.status,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(StatusBoardCarSelectResult.selected(car)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
