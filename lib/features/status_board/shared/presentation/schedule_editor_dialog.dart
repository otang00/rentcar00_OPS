import 'package:flutter/material.dart';

class ScheduleEditorDialog extends StatefulWidget {
  const ScheduleEditorDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialType = '배차',
    this.initialScheduleAt,
    this.initialCarNumber = '',
    this.initialCarName = '',
    this.initialLocationText = '',
    this.initialDetailText = '',
  });

  final String title;
  final String confirmLabel;
  final String initialType;
  final DateTime? initialScheduleAt;
  final String initialCarNumber;
  final String initialCarName;
  final String initialLocationText;
  final String initialDetailText;

  @override
  State<ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

class _ScheduleEditorDialogState extends State<ScheduleEditorDialog> {
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
    final initial =
        widget.initialScheduleAt ??
        DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _scheduleType = _scheduleTypes.contains(widget.initialType.trim())
        ? widget.initialType.trim()
        : _scheduleTypes.first;
    _scheduleAtController = TextEditingController(
      text: formatScheduleEditorDateTime(initial),
    );
    _carNumberController = TextEditingController(text: widget.initialCarNumber);
    _carNameController = TextEditingController(text: widget.initialCarName);
    _locationController = TextEditingController(
      text: widget.initialLocationText,
    );
    _detailController = TextEditingController(text: widget.initialDetailText);
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
        tryParseScheduleDateTime(_scheduleAtController.text.trim()) ?? now;
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
      _scheduleAtController.text = formatScheduleEditorDateTime(combined);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.event_available_outlined, color: colorScheme.primary),
      title: Text(widget.title),
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
                  validator: scheduleDateTimeValidator,
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
            final scheduleAt = tryParseScheduleDateTime(
              _scheduleAtController.text.trim(),
            );
            if (scheduleAt == null) return;
            Navigator.of(context).pop(
              ScheduleEditorResult(
                scheduleType: _scheduleType,
                scheduleAt: scheduleAt,
                carNumber: _carNumberController.text.trim(),
                carName: _carNameController.text.trim(),
                locationText: _locationController.text.trim(),
                detailText: _detailController.text.trim(),
              ),
            );
          },
          child: Text(widget.confirmLabel),
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

class ScheduleEditorResult {
  const ScheduleEditorResult({
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

String formatScheduleEditorDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

DateTime? tryParseScheduleDateTime(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  return DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
}

String? scheduleDateTimeValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '일정시각을 입력하세요.';
  }
  if (tryParseScheduleDateTime(value) == null) {
    return 'YYYY-MM-DD HH:mm 형식으로 입력하세요.';
  }
  return null;
}
