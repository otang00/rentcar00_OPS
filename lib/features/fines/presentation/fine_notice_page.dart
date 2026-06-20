import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rentcar00_ops/features/fines/data/fine_notice_ai_parser_client.dart';
import 'package:rentcar00_ops/features/fines/data/fine_notice_contract_matching_client.dart';
import 'package:rentcar00_ops/features/fines/data/fine_notice_contract_pdf_client.dart';
import 'package:rentcar00_ops/features/fines/data/fine_notice_document_client.dart';
import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';
import 'package:rentcar00_ops/features/fines/shared/fine_notice_providers.dart';
import 'package:rentcar00_ops/shared/config/supabase_providers.dart';

class FineNoticePage extends ConsumerWidget {
  const FineNoticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(fineNoticeCasesProvider);

    return casesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('과태료 원장을 불러오지 못했습니다.\n$error'),
            ),
          ),
        ],
      ),
      data: (cases) {
        if (cases.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('등록된 과태료 원장이 없습니다. 상단 + 버튼으로 수동 입력을 시작하세요.'),
                ),
              ),
            ],
          );
        }

        return _FineNoticeTable(items: cases);
      },
    );
  }
}

class _FineNoticeTable extends ConsumerStatefulWidget {
  const _FineNoticeTable({required this.items});

  final List<FineNoticeCase> items;

  @override
  ConsumerState<_FineNoticeTable> createState() => _FineNoticeTableState();
}

class _FineNoticeTableState extends ConsumerState<_FineNoticeTable> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _merging = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
      children: [
        _BundleSelectionToolbar(
          selectionMode: _selectionMode,
          selectedCount: _selectedIds.length,
          working: _merging,
          onStart: () => setState(() => _selectionMode = true),
          onCancel: _clearSelection,
          onMerge: () => _mergeSelected(context),
        ),
        const SizedBox(height: 6),
        for (final item in widget.items) ...[
          _FineNoticeCompactRow(
            item: item,
            selectionMode: _selectionMode,
            selected: _selectedIds.contains(item.id),
            onSelectionChanged: (selected) => _setSelected(item.id, selected),
            onTap: _selectionMode
                ? () => _setSelected(item.id, !_selectedIds.contains(item.id))
                : () => _showFineNoticeDetail(context, item),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  void _setSelected(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _mergeSelected(BuildContext context) async {
    if (_selectedIds.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('묶기는 2건 이상 선택해야 합니다.')));
      return;
    }

    setState(() => _merging = true);
    final appEnv = ref.read(appEnvProvider);
    final client = FineNoticeDocumentClient(baseUrl: appEnv.aiParserBaseUrl);
    try {
      var dryRun = await client.mergeBundle(
        fineNoticeIds: _selectedIds.toList(),
      );
      if (!context.mounted) return;
      final forceRebundle = await _showBundleMergeReviewDialog(
        context,
        result: dryRun,
      );
      if (forceRebundle == null) return;
      if (forceRebundle) {
        dryRun = await client.mergeBundle(
          fineNoticeIds: _selectedIds.toList(),
          forceRebundle: true,
        );
        if (!context.mounted) return;
        final confirmed = await _showBundleMergeReviewDialog(
          context,
          result: dryRun,
          forcePreview: true,
        );
        if (confirmed != true) return;
      } else if (!dryRun.eligible) {
        return;
      }

      await client.mergeBundle(
        fineNoticeIds: _selectedIds.toList(),
        dryRun: false,
        forceRebundle: forceRebundle,
      );
      ref.invalidate(fineNoticeCasesProvider);
      if (!context.mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${dryRun.rows.length}건을 묶었습니다.')));
    } on FineNoticeDocumentException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('묶기 실패\n$error')));
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }
}

class _BundleSelectionToolbar extends StatelessWidget {
  const _BundleSelectionToolbar({
    required this.selectionMode,
    required this.selectedCount,
    required this.working,
    required this.onStart,
    required this.onCancel,
    required this.onMerge,
  });

