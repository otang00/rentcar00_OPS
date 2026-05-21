import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentcar00_ops/features/auth/shared/auth_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';

final _adminVehicleRowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final client = ref.read(supabaseClientProvider);
      final rows = await client
          .from('rc00_ops_cars')
          .select()
          .order('car_number', ascending: true);
      return rows
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList();
    });

const _basicVehicleColumns = [
  _VehicleColumn('car_number', '차량번호', required: true),
  _VehicleColumn('car_name', '차종/차명'),
  _VehicleColumn('status', '상태'),
  _VehicleColumn('parking_location', '주차위치'),
  _VehicleColumn('car_registered_at', '등록일'),
  _VehicleColumn('car_inspection_at', '검사일'),
  _VehicleColumn('car_age_expiry_at', '연식만료일'),
  _VehicleColumn('note_text', '메모', maxLines: 3),
];

const _advancedVehicleColumns = [
  _VehicleColumn('status_action', '상태 action'),
  _VehicleColumn('car_wash', '세차'),
  _VehicleColumn('interior_wash', '실내세차'),
  _VehicleColumn('start_at', '대여일 raw'),
  _VehicleColumn('end_at', '반납일 raw'),
  _VehicleColumn('start_at_ts', '대여일 timestamp'),
  _VehicleColumn('end_at_ts', '반납일 timestamp'),
  _VehicleColumn('customer_name', '고객명'),
  _VehicleColumn('customer_phone', '고객 연락처'),
  _VehicleColumn('pickup_location', '배차지'),
  _VehicleColumn('car_number_front', '차량번호 앞'),
  _VehicleColumn('car_number_middle', '차량번호 중'),
  _VehicleColumn('car_number_rear', '차량번호 뒤'),
  _VehicleColumn('payload_json', 'payload_json', maxLines: 5, isJson: true),
  _VehicleColumn('last_synced_at', '마지막 동기화일'),
  _VehicleColumn('created_at', '생성일'),
  _VehicleColumn('updated_at', '수정일'),
];

class VehicleManagementPage extends ConsumerStatefulWidget {
  const VehicleManagementPage({super.key});

  @override
  ConsumerState<VehicleManagementPage> createState() =>
      _VehicleManagementPageState();
}

