import 'package:flutter_test/flutter_test.dart';
import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';

void main() {
  test(
    'FineNoticeCase keeps raw parser data separate from confirmed fields',
    () {
      final item = FineNoticeCase(
        id: 'draft',
        createdAt: DateTime.utc(2026, 6, 19),
        status: 'review_needed',
        noticeProfile: 'toll_fee.woomyeonsan',
        noticeType: 'toll_fee',
        issuer: '우면산인프라웨이',
        documentNumber: '6419815',
        carNumber: '142호5684',
        occurredAt: '2026.05.26 10:00',
        location: '우면산터널',
        totalAmount: '2,500',
        dueDate: '2026.07.22',
        memo: '수동 확인',
        warnings: const ['차량번호 확인 필요'],
        renterName: '홍길동',
        renterPhone: '01012345678',
        renterAddress: '서울시 서초구',
        renterIdentityNo: '900101-1234567',
        renterDriverLicenseNo: '11-12-123456-78',
        rawCandidateJson: const {
          'rawCandidate': {'carNumber': '142호5688'},
        },
      );

      final row = item.toInsertRow();

      expect(row['car_number'], '142호5684');
      expect(row['raw_candidate_json'], {
        'rawCandidate': {'carNumber': '142호5688'},
      });
      expect(row['review_warnings'], ['차량번호 확인 필요']);
      expect(row['total_amount'], 2500);
      expect(row['renter_name'], '홍길동');
      expect(row['renter_phone'], '01012345678');
      expect(row['renter_address'], '서울시 서초구');
      expect(row['renter_identity_no'], '900101-1234567');
      expect(row['renter_driver_license_no'], '11-12-123456-78');
    },
  );

  test('FineNoticeCase maps Supabase row values', () {
    final item = FineNoticeCase.fromRow({
      'id': 'a0fef277-1e58-4e5b-a8c8-ef2e13577a5a',
      'created_at': '2026-06-19T10:00:00.000Z',
      'status': 'ready_for_contract_search',
      'notice_profile': 'parking.namdong',
      'notice_type': 'parking_violation',
      'issuer': '남동구청',
      'document_number': '09614500',
      'car_number': '101호4703',
      'occurred_at_text': '2026-06-01 11:04:53',
      'location': '구월동',
      'total_amount_text': '32,000',
      'due_date_text': '2026.07.08',
      'memo': null,
      'review_warnings': ['확인'],
      'raw_candidate_json': {
        'rawCandidate': {'carNumber': '101호4703'},
      },
      'confirmed_contract_source_type': 'ims_normal_contract',
      'ims_contract_id': 'normal-1',
      'ims_claim_id': null,
      'renter_snapshot_json': {'name': '홍길동'},
      'renter_name': '홍길동',
      'renter_phone': '01012345678',
      'renter_address': '서울시 서초구',
      'renter_identity_no': '900101-1234567',
      'renter_driver_license_no': '11-12-123456-78',
    });

    expect(item.carNumber, '101호4703');
    expect(item.confirmedContractSourceType, 'ims_normal_contract');
    expect(item.imsContractId, 'normal-1');
    expect(item.warnings, ['확인']);
    expect(item.renterSnapshotJson, {'name': '홍길동'});
    expect(item.renterName, '홍길동');
    expect(item.renterPhone, '01012345678');
    expect(item.renterAddress, '서울시 서초구');
    expect(item.renterIdentityNo, '900101-1234567');
    expect(item.renterDriverLicenseNo, '11-12-123456-78');
  });

  test('FineNoticeFileMetadata maps parser file payload', () {
    final file = FineNoticeFileMetadata.fromParserJson({
      'fileRole': 'notice_original',
      'localPath':
          '/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices/incoming/20260619/a.jpg',
      'sha256': 'abc',
      'mimeType': 'image/jpeg',
      'sizeBytes': 1234,
      'requestId': 'req-1',
      'backupStatus': 'pending',
    });

    expect(file.fileRole, 'notice_original');
    expect(file.parserRequestId, 'req-1');

    expect(file.toInsertRow('fine-1'), {
      'fine_notice_id': 'fine-1',
      'file_role': 'notice_original',
      'local_path':
          '/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices/incoming/20260619/a.jpg',
      'sha256': 'abc',
      'mime_type': 'image/jpeg',
      'size_bytes': 1234,
      'source_type': null,
      'parser_request_id': 'req-1',
      'backup_status': 'pending',
      'metadata_json': <String, dynamic>{},
    });
  });

  test('FineNoticeFileMetadata only shares approved share-folder files', () {
    final shareContract = FineNoticeFileMetadata.fromParserJson({
      'fileRole': 'contract_with_stamps',
      'metadataJson': {'folderKind': 'share', 'sharePackage': true},
    });
    final originalContract = FineNoticeFileMetadata.fromParserJson({
      'fileRole': 'contract_original',
      'metadataJson': {'folderKind': 'original', 'sharePackage': false},
    });
    final oldNoticeWithoutFolder = FineNoticeFileMetadata.fromParserJson({
      'fileRole': 'notice_original',
    });

    expect(shareContract.isPackageDocument, isTrue);
    expect(originalContract.isPackageDocument, isFalse);
    expect(oldNoticeWithoutFolder.isPackageDocument, isFalse);
  });

  test('FineNoticeContractCandidate maps normal and insurance sources', () {
    final normal = FineNoticeContractCandidate.fromNormalContract({
      'sourceType': 'ims_normal_contract',
      'detailId': 'normal-1',
      'contractId': 'contract-1',
      'customerName': '일반고객',
      'customerPhone': '01012345678',
      'carNumber': '142호5684',
      'rentalAt': '2026-05-31 10:00',
      'returnAt': '2026-06-02 10:00',
    });
    final insurance = FineNoticeContractCandidate.fromInsuranceClaim({
      'claimId': 'claim-1',
      'customerName': '보험고객',
      'carNumber': '101호4703',
    });

    expect(normal.sourceType, 'ims_normal_contract');
    expect(normal.sourceId, 'contract-1');
    expect(normal.toRenterSnapshotJson()['customerName'], '일반고객');
    expect(insurance.sourceType, 'ims_insurance_claim');
    expect(insurance.sourceId, 'claim-1');
  });

  test(
    'FineNoticeContractCandidate keeps resident and driver identity fields',
    () {
      final normal = FineNoticeContractCandidate.fromNormalContract({
        'sourceType': 'ims_normal_contract',
        'contractId': 'contract-1',
        'customerName': '일반고객',
        'residentRegistrationNo': '900101-1234567',
        'driverLicenseNo': '11-12-123456-78',
      });

      final snapshot = normal.toRenterSnapshotJson();

      expect(snapshot['residentRegistrationNo'], '900101-1234567');
      expect(snapshot['driverLicenseNo'], '11-12-123456-78');
    },
  );

  test('FineNoticeContractCandidate dispatches unified search payload', () {
    final normal = FineNoticeContractCandidate.fromContractSearchJson({
      'sourceType': 'ims_normal_contract',
      'detailId': 'detail-1',
      'contractId': 'contract-1',
      'customerName': '일반고객',
    });
    final insurance = FineNoticeContractCandidate.fromContractSearchJson({
      'sourceType': 'ims_insurance_claim',
      'claimId': 'claim-1',
      'customerName': '보험고객',
    });

    expect(normal.sourceType, 'ims_normal_contract');
    expect(normal.sourceId, 'contract-1');
    expect(insurance.sourceType, 'ims_insurance_claim');
    expect(insurance.sourceId, 'claim-1');
  });

  test('FineNoticeCase can persist not our vehicle status', () {
    final item = FineNoticeCase(
      id: 'draft',
      createdAt: DateTime.utc(2026, 6, 19),
      status: 'not_our_vehicle',
      noticeProfile: 'toll_fee.gangnam_sunhwan',
      noticeType: 'toll_fee',
      issuer: '강남순환도로(주)',
      documentNumber: '6418191',
      carNumber: '142호2673',
      occurredAt: '2026-05-06 09:45:25',
      location: '금천',
      totalAmount: '1900',
      dueDate: '',
      memo: '지사/외부 차량 처리',
      warnings: const ['not_our_vehicle'],
    );

    final row = item.toInsertRow();

    expect(row['status'], 'not_our_vehicle');
    expect(row['review_warnings'], ['not_our_vehicle']);
  });

  test(
    'FineNoticeParserIntakeResult maps complete multi-row notice to drafts',
    () {
      final result = FineNoticeParserIntakeResult.fromParserJson({
        'ok': true,
        'noticeProfile': 'toll_fee.gangnam_sunhwan',
        'noticeType': 'toll_fee',
        'issuer': '강남순환도로(주)',
        'documentNumber': '6418191',
        'warnings': <String>[],
        'rawCandidate': {
          'carNumber': '142호2673',
          'totalAmount': 7600,
          'items': [
            {
              'occurredAt': '2026-05-06 09:45:25',
              'amount': 1900,
              'location': '금천',
            },
            {
              'occurredAt': '2026-05-06 15:49:59',
              'amount': 1900,
              'location': '금천',
            },
            {
              'occurredAt': '2026-05-06 15:59:50',
              'amount': 1900,
              'location': '선암',
            },
            {
              'occurredAt': '2026-05-12 13:09:43',
              'amount': 1900,
              'location': '선암',
            },
          ],
        },
      }, now: DateTime.utc(2026, 6, 19));

      expect(result.kind, FineNoticeParserIntakeKind.autoMulti);
      expect(result.drafts, hasLength(4));
      expect(result.drafts.map((item) => item.occurredAt), [
        '2026-05-06 09:45:25',
        '2026-05-06 15:49:59',
        '2026-05-06 15:59:50',
        '2026-05-12 13:09:43',
      ]);
      expect(result.drafts.map((item) => item.totalAmount), [
        '1900',
        '1900',
        '1900',
        '1900',
      ]);
      expect(result.drafts[2].rawCandidateJson['selectedItemIndex'], 2);
    },
  );

  test(
    'FineNoticeParserIntakeResult keeps incomplete multi-row notice manual',
    () {
      final result = FineNoticeParserIntakeResult.fromParserJson({
        'ok': true,
        'noticeProfile': 'toll_fee.gangnam_sunhwan',
        'noticeType': 'toll_fee',
        'issuer': '강남순환도로(주)',
        'documentNumber': '6418191',
        'warnings': ['rowDate_missing'],
        'rawCandidate': {
          'carNumber': '142호2673',
          'totalAmount': 7600,
          'items': [
            {'amount': 1900, 'location': '금천'},
            {'occurredAt': '2026-05-06 15:49:59', 'amount': 1900},
          ],
        },
      }, now: DateTime.utc(2026, 6, 19));

      expect(result.kind, FineNoticeParserIntakeKind.parseFailedManualPrefill);
      expect(result.drafts, isEmpty);
      expect(result.prefillDraft, isNotNull);
      expect(result.prefillDraft!.warnings, contains('parse_failed'));
      expect(result.reasons, contains('row_1_occurredAt_missing'));
      expect(result.prefillDraft!.carNumber, '142호2673');
    },
  );

  test('FineNoticeParserIntakeResult maps complete single notice to draft', () {
    final result = FineNoticeParserIntakeResult.fromParserJson({
      'ok': true,
      'noticeProfile': 'parking.namdong',
      'noticeType': 'parking_violation',
      'issuer': '남동구청',
      'documentNumber': '09614500',
      'warnings': <String>[],
      'rawCandidate': {
        'carNumber': '101호4703',
        'violationAt': '2026-06-01 11:04:53',
        'location': '구월동',
        'totalAmount': 32000,
      },
    }, now: DateTime.utc(2026, 6, 19));

    expect(result.kind, FineNoticeParserIntakeKind.autoSingle);
    expect(result.drafts, hasLength(1));
    expect(result.drafts.single.status, 'ready_for_contract_search');
    expect(result.drafts.single.carNumber, '101호4703');
    expect(result.drafts.single.totalAmount, '32000');
  });
}
