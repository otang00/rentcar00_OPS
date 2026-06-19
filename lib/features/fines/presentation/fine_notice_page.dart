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

class _FineNoticeTable extends StatelessWidget {
  const _FineNoticeTable({required this.items});

  final List<FineNoticeCase> items;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 980),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              columnSpacing: 18,
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('차량')),
                DataColumn(label: Text('고지서')),
                DataColumn(label: Text('통행일')),
                DataColumn(label: Text('장소')),
                DataColumn(label: Text('금액')),
                DataColumn(label: Text('계약서확정')),
                DataColumn(label: Text('문서작성')),
                DataColumn(label: Text('발송완료')),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    onSelectChanged: (_) => _showFineNoticeDetail(context, item),
                    cells: [
                      DataCell(_TableText(item.carNumber.isEmpty ? '확인 필요' : item.carNumber)),
                      DataCell(_TableText(_noticeTitle(item))),
                      DataCell(_TableText(item.occurredAt)),
                      DataCell(_TableText(item.location)),
                      DataCell(_TableText(item.totalAmount.isEmpty ? '' : '${item.totalAmount}원')),
                      DataCell(_CheckCell(checked: _hasConfirmedContract(item), label: _displayStatus(item.status))),
                      DataCell(_CheckCell(checked: _hasDocumentPackage(item), label: _documentStatusLabel(item))),
                      DataCell(_CheckCell(checked: item.status == 'submitted', label: item.status == 'submitted' ? '완료' : '대기')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableText extends StatelessWidget {
  const _TableText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Text(
        value.trim().isEmpty ? '-' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CheckCell extends StatelessWidget {
  const _CheckCell({required this.checked, required this.label});

  final bool checked;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = checked ? Colors.green.shade700 : Theme.of(context).disabledColor;
    return SizedBox(
      width: 96,
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
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
    'amount_missing' => '금액 확인 필요',
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
                if (item.totalAmount.isNotEmpty)
                  _InfoChip(label: '${item.totalAmount}원'),
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
	                    onPressed: (_working ||
	                            (!_documentReadyOverride && !_hasDocumentPackage(item)))
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계약서 확정 전에는 문서생성이 불가능합니다.')),
      );
      return;
    }
    setState(() => _working = true);
    final appEnv = ref.read(appEnvProvider);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('문서생성을 시작합니다.')),
    );
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
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
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

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _profileController = TextEditingController(text: item.noticeProfile);
    _typeController = TextEditingController(text: item.noticeType);
    _issuerController = TextEditingController(text: item.issuer);
    _documentNumberController = TextEditingController(text: item.documentNumber);
    _carNumberController = TextEditingController(text: item.carNumber);
    _occurredAtController = TextEditingController(text: item.occurredAt);
    _locationController = TextEditingController(text: item.location);
    _amountController = TextEditingController(text: item.totalAmount);
    _memoController = TextEditingController(text: item.memo);
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
                  controller: _amountController,
                  label: '금액',
                  keyboardType: TextInputType.number,
                ),
                _DialogTextField(
                  controller: _memoController,
                  label: '메모',
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
                  controller: _amountController,
                  label: '금액',
                  keyboardType: TextInputType.number,
                ),
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final int maxLines;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
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