class _VehicleManagementPageState extends ConsumerState<VehicleManagementPage> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterRows(List<Map<String, dynamic>> rows) {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((row) {
      final haystack = [
        row['car_number'],
        row['car_name'],
        row['status'],
        row['parking_location'],
      ].map((value) => '$value'.toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openForm({Map<String, dynamic>? row}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _VehicleEditDialog(initialRow: row),
    );
    if (saved == true) {
      ref.invalidate(_adminVehicleRowsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(currentStaffAccountProvider);
    final rowsAsync = ref.watch(_adminVehicleRowsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('차량관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('차량 추가'),
      ),
      body: staffAsync.when(
        data: (staff) {
          if (staff?.isAdmin != true) return const _VehicleAdminBlockedView();
          return rowsAsync.when(
            data: (rows) {
              final filtered = _filterRows(rows);
              return RefreshIndicator(
                triggerMode: RefreshIndicatorTriggerMode.anywhere,
                onRefresh: () async =>
                    ref.invalidate(_adminVehicleRowsProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  children: [
                    TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        labelText: '차량번호 / 차종 / 상태 / 주차위치 검색',
                        prefixIcon: Icon(Icons.search_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '총 ${rows.length}대 · 표시 ${filtered.length}대',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: Text('차량이 없습니다.')),
                      )
                    else
                      for (final row in filtered)
                        _VehicleAdminCard(
                          row: row,
                          onTap: () => _openForm(row: row),
                        ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('차량 목록을 불러오지 못했습니다.\n$error'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('관리자 권한을 확인하지 못했습니다.\n$error'),
          ),
        ),
      ),
    );
  }
}

class _VehicleAdminCard extends StatelessWidget {
  const _VehicleAdminCard({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback onTap;

  String _text(String key) => (row[key]?.toString() ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _text('status');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          _text('car_number').isEmpty ? '(차량번호 없음)' : _text('car_number'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (_text('car_name').isNotEmpty) _text('car_name'),
              if (status.isNotEmpty) status,
              if (_text('parking_location').isNotEmpty)
                _text('parking_location'),
              if (_text('car_inspection_at').isNotEmpty)
                '검사 ${_text('car_inspection_at')}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _VehicleEditDialog extends ConsumerStatefulWidget {
  const _VehicleEditDialog({this.initialRow});

  final Map<String, dynamic>? initialRow;

  bool get isCreate => initialRow == null;

  @override
  ConsumerState<_VehicleEditDialog> createState() => _VehicleEditDialogState();
}

class _VehicleEditDialogState extends ConsumerState<_VehicleEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _showAdvanced = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final allColumns = [..._basicVehicleColumns, ..._advancedVehicleColumns];
    _controllers = {
      for (final column in allColumns)
        column.key: TextEditingController(text: _initialText(column.key)),
    };
    if (widget.isCreate) {
      _controllers['status']!.text = '대기중';
      _controllers['car_wash']!.text = 'FALSE';
      _controllers['interior_wash']!.text = 'FALSE';
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _initialText(String key) {
    final value = widget.initialRow?[key];
    if (value == null) return '';
    if (key == 'payload_json') {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    }
    return value.toString();
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};
    for (final column in [
      ..._basicVehicleColumns,
      ..._advancedVehicleColumns,
    ]) {
      final raw = _controllers[column.key]?.text.trim() ?? '';
      if (widget.isCreate && raw.isEmpty && !column.required) continue;
      if (column.isJson) {
        payload[column.key] = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw);
      } else if (raw.isEmpty) {
        payload[column.key] = null;
      } else {
        payload[column.key] = raw;
      }
    }
    return payload;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final payload = _buildPayload();
      if (widget.isCreate) {
        await client.from('rc00_ops_cars').insert(payload);
      } else {
        await client
            .from('rc00_ops_cars')
            .update(payload)
            .eq('id', widget.initialRow!['id'] as String);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패\n$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차량 삭제'),
        content: Text(
          '${_controllers['car_number']!.text.trim()} 차량을 삭제합니다.\n'
          '과거 예약/일정의 차량번호 연결이 끊길 수 있습니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rc00_ops_cars')
          .delete()
          .eq('id', widget.initialRow!['id'] as String);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패\n$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCreate ? '차량 추가' : '차량 수정';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isCreate)
                  _ReadonlyVehicleField(
                    label: 'id',
                    value: '${widget.initialRow!['id']}',
                  ),
                for (final column in _basicVehicleColumns)
                  _VehicleTextField(
                    column: column,
                    controller: _controllers[column.key]!,
                  ),
                const SizedBox(height: 6),
                ExpansionTile(
                  initiallyExpanded: _showAdvanced,
                  onExpansionChanged: (value) => _showAdvanced = value,
                  title: const Text(
                    '고급 컬럼 보기',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('운행/시스템 컬럼 전체 수정'),
                  children: [
                    const _AdvancedWarningBox(),
                    for (final column in _advancedVehicleColumns)
                      _VehicleTextField(
                        column: column,
                        controller: _controllers[column.key]!,
                      ),
                  ],
                ),
                if (!widget.isCreate) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('차량 삭제'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('저장'),
        ),
      ],
    );
  }
}

class _VehicleTextField extends StatelessWidget {
  const _VehicleTextField({required this.column, required this.controller});

  final _VehicleColumn column;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        maxLines: column.maxLines,
        decoration: InputDecoration(
          labelText: column.required ? '${column.label} *' : column.label,
          hintText: column.key,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (column.required && text.isEmpty) {
            return '${column.label}을 입력해 주세요.';
          }
          if (column.isJson && text.isNotEmpty) {
            try {
              jsonDecode(text);
            } catch (_) {
              return 'JSON 형식이 올바르지 않습니다.';
            }
          }
          return null;
        },
      ),
    );
  }
}

class _ReadonlyVehicleField extends StatelessWidget {
  const _ReadonlyVehicleField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: SelectableText(value),
      ),
    );
  }
}

class _AdvancedWarningBox extends StatelessWidget {
  const _AdvancedWarningBox();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '고급 컬럼은 상태보드/예약 표시와 직접 연결됩니다. 값 형식이 틀리면 화면 표시가 깨질 수 있습니다.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _VehicleAdminBlockedView extends StatelessWidget {
  const _VehicleAdminBlockedView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('관리자만 접근할 수 있습니다.'));
  }
}

class _VehicleColumn {
  const _VehicleColumn(
    this.key,
    this.label, {
    this.required = false,
    this.maxLines = 1,
    this.isJson = false,
  });

  final String key;
  final String label;
  final bool required;
  final int maxLines;
  final bool isJson;
}