  final bool selectionMode;
  final int selectedCount;
  final bool working;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    if (!selectionMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: working ? null : onStart,
          icon: const Icon(Icons.link),
          label: const Text('묶기'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text('선택 $selectedCount건')),
          TextButton(
            onPressed: working ? null : onCancel,
            child: const Text('취소'),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: working || selectedCount < 2 ? null : onMerge,
            icon: working
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: const Text('선택 묶기'),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _showBundleMergeReviewDialog(
  BuildContext context, {
  required FineNoticeBundleMergeResult result,
  bool forcePreview = false,
}) {
  final canForce =
      !result.eligible &&
      result.blockedReasons.any((reason) => reason.contains('이미 서로 다른 묶음'));
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(result.eligible ? '묶기 확인' : '묶기 불가'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MergeSummaryLine(label: '묶음ID', value: result.bundleId),
              _MergeSummaryLine(label: '고지서 날짜', value: result.noticeDate),
              _MergeSummaryLine(label: '선택건수', value: '${result.rows.length}건'),
              if (result.rows.isNotEmpty) ...[
                _MergeSummaryLine(
                  label: '차량번호',
                  value: result.rows.first.carNumber,
                ),
                _MergeSummaryLine(
                  label: '발송처',
                  value: result.rows.first.issuer,
                ),
                _MergeSummaryLine(
                  label: '계약',
                  value: [
                    result.rows.first.contractSourceType,
                    result.rows.first.contractSourceId,
                  ].where((value) => value.trim().isNotEmpty).join(' / '),
                ),
                _MergeSummaryLine(
                  label: '위반일시',
                  value: _bundleOccurredAtRange(result.rows),
                ),
              ],
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  result.warnings.join('\n'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              if (result.blockedReasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  result.blockedReasons.join('\n'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 10),
              for (final row in result.rows)
                Text(
                  '${row.carNumber} · ${row.issuer} · ${_shortNoticeDate(row.occurredAt)} · ${row.location}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('취소'),
        ),
        if (canForce && !forcePreview)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('재묶음 확인'),
          )
        else if (result.eligible)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(forcePreview),
            child: const Text('묶기'),
          ),
      ],
    ),
  );
}

class _MergeSummaryLine extends StatelessWidget {
  const _MergeSummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

String _bundleOccurredAtRange(List<FineNoticeBundleMergeRow> rows) {
  final values =
      rows
          .map((row) => row.occurredAt.trim())
          .where((value) => value.isNotEmpty)
          .toList()
        ..sort();
  if (values.isEmpty) return '-';
  if (values.length == 1) return values.first;
  return '${values.first} ~ ${values.last}';
}

class _FineNoticeCompactRow extends StatelessWidget {
  const _FineNoticeCompactRow({
    required this.item,
    required this.onTap,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionChanged,
  });

