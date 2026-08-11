import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FineNoticeRepository {
  const FineNoticeRepository(this._client);

  final SupabaseClient _client;

  Future<List<FineNoticeCase>> fetchCases() async {
    final rows = await _client
        .from('rc00_ops_fine_notices')
        .select()
        .order('created_at', ascending: false);

    final noticeRows = rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (noticeRows.isEmpty) return const [];
    final ids = noticeRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();
    final fileRows = await _client
        .from('rc00_ops_fine_notice_files')
        .select()
        .inFilter('fine_notice_id', ids);
    final filesByNoticeId = <String, List<FineNoticeFileMetadata>>{};
    for (final row in fileRows) {
      final file = FineNoticeFileMetadata.fromRow(
        Map<String, dynamic>.from(row),
      );
      final fineNoticeId = file.fineNoticeId;
      if (fineNoticeId == null || fineNoticeId.isEmpty) continue;
      filesByNoticeId.putIfAbsent(fineNoticeId, () => []).add(file);
    }

    return [
      for (final row in noticeRows)
        FineNoticeCase.fromRow(
          row,
          files: filesByNoticeId[row['id']?.toString()] ?? const [],
        ),
    ];
  }

  Future<FineNoticeCase> createCase(FineNoticeCase draft) async {
    final row = await _client
        .from('rc00_ops_fine_notices')
        .insert(draft.toInsertRow())
        .select()
        .single();

    final item = FineNoticeCase.fromRow(Map<String, dynamic>.from(row));
    final files = draft.files
        .where((file) => file.localPath.trim().isNotEmpty)
        .map((file) => file.toInsertRow(item.id))
        .toList();
    if (files.isNotEmpty) {
      await _client.from('rc00_ops_fine_notice_files').insert(files);
    }
    return item;
  }

  Future<void> updateCase(FineNoticeCase item) async {
    await _client
        .from('rc00_ops_fine_notices')
        .update({
          ...item.toInsertRow(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', item.id);
  }

  Future<bool> isManagedVehicleNumber(String carNumber) async {
    final normalized = _normalizeCarNumber(carNumber);
    if (normalized.isEmpty) return false;
    final rows = await _client
        .from('rc00_ops_cars')
        .select('id')
        .eq('car_number', normalized)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> markNotOurVehicle(FineNoticeCase fineNotice) async {
    final warnings = {...fineNotice.warnings, 'not_our_vehicle'}.toList();
    await _client
        .from('rc00_ops_fine_notices')
        .update({
          'status': 'not_our_vehicle',
          'review_warnings': warnings,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', fineNotice.id);
  }

  Future<void> confirmContract({
    required FineNoticeCase fineNotice,
    required FineNoticeContractCandidate candidate,
  }) async {
    final renterSnapshot = candidate.toRenterSnapshotJson();
    await _client
        .from('rc00_ops_fine_notices')
        .update({
          'status': 'contract_confirmed',
          'confirmed_contract_source_type': candidate.sourceType,
          'ims_contract_id': candidate.sourceType == 'ims_normal_contract'
              ? candidate.sourceId
              : null,
          'ims_claim_id': candidate.sourceType == 'ims_insurance_claim'
              ? candidate.sourceId
              : null,
          'renter_snapshot_json': renterSnapshot,
          'contract_confirmed_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', fineNotice.id);

    await _client.from('rc00_ops_action_logs').insert({
      'action_key': 'fine_notice.contract_confirmed',
      'target_type': 'fine_notice',
      'target_ref': fineNotice.id,
      'car_number': fineNotice.carNumber,
      'action_label': '과태료 계약자 확정',
      'result_status': 'success',
      'message_text': '${candidate.sourceLabel} ${candidate.customerName}',
      'meta_json': {
        'fineNoticeId': fineNotice.id,
        'candidate': {
          'sourceType': candidate.sourceType,
          'sourceId': candidate.sourceId,
          'sourceLabel': candidate.sourceLabel,
          'customerName': candidate.customerName,
          'carNumber': candidate.carNumber,
        },
      },
    });
  }

  static String _normalizeCarNumber(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim();
  }
}