  final FineNoticeCase item;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectionMode) ...[
                    Checkbox(
                      value: selected,
                      onChanged: (value) => onSelectionChanged(value == true),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 2),
                  ],
                  SizedBox(
                    width: selectionMode ? 74 : 88,
                    child: Text(
                      item.carNumber.isEmpty ? '확인 필요' : item.carNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.issuer.isEmpty
                                ? _noticeTitle(item)
                                : item.issuer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.documentListGroupKey.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.link,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 104,
                    child: Text(
                      _shortNoticeDate(item.occurredAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _FineNoticeStatusStrip(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _FineNoticeStatusStrip extends StatelessWidget {
  const _FineNoticeStatusStrip({required this.item});

  final FineNoticeCase item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TinyCheck(
                label: '계약서확정',
                checked: _hasConfirmedContract(item),
              ),
            ),
            Expanded(
              child: _TinyCheck(
                label: '문서작성',
                checked: _hasDocumentPackage(item),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: _TinyCheck(
                label: '발송완료',
                checked: item.status == 'submitted',
              ),
            ),
            Expanded(
              child: Text(
                _documentStatusLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TinyCheck extends StatelessWidget {
  const _TinyCheck({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final color = checked
        ? Colors.green.shade700
        : Theme.of(context).disabledColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          checked ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

String _shortNoticeDate(String value) {
  final match = RegExp(
    r'(\d{4})[-./년\s]*(\d{1,2})[-./월\s]*(\d{1,2})',
  ).firstMatch(value);
  if (match == null) return value.trim().isEmpty ? '-' : value.trim();
  return [
    match.group(1),
    match.group(2)!.padLeft(2, '0'),
    match.group(3)!.padLeft(2, '0'),
  ].join('-');
}

Future<void> _showFineNoticeDetail(
  BuildContext context,
  FineNoticeCase item,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _FineNoticeCard(item: item),
        ),
      ),
    ),
  );
}

Future<void> showFineNoticeCreateFlow({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final appEnv = ref.read(appEnvProvider);
  final result = await showDialog<_FineNoticeCreateResult>(
    context: context,
    builder: (context) =>
        _FineNoticeCreateDialog(aiParserBaseUrl: appEnv.aiParserBaseUrl),
  );
  if (result == null) return;
  try {
    final repository = ref.read(fineNoticeRepositoryProvider);
    var savedCount = 0;
    var notOurVehicleCount = 0;
    for (final item in result.drafts) {
      final isManagedVehicle = await repository.isManagedVehicleNumber(
        item.carNumber,
      );
      final draft = isManagedVehicle
          ? item
          : item.copyWith(
              status: 'not_our_vehicle',
              warnings: {...item.warnings, 'not_our_vehicle'}.toList(),
            );
      await repository.createCase(draft);
      savedCount += 1;
      if (!isManagedVehicle) notOurVehicleCount += 1;
    }
    ref.invalidate(fineNoticeCasesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_createResultMessage(savedCount, notOurVehicleCount)),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('과태료 원장 저장 실패\n$error')));
  }
}

String _createResultMessage(int savedCount, int notOurVehicleCount) {
  if (notOurVehicleCount == 0) {
    return savedCount <= 1 ? '과태료 원장을 저장했습니다.' : '과태료 원장 $savedCount건을 저장했습니다.';
  }
  if (savedCount <= 1) {
    return '우리 소유/관리 차량이 아닙니다. 지사/외부 차량 처리 대상입니다.';
  }
  return '과태료 원장 $savedCount건 저장, $notOurVehicleCount건은 우리 소유/관리 차량이 아닙니다.';
}

String _noticeTitle(FineNoticeCase item) {
  return [
    if (item.noticeProfile.trim().isNotEmpty) item.noticeProfile,
    if (item.documentNumber.trim().isNotEmpty) item.documentNumber,
    if (item.issuer.trim().isNotEmpty) item.issuer,
  ].join(' / ');
}

bool _hasConfirmedContract(FineNoticeCase item) {
  final source = item.confirmedContractSourceType?.trim() ?? '';
  return source.isNotEmpty &&
      ((item.imsContractId?.trim().isNotEmpty ?? false) ||
          (item.imsClaimId?.trim().isNotEmpty ?? false));
}

bool _hasContractOriginal(FineNoticeCase item) {
  return item.contractPdfSavedAt != null ||
      item.files.any((file) => file.fileRole == 'contract_original');
}

bool _hasDocumentPackage(FineNoticeCase item) {
  return item.documentPackageGeneratedAt != null ||
      item.status == 'document_ready' ||
      item.files.any(
        (file) =>
            file.fileRole == 'renter_change_application' ||
            file.fileRole == 'contract_with_stamps',
      );
}

String _documentStatusLabel(FineNoticeCase item) {
  if (_hasDocumentPackage(item)) return '완료';
  if (_hasConfirmedContract(item)) return '가능';
  return '불가';
}

String _displayStatus(String status) {
  return switch (status) {
    'draft' => '작성중',
    'review_needed' => '확인 필요',
    'ready_for_contract_search' => '계약서 검색 필요',
    'contract_candidates_ready' => '계약 후보 있음',
    'contract_confirmed' => '계약 확정',
    'document_ready' => '문서 생성 완료',
    'submission_ready' => '제출 준비 완료',
    'submitted' => '제출 완료',
    'on_hold' => '보류',
    'not_our_vehicle' => '외부/지사 차량',
    _ => status,
  };
}

String _displayWarning(String warning) {
  return switch (warning) {
    'parse_failed' => '파싱 실패',
    'not_our_vehicle' => '우리 소유/관리 차량 아님',
    'noticeProfile_missing' => '고지서 프로필 확인 필요',
    'noticeType_missing' => '고지서 유형 확인 필요',
    'carNumber_missing' => '차량번호 확인 필요',
    'occurredAt_missing' => '위반/통행일시 확인 필요',
    'amount_missing' => '추가 확인 필요',
    'contract_research_required' => '수정 후 계약서 재검색 필요',
    _ => warning,
  };
}

class _FineNoticeCreateResult {
  const _FineNoticeCreateResult({required this.drafts});

  final List<FineNoticeCase> drafts;
}

class _FineNoticeCard extends ConsumerStatefulWidget {
  const _FineNoticeCard({required this.item});

  final FineNoticeCase item;

  @override
  ConsumerState<_FineNoticeCard> createState() => _FineNoticeCardState();
}

class _FineNoticeCardState extends ConsumerState<_FineNoticeCard> {
  bool _documentReadyOverride = false;
  bool _working = false;

  FineNoticeCase get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.carNumber.isEmpty ? '차량번호 확인 필요' : item.carNumber,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(label: _displayStatus(item.status)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(label: item.noticeProfile),
                if (item.issuer.isNotEmpty) _InfoChip(label: item.issuer),
              ],
            ),
            if (item.occurredAt.isNotEmpty || item.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  item.occurredAt,
                  item.location,
                ].where((value) => value.trim().isNotEmpty).join(' · '),
              ),
            ],
            if (item.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '확인 필요: ${item.warnings.map(_displayWarning).join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (item.confirmedContractSourceType != null) ...[
              const SizedBox(height: 8),
              Text(
                _contractSummary(item),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _working
                        ? null
                        : () => _showFineNoticeEditDialog(context, ref, item),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('고지서수정'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _working ||
                            item.carNumber.trim().isEmpty ||
                            item.occurredAt.trim().isEmpty ||
                            item.status == 'not_our_vehicle'
                        ? null
                        : () => _searchAndConfirmContract(context, ref, item),
                    icon: const Icon(Icons.manage_search),
                    label: const Text('계약서 재검색'),
                  ),
                  if (item.confirmedContractSourceType != null)
                    FilledButton.icon(
                      onPressed: _working
                          ? null
                          : () => _generateDocuments(context, ref, item),
                      icon: const Icon(Icons.description),
                      label: const Text('문서생성'),
                    ),
                  OutlinedButton.icon(
                    onPressed:
                        (_working ||
                            (!_documentReadyOverride &&
                                !_hasDocumentPackage(item)))
                        ? null
                        : () => _shareDocuments(context, ref, item),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('공유'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _contractSummary(FineNoticeCase item) {
    final label = item.confirmedContractSourceType == 'ims_insurance_claim'
        ? '보험계약'
        : '일반계약';
    final name = item.renterSnapshotJson['customerName']?.toString() ?? '';
    final id = item.imsContractId ?? item.imsClaimId ?? '';
    return [
      '확정',
      label,
      if (name.trim().isNotEmpty) name,
      if (id.trim().isNotEmpty) id,
    ].join(' · ');
  }

  Future<void> _generateDocuments(
    BuildContext context,
    WidgetRef ref,
    FineNoticeCase item,
  ) async {
    if (!_hasConfirmedContract(item)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('계약서 확정 전에는 문서생성이 불가능합니다.')));
      return;
    }
    setState(() => _working = true);
    final appEnv = ref.read(appEnvProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('문서생성을 시작합니다.')));
    try {
      if (!_hasContractOriginal(item)) {
        await FineNoticeContractPdfClient(
          baseUrl: appEnv.aiParserBaseUrl,
        ).saveContractPdf(fineNoticeId: item.id);
      }
      await FineNoticeDocumentClient(
        baseUrl: appEnv.aiParserBaseUrl,
      ).generateDocuments(fineNoticeId: item.id);
      ref.invalidate(fineNoticeCasesProvider);
      if (!mounted) return;
      setState(() => _documentReadyOverride = true);
      messenger.showSnackBar(
        const SnackBar(content: Text('문서생성 완료. 공유 버튼을 사용할 수 있습니다.')),
      );
    } on FineNoticeContractPdfException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on FineNoticeDocumentException catch (error) {
      if (!mounted) return;
      final missingFields = error.missingFields;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            missingFields.isEmpty
                ? error.message
                : '${error.message}\n누락: ${missingFields.join(', ')}',
          ),
        ),
      );
      if (missingFields.isNotEmpty && context.mounted) {
        await _showFineNoticeEditDialog(context, ref, item);
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('문서생성 실패\n$error')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _shareDocuments(
    BuildContext context,
    WidgetRef ref,
    FineNoticeCase item,
  ) async {
    setState(() => _working = true);
    final appEnv = ref.read(appEnvProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = FineNoticeDocumentClient(baseUrl: appEnv.aiParserBaseUrl);
      final files = await client.listPackageFiles(fineNoticeId: item.id);
      await client.sharePackageFiles(files);
    } on FineNoticeDocumentException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('공유 실패\n$error')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

Future<void> _searchAndConfirmContract(
  BuildContext context,
  WidgetRef ref,
  FineNoticeCase item,
) async {
  final repository = ref.read(fineNoticeRepositoryProvider);
  final isManagedVehicle = await repository.isManagedVehicleNumber(
    item.carNumber,
  );
  if (!context.mounted) return;
  if (!isManagedVehicle) {
    await repository.markNotOurVehicle(item);
    ref.invalidate(fineNoticeCasesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('우리 소유/관리 차량이 아닙니다. 지사/외부 차량 처리 대상입니다.')),
    );
    return;
  }

  final occurredDate = _parseNoticeDate(item.occurredAt);
  if (occurredDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('계약검색 날짜를 해석하지 못했습니다. 위반/통행일시를 확인하세요.')),
    );
    return;
  }

  final appEnv = ref.read(appEnvProvider);
  final candidate = await showDialog<FineNoticeContractCandidate>(
    context: context,
    builder: (context) => _FineNoticeContractSearchDialog(
      baseUrl: appEnv.aiParserBaseUrl,
      carNumber: item.carNumber,
      occurredDate: occurredDate,
    ),
  );
  if (candidate == null) return;

  try {
    await ref
        .read(fineNoticeRepositoryProvider)
        .confirmContract(fineNotice: item, candidate: candidate);
    ref.invalidate(fineNoticeCasesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('계약자를 확정했습니다. (${candidate.customerName})')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('계약자 확정 저장 실패\n$error')));
  }
}

Future<void> _showFineNoticeEditDialog(
  BuildContext context,
  WidgetRef ref,
  FineNoticeCase item,
) async {
  final edited = await showDialog<FineNoticeCase>(
    context: context,
    builder: (context) => _FineNoticeEditDialog(item: item),
  );
  if (edited == null) return;
  final contractSensitiveChanged =
      edited.carNumber != item.carNumber ||
      edited.occurredAt != item.occurredAt ||
      edited.documentNumber != item.documentNumber ||
      edited.noticeProfile != item.noticeProfile;
  final itemToSave = contractSensitiveChanged && _hasConfirmedContract(item)
      ? edited.copyWith(
          status: 'ready_for_contract_search',
          warnings: {...edited.warnings, 'contract_research_required'}.toList(),
          clearConfirmedContract: true,
          clearDocumentState: true,
        )
      : edited;
  try {
    await ref.read(fineNoticeRepositoryProvider).updateCase(itemToSave);
    ref.invalidate(fineNoticeCasesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          contractSensitiveChanged && _hasConfirmedContract(item)
              ? '고지서를 수정했습니다. 계약서 재검색이 필요합니다.'
              : '고지서를 수정했습니다.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('고지서 수정 실패\n$error')));
  }
}

DateTime? _parseNoticeDate(String value) {
  final normalized = value
      .trim()
      .replaceAll('년', '-')
      .replaceAll('월', '-')
      .replaceAll('일', ' ')
      .replaceAll('.', '-')
      .replaceAll('/', '-');
  final match = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(normalized);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

class _FineNoticeEditDialog extends StatefulWidget {
  const _FineNoticeEditDialog({required this.item});

  final FineNoticeCase item;

  @override
  State<_FineNoticeEditDialog> createState() => _FineNoticeEditDialogState();
}

class _FineNoticeEditDialogState extends State<_FineNoticeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _profileController;
  late final TextEditingController _typeController;
  late final TextEditingController _issuerController;
  late final TextEditingController _documentNumberController;
  late final TextEditingController _carNumberController;
  late final TextEditingController _occurredAtController;
  late final TextEditingController _locationController;
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  late final TextEditingController _renterNameController;
  late final TextEditingController _renterPhoneController;
  late final TextEditingController _renterAddressController;
  late final TextEditingController _renterIdentityNoController;
  late final TextEditingController _renterDriverLicenseNoController;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _profileController = TextEditingController(text: item.noticeProfile);
    _typeController = TextEditingController(text: item.noticeType);
    _issuerController = TextEditingController(text: item.issuer);
    _documentNumberController = TextEditingController(
      text: item.documentNumber,
    );
    _carNumberController = TextEditingController(text: item.carNumber);
    _occurredAtController = TextEditingController(text: item.occurredAt);
    _locationController = TextEditingController(text: item.location);
    _amountController = TextEditingController(text: item.totalAmount);
    _memoController = TextEditingController(text: item.memo);
    _renterNameController = TextEditingController(text: item.renterName);
    _renterPhoneController = TextEditingController(text: item.renterPhone);
    _renterAddressController = TextEditingController(text: item.renterAddress);
    _renterIdentityNoController = TextEditingController(
      text: item.renterIdentityNo,
    );
    _renterDriverLicenseNoController = TextEditingController(
      text: item.renterDriverLicenseNo,
    );
  }

  @override
  void dispose() {
    _profileController.dispose();
    _typeController.dispose();
    _issuerController.dispose();
    _documentNumberController.dispose();
    _carNumberController.dispose();
    _occurredAtController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _renterNameController.dispose();
    _renterPhoneController.dispose();
    _renterAddressController.dispose();
    _renterIdentityNoController.dispose();
    _renterDriverLicenseNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('고지서수정'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogTextField(
                  controller: _profileController,
                  label: '고지서 프로필',
                ),
                _DialogTextField(controller: _typeController, label: '고지서 유형'),
                _DialogTextField(controller: _issuerController, label: '발행기관'),
                _DialogTextField(
                  controller: _documentNumberController,
                  label: '고지서번호',
                ),
                _DialogTextField(
                  controller: _carNumberController,
                  label: '차량번호',
                  required: true,
                ),
                _DialogTextField(
                  controller: _occurredAtController,
                  label: '위반/통행일시',
                  required: true,
                ),
                _DialogTextField(controller: _locationController, label: '장소'),
                _DialogTextField(
                  controller: _memoController,
                  label: '메모',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '임차인 정보',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                _DialogTextField(
                  controller: _renterNameController,
                  label: '임차인명',
                ),
                _DialogTextField(
                  controller: _renterPhoneController,
                  label: '임차인 전화번호',
                ),
                _DialogTextField(
                  controller: _renterAddressController,
                  label: '임차인 주소',
                ),
                _DialogTextField(
                  controller: _renterIdentityNoController,
                  label: '주민등록번호',
                ),
                _DialogTextField(
                  controller: _renterDriverLicenseNoController,
                  label: '운전면허번호',
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
            final profile = _profileController.text.trim();
            Navigator.of(context).pop(
              widget.item.copyWith(
                status: widget.item.status == 'review_needed'
                    ? 'review_needed'
                    : widget.item.status,
                noticeProfile: profile.isEmpty ? 'unknown_notice' : profile,
                noticeType: _typeController.text.trim(),
                issuer: _issuerController.text.trim(),
                documentNumber: _documentNumberController.text.trim(),
                carNumber: _carNumberController.text.trim(),
                occurredAt: _occurredAtController.text.trim(),
                location: _locationController.text.trim(),
                totalAmount: _amountController.text.trim(),
                memo: _memoController.text.trim(),
                renterName: _renterNameController.text.trim(),
                renterPhone: _renterPhoneController.text.trim(),
                renterAddress: _renterAddressController.text.trim(),
                renterIdentityNo: _renterIdentityNoController.text.trim(),
                renterDriverLicenseNo: _renterDriverLicenseNoController.text
                    .trim(),
              ),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _FineNoticeCreateDialog extends StatefulWidget {
  const _FineNoticeCreateDialog({required this.aiParserBaseUrl});

  final String aiParserBaseUrl;

  @override
  State<_FineNoticeCreateDialog> createState() =>
      _FineNoticeCreateDialogState();
}

class _FineNoticeCreateDialogState extends State<_FineNoticeCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _profileController;
  late final TextEditingController _typeController;
  late final TextEditingController _issuerController;
  late final TextEditingController _documentNumberController;
  late final TextEditingController _carNumberController;
  late final TextEditingController _occurredAtController;
  late final TextEditingController _locationController;
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  final List<String> _warnings = [];
  Map<String, dynamic> _rawCandidateJson = const {};
  FineNoticeFileMetadata? _noticeOriginalFile;
  bool _aiParsing = false;
  bool _checkingConnection = false;
  bool? _isConnected;

  @override
  void initState() {
    super.initState();
    _profileController = TextEditingController();
    _typeController = TextEditingController();
    _issuerController = TextEditingController();
    _documentNumberController = TextEditingController();
    _carNumberController = TextEditingController();
    _occurredAtController = TextEditingController();
    _locationController = TextEditingController();
    _amountController = TextEditingController();
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _profileController.dispose();
    _typeController.dispose();
    _issuerController.dispose();
    _documentNumberController.dispose();
    _carNumberController.dispose();
    _occurredAtController.dispose();
    _locationController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (_checkingConnection) return;
    setState(() => _checkingConnection = true);
    try {
      final client = FineNoticeAiParserClient(baseUrl: widget.aiParserBaseUrl);
      final ok = await client.checkHealth();
      if (!mounted) return;
      setState(() => _isConnected = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isConnected = false);
    } finally {
      if (mounted) setState(() => _checkingConnection = false);
    }
  }

  Future<void> _runAiParser() async {
    if (_aiParsing) return;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('고지서 사진 선택'),
        content: const Text('사진을 촬영하거나 갤러리에서 고지서를 선택합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('갤러리'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('촬영'),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _aiParsing = true);
    try {
      final client = FineNoticeAiParserClient(baseUrl: widget.aiParserBaseUrl);
      final result = await client.parseImage(
        bytes: await picked.readAsBytes(),
        mimeType: picked.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      final intake = FineNoticeParserIntakeResult.fromParserJson(
        result.rawJson,
        file: result.file,
      );
      if (intake.isAutoAdd) {
        Navigator.of(
          context,
        ).pop(_FineNoticeCreateResult(drafts: intake.drafts));
        return;
      }

      _applyAiResult(result, prefillDraft: intake.prefillDraft);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            intake.reasons.isEmpty
                ? '파싱 실패: 확인 후 수동 입력으로 저장하세요.'
                : '파싱 실패: ${intake.reasons.join(', ')}',
          ),
        ),
      );
    } on FineNoticeAiParserException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('AI파서 호출 실패\n$error')));
    } finally {
      if (mounted) setState(() => _aiParsing = false);
    }
  }

  void _applyAiResult(
    FineNoticeAiParseResult result, {
    FineNoticeCase? prefillDraft,
  }) {
    final candidate = result.candidate;
    void fill(TextEditingController controller, Object? value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      controller.text = text;
    }

    fill(_profileController, candidate.noticeProfile);
    fill(_typeController, candidate.noticeType);
    fill(_issuerController, candidate.issuer);
    fill(_documentNumberController, candidate.documentNumber);
    fill(_carNumberController, candidate.carNumber);
    fill(_occurredAtController, candidate.violationAt ?? candidate.passAt);
    fill(_locationController, candidate.location);
    fill(_amountController, candidate.totalAmount);
    if (prefillDraft != null) {
      fill(_profileController, prefillDraft.noticeProfile);
      fill(_typeController, prefillDraft.noticeType);
      fill(_issuerController, prefillDraft.issuer);
      fill(_documentNumberController, prefillDraft.documentNumber);
      fill(_carNumberController, prefillDraft.carNumber);
      fill(_occurredAtController, prefillDraft.occurredAt);
      fill(_locationController, prefillDraft.location);
      fill(_amountController, prefillDraft.totalAmount);
    }
    setState(() {
      _rawCandidateJson = prefillDraft?.rawCandidateJson ?? result.rawJson;
      _noticeOriginalFile = (prefillDraft?.files.isNotEmpty ?? false)
          ? prefillDraft!.files.first
          : result.file;
      _warnings
        ..clear()
        ..addAll(prefillDraft?.warnings ?? result.warnings);
    });
  }

  FineNoticeCase? _buildResult() {
    if (!_formKey.currentState!.validate()) return null;
    final now = DateTime.now();
    final profile = _profileController.text.trim();
    return FineNoticeCase(
      id: 'fine-${now.microsecondsSinceEpoch}',
      createdAt: now,
      status: _warnings.isEmpty ? 'ready_for_contract_search' : 'review_needed',
      noticeProfile: profile.isEmpty ? 'unknown_notice' : profile,
      noticeType: _typeController.text.trim(),
      issuer: _issuerController.text.trim(),
      documentNumber: _documentNumberController.text.trim(),
      carNumber: _carNumberController.text.trim(),
      occurredAt: _occurredAtController.text.trim(),
      location: _locationController.text.trim(),
      totalAmount: _amountController.text.trim(),
      dueDate: '',
      memo: _memoController.text.trim(),
      warnings: List.unmodifiable(_warnings),
      rawCandidateJson: Map.unmodifiable(_rawCandidateJson),
      files: [?_noticeOriginalFile],
    );
  }

  Widget _buildConnectionIcon() {
    if (_checkingConnection) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_isConnected == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (_isConnected == false) {
      return const Icon(Icons.error, color: Colors.redAccent);
    }
    return const Icon(Icons.help_outline);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('과태료 등록')),
              IconButton(
                tooltip: _isConnected == true
                    ? 'AI파서 연결됨'
                    : _isConnected == false
                    ? 'AI파서 연결 실패 - 다시 확인'
                    : 'AI파서 연결 확인',
                onPressed: _checkingConnection ? null : _checkConnection,
                icon: _buildConnectionIcon(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _FineNoticeDialogActionButton(
              label: 'AI파서',
              icon: Icons.auto_awesome_outlined,
              loading: _aiParsing,
              onPressed: _aiParsing ? null : _runAiParser,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_warnings.isNotEmpty) ...[
                  _WarningPanel(warnings: _warnings),
                  const SizedBox(height: 10),
                ],
                if (_noticeOriginalFile != null) ...[
                  _NoticeOriginalFilePanel(file: _noticeOriginalFile!),
                  const SizedBox(height: 10),
                ],
                _DialogTextField(
                  controller: _profileController,
                  label: '고지서 프로필',
                  hintText: '예: toll_fee.woomyeonsan',
                ),
                _DialogTextField(
                  controller: _typeController,
                  label: '고지서 유형',
                  hintText: 'toll_fee / parking_violation / traffic_fine',
                ),
                _DialogTextField(controller: _issuerController, label: '발행기관'),
                _DialogTextField(
                  controller: _documentNumberController,
                  label: '고지서번호',
                ),
                _DialogTextField(
                  controller: _carNumberController,
                  label: '차량번호',
                  required: true,
                ),
                _DialogTextField(
                  controller: _occurredAtController,
                  label: '위반/통행일시',
                  hintText: '예: 2026-05-06 20:22',
                  required: true,
                ),
                _DialogTextField(controller: _locationController, label: '장소'),
                _DialogTextField(
                  controller: _memoController,
                  label: '메모',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                const _SubmissionPolicyPlaceholder(),
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
        OutlinedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('계약검색은 다음 Phase에서 연결됩니다.')),
            );
          },
          child: const Text('계약검색'),
        ),
        FilledButton(
          onPressed: () {
            final result = _buildResult();
            if (result == null) return;
            Navigator.of(
              context,
            ).pop(_FineNoticeCreateResult(drafts: [result]));
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _FineNoticeContractSearchDialog extends StatefulWidget {
  const _FineNoticeContractSearchDialog({
    required this.baseUrl,
    required this.carNumber,
    required this.occurredDate,
  });

  final String baseUrl;
  final String carNumber;
  final DateTime occurredDate;

  @override
  State<_FineNoticeContractSearchDialog> createState() =>
      _FineNoticeContractSearchDialogState();
}

class _FineNoticeContractSearchDialogState
    extends State<_FineNoticeContractSearchDialog> {
  late final Future<List<FineNoticeContractCandidate>> _future;

  @override
  void initState() {
    super.initState();
    _future = FineNoticeContractMatchingClient(baseUrl: widget.baseUrl)
        .searchCandidates(
          carNumber: widget.carNumber,
          occurredDate: widget.occurredDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('IMS 계약검색'),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<List<FineNoticeContractCandidate>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('IMS 계약검색 실패\n${snapshot.error}');
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const Text('후보 계약이 없습니다. 차량번호와 일자를 확인하세요.');
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        [
                          item.sourceLabel,
                          item.customerName,
                          item.carNumber,
                        ].where((value) => value.trim().isNotEmpty).join(' · '),
                      ),
                      subtitle: Text(
                        [
                          if (item.rentalAt.trim().isNotEmpty)
                            '대여 ${item.rentalAt}',
                          if (item.returnAt.trim().isNotEmpty)
                            '반납 ${item.returnAt}',
                          if (item.customerPhone.trim().isNotEmpty)
                            item.customerPhone,
                          item.matchReason,
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () => Navigator.of(context).pop(item),
                        child: const Text('확정'),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.maxLines = 1,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final int maxLines;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label 입력 필요';
                }
                return null;
              }
            : null,
      ),
    );
  }
}

class _FineNoticeDialogActionButton extends StatelessWidget {
  const _FineNoticeDialogActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '확인 필요\n${warnings.join(', ')}',
        style: TextStyle(color: color),
      ),
    );
  }
}

class _NoticeOriginalFilePanel extends StatelessWidget {
  const _NoticeOriginalFilePanel({required this.file});

  final FineNoticeFileMetadata file;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '원본 저장됨\n${file.localPath}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _SubmissionPolicyPlaceholder extends StatelessWidget {
  const _SubmissionPolicyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('제출 정책', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('정책 미정: 제출 채널/필요서류/양식은 profile별 정책 잠금 후 표시됩니다.'),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
