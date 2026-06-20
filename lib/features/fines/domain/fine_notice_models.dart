class FineNoticeCandidate {
  const FineNoticeCandidate({
    this.carNumber,
    this.violationAt,
    this.passAt,
    this.location,
    this.totalAmount,
    this.dueDate,
    this.documentNumber,
    this.issuer,
    this.noticeProfile,
    this.noticeType,
  });

  final String? carNumber;
  final String? violationAt;
  final String? passAt;
  final String? location;
  final num? totalAmount;
  final String? dueDate;
  final String? documentNumber;
  final String? issuer;
  final String? noticeProfile;
  final String? noticeType;

  factory FineNoticeCandidate.fromJson(Map<String, dynamic> json) {
    final raw = (json['rawCandidate'] as Map?)?.cast<String, dynamic>() ?? {};
    return FineNoticeCandidate(
      carNumber: _string(raw['carNumber']),
      violationAt: _string(raw['violationAt']),
      passAt: _string(raw['passAt']),
      location: _string(raw['location']),
      totalAmount: _number(raw['totalAmount'] ?? raw['amount']),
      dueDate: _string(raw['dueDate']),
      documentNumber: _string(json['documentNumber']),
      issuer: _string(json['issuer']),
      noticeProfile: _string(json['noticeProfile']),
      noticeType: _string(json['noticeType']),
    );
  }
}

enum FineNoticeParserIntakeKind {
  autoSingle,
  autoMulti,
  parseFailedManualPrefill,
}

class FineNoticeParserIntakeResult {
  const FineNoticeParserIntakeResult({
    required this.kind,
    required this.drafts,
    required this.reasons,
    this.prefillDraft,
  });

  final FineNoticeParserIntakeKind kind;
  final List<FineNoticeCase> drafts;
  final FineNoticeCase? prefillDraft;
  final List<String> reasons;

  bool get isAutoAdd =>
      kind == FineNoticeParserIntakeKind.autoSingle ||
      kind == FineNoticeParserIntakeKind.autoMulti;

  bool get isParseFailed =>
      kind == FineNoticeParserIntakeKind.parseFailedManualPrefill;

  factory FineNoticeParserIntakeResult.fromParserJson(
    Map<String, dynamic> json, {
    FineNoticeFileMetadata? file,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final candidate = FineNoticeCandidate.fromJson(json);
    final rawCandidate = _map(json['rawCandidate']);
    final parserWarnings = _stringList(json['warnings']);
    final items = _mapList(rawCandidate['items']);
    final baseReasons = _contractMissingReasons(
      noticeProfile: candidate.noticeProfile,
      noticeType: candidate.noticeType,
      carNumber: candidate.carNumber,
    );

    if (items.length >= 2) {
      final rowReasons = <String>[];
      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];
        final occurredAt =
            _string(item['occurredAt']) ??
            _string(item['violationAt']) ??
            _string(item['passAt']);
        final amount = _number(item['amount'] ?? item['totalAmount']);
        if (occurredAt == null) {
          rowReasons.add('row_${index + 1}_occurredAt_missing');
        }
        if (amount == null) {
          rowReasons.add('row_${index + 1}_amount_missing');
        }
      }

      final reasons = [...baseReasons, ...rowReasons];
      if (reasons.isEmpty) {
        return FineNoticeParserIntakeResult(
          kind: FineNoticeParserIntakeKind.autoMulti,
          drafts: [
            for (var index = 0; index < items.length; index += 1)
              _caseFromCandidate(
                idSuffix: index,
                now: timestamp,
                candidate: candidate,
                json: json,
                file: file,
                warnings: parserWarnings,
                item: items[index],
                itemIndex: index,
              ),
          ],
          reasons: const [],
        );
      }

      return FineNoticeParserIntakeResult(
        kind: FineNoticeParserIntakeKind.parseFailedManualPrefill,
        drafts: const [],
        prefillDraft: _caseFromCandidate(
          idSuffix: 0,
          now: timestamp,
          candidate: candidate,
          json: json,
          file: file,
          warnings: _dedupeWarnings([
            'parse_failed',
            ...parserWarnings,
            ...reasons,
          ]),
        ),
        reasons: reasons,
      );
    }

    final occurredAt = candidate.violationAt ?? candidate.passAt;
    final reasons = [
      ...baseReasons,
      if (_string(occurredAt) == null) 'occurredAt_missing',
      if (candidate.totalAmount == null) 'amount_missing',
    ];

    if (reasons.isEmpty) {
      return FineNoticeParserIntakeResult(
        kind: FineNoticeParserIntakeKind.autoSingle,
        drafts: [
          _caseFromCandidate(
            idSuffix: 0,
            now: timestamp,
            candidate: candidate,
            json: json,
            file: file,
            warnings: parserWarnings,
          ),
        ],
        reasons: const [],
      );
    }

    return FineNoticeParserIntakeResult(
      kind: FineNoticeParserIntakeKind.parseFailedManualPrefill,
      drafts: const [],
      prefillDraft: _caseFromCandidate(
        idSuffix: 0,
        now: timestamp,
        candidate: candidate,
        json: json,
        file: file,
        warnings: _dedupeWarnings([
          'parse_failed',
          ...parserWarnings,
          ...reasons,
        ]),
      ),
      reasons: reasons,
    );
  }

  static List<String> _contractMissingReasons({
    required String? noticeProfile,
    required String? noticeType,
    required String? carNumber,
  }) {
    return [
      if (_isUnknown(noticeProfile)) 'noticeProfile_missing',
      if (_isUnknown(noticeType)) 'noticeType_missing',
      if (_string(carNumber) == null) 'carNumber_missing',
    ];
  }

  static bool _isUnknown(String? value) {
    final text = _string(value);
    return text == null || text == 'unknown' || text == 'unknown_notice';
  }

  static FineNoticeCase _caseFromCandidate({
    required int idSuffix,
    required DateTime now,
    required FineNoticeCandidate candidate,
    required Map<String, dynamic> json,
    required List<String> warnings,
    FineNoticeFileMetadata? file,
    Map<String, dynamic>? item,
    int? itemIndex,
  }) {
    final occurredAt = item == null
        ? candidate.violationAt ?? candidate.passAt
        : _string(item['occurredAt']) ??
              _string(item['violationAt']) ??
              _string(item['passAt']) ??
              candidate.violationAt ??
              candidate.passAt;
    final amount = item == null
        ? candidate.totalAmount
        : _number(item['amount'] ?? item['totalAmount']) ??
              candidate.totalAmount;
    final rawJson = item == null
        ? Map<String, dynamic>.from(json)
        : {
            ...Map<String, dynamic>.from(json),
            'selectedItemIndex': itemIndex,
            'selectedItem': Map<String, dynamic>.from(item),
          };
    final cleanWarnings = _dedupeWarnings(warnings);

    return FineNoticeCase(
      id: 'fine-${now.microsecondsSinceEpoch}-$idSuffix',
      createdAt: now,
      status: cleanWarnings.isEmpty
          ? 'ready_for_contract_search'
          : 'review_needed',
      noticeProfile: candidate.noticeProfile ?? 'unknown_notice',
      noticeType: candidate.noticeType ?? '',
      issuer: candidate.issuer ?? '',
      documentNumber: candidate.documentNumber ?? '',
      carNumber: candidate.carNumber ?? '',
      occurredAt: occurredAt ?? '',
      location: _string(item?['location']) ?? candidate.location ?? '',
      totalAmount: _formatAmount(amount),
      dueDate: '',
      memo: '',
      warnings: cleanWarnings,
      rawCandidateJson: rawJson,
      files: [?file],
    );
  }
}

class FineNoticeCase {
  const FineNoticeCase({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.noticeProfile,
    required this.noticeType,
    required this.issuer,
    required this.documentNumber,
    required this.carNumber,
    required this.occurredAt,
    required this.location,
    required this.totalAmount,
    required this.dueDate,
    required this.memo,
    required this.warnings,
    this.rawCandidateJson = const {},
    this.confirmedContractSourceType,
    this.imsContractId,
    this.imsClaimId,
    this.contractPdfSavedAt,
    this.documentPackageGeneratedAt,
    this.renterName = '',
    this.renterPhone = '',
    this.renterAddress = '',
    this.renterIdentityNo = '',
    this.renterDriverLicenseNo = '',
    this.renterSnapshotJson = const {},
    this.files = const [],
  });

  final String id;
  final DateTime createdAt;
  final String status;
  final String noticeProfile;
  final String noticeType;
  final String issuer;
  final String documentNumber;
  final String carNumber;
  final String occurredAt;
  final String location;
  final String totalAmount;
  final String dueDate;
  final String memo;
  final List<String> warnings;
  final Map<String, dynamic> rawCandidateJson;
  final String? confirmedContractSourceType;
  final String? imsContractId;
  final String? imsClaimId;
  final DateTime? contractPdfSavedAt;
  final DateTime? documentPackageGeneratedAt;
  final String renterName;
  final String renterPhone;
  final String renterAddress;
  final String renterIdentityNo;
  final String renterDriverLicenseNo;
  final Map<String, dynamic> renterSnapshotJson;
  final List<FineNoticeFileMetadata> files;

  factory FineNoticeCase.fromRow(
    Map<String, dynamic> row, {
    List<FineNoticeFileMetadata> files = const [],
  }) {
    return FineNoticeCase(
      id: _string(row['id']) ?? '',
      createdAt:
          DateTime.tryParse(_string(row['created_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: _string(row['status']) ?? 'draft',
      noticeProfile: _string(row['notice_profile']) ?? 'unknown_notice',
      noticeType: _string(row['notice_type']) ?? '',
      issuer: _string(row['issuer']) ?? '',
      documentNumber: _string(row['document_number']) ?? '',
      carNumber: _string(row['car_number']) ?? '',
      occurredAt: _string(row['occurred_at_text']) ?? '',
      location: _string(row['location']) ?? '',
      totalAmount: _string(row['total_amount_text']) ?? '',
      dueDate: _string(row['due_date_text']) ?? '',
      memo: _string(row['memo']) ?? '',
      warnings: _stringList(row['review_warnings']),
      rawCandidateJson: _map(row['raw_candidate_json']),
      confirmedContractSourceType: _string(
        row['confirmed_contract_source_type'],
      ),
      imsContractId: _string(row['ims_contract_id']),
      imsClaimId: _string(row['ims_claim_id']),
      contractPdfSavedAt: _dateTime(row['contract_pdf_saved_at']),
      documentPackageGeneratedAt: _dateTime(
        row['document_package_generated_at'],
      ),
      renterName:
          _string(row['renter_name']) ??
          _string(_map(row['renter_snapshot_json'])['customerName']) ??
          '',
      renterPhone:
          _string(row['renter_phone']) ??
          _string(_map(row['renter_snapshot_json'])['customerPhone']) ??
          '',
      renterAddress:
          _string(row['renter_address']) ??
          _string(_map(row['renter_snapshot_json'])['customerAddress']) ??
          '',
      renterIdentityNo:
          _string(row['renter_identity_no']) ??
          _string(
            _map(row['renter_snapshot_json'])['residentRegistrationNo'],
          ) ??
          _string(_map(row['renter_snapshot_json'])['identityNo']) ??
          '',
      renterDriverLicenseNo:
          _string(row['renter_driver_license_no']) ??
          _string(_map(row['renter_snapshot_json'])['driverLicenseNo']) ??
          '',
      renterSnapshotJson: _map(row['renter_snapshot_json']),
      files: files,
    );
  }

  Map<String, dynamic> toInsertRow() {
    return {
      'status': status,
      'notice_profile': noticeProfile.isEmpty
          ? 'unknown_notice'
          : noticeProfile,
      'notice_type': _nullIfEmpty(noticeType),
      'issuer': _nullIfEmpty(issuer),
      'document_number': _nullIfEmpty(documentNumber),
      'car_number': carNumber,
      'occurred_at_text': occurredAt,
      'location': _nullIfEmpty(location),
      'total_amount_text': _nullIfEmpty(totalAmount),
      'total_amount': _number(totalAmount),
      'due_date_text': _nullIfEmpty(dueDate),
      'memo': _nullIfEmpty(memo),
      'raw_candidate_json': rawCandidateJson,
      'review_warnings': warnings,
      'confirmed_contract_source_type': confirmedContractSourceType,
      'ims_contract_id': imsContractId,
      'ims_claim_id': imsClaimId,
      'contract_pdf_saved_at': contractPdfSavedAt?.toUtc().toIso8601String(),
      'document_package_generated_at': documentPackageGeneratedAt
          ?.toUtc()
          .toIso8601String(),
      'renter_name': _nullIfEmpty(renterName),
      'renter_phone': _nullIfEmpty(renterPhone),
      'renter_address': _nullIfEmpty(renterAddress),
      'renter_identity_no': _nullIfEmpty(renterIdentityNo),
      'renter_driver_license_no': _nullIfEmpty(renterDriverLicenseNo),
      'renter_snapshot_json': renterSnapshotJson,
    };
  }

  FineNoticeCase copyWith({
    String? status,
    String? noticeProfile,
    String? noticeType,
    String? issuer,
    String? documentNumber,
    String? carNumber,
    String? occurredAt,
    String? location,
    String? totalAmount,
    String? dueDate,
    String? memo,
    List<String>? warnings,
    Map<String, dynamic>? rawCandidateJson,
    String? confirmedContractSourceType,
    String? imsContractId,
    String? imsClaimId,
    DateTime? contractPdfSavedAt,
    DateTime? documentPackageGeneratedAt,
    String? renterName,
    String? renterPhone,
    String? renterAddress,
    String? renterIdentityNo,
    String? renterDriverLicenseNo,
    Map<String, dynamic>? renterSnapshotJson,
    List<FineNoticeFileMetadata>? files,
    bool clearConfirmedContract = false,
    bool clearDocumentState = false,
  }) {
    return FineNoticeCase(
      id: id,
      createdAt: createdAt,
      status: status ?? this.status,
      noticeProfile: noticeProfile ?? this.noticeProfile,
      noticeType: noticeType ?? this.noticeType,
      issuer: issuer ?? this.issuer,
      documentNumber: documentNumber ?? this.documentNumber,
      carNumber: carNumber ?? this.carNumber,
      occurredAt: occurredAt ?? this.occurredAt,
      location: location ?? this.location,
      totalAmount: totalAmount ?? this.totalAmount,
      dueDate: dueDate ?? this.dueDate,
      memo: memo ?? this.memo,
      warnings: warnings ?? this.warnings,
      rawCandidateJson: rawCandidateJson ?? this.rawCandidateJson,
      confirmedContractSourceType: clearConfirmedContract
          ? null
          : confirmedContractSourceType ?? this.confirmedContractSourceType,
      imsContractId: clearConfirmedContract
          ? null
          : imsContractId ?? this.imsContractId,
      imsClaimId: clearConfirmedContract ? null : imsClaimId ?? this.imsClaimId,
      contractPdfSavedAt: clearDocumentState
          ? null
          : contractPdfSavedAt ?? this.contractPdfSavedAt,
      documentPackageGeneratedAt: clearDocumentState
          ? null
          : documentPackageGeneratedAt ?? this.documentPackageGeneratedAt,
      renterName: clearConfirmedContract ? '' : renterName ?? this.renterName,
      renterPhone: clearConfirmedContract
          ? ''
          : renterPhone ?? this.renterPhone,
      renterAddress: clearConfirmedContract
          ? ''
          : renterAddress ?? this.renterAddress,
      renterIdentityNo: clearConfirmedContract
          ? ''
          : renterIdentityNo ?? this.renterIdentityNo,
      renterDriverLicenseNo: clearConfirmedContract
          ? ''
          : renterDriverLicenseNo ?? this.renterDriverLicenseNo,
      renterSnapshotJson: clearConfirmedContract
          ? const {}
          : renterSnapshotJson ?? this.renterSnapshotJson,
      files: files ?? this.files,
    );
  }
}

class FineNoticeFileMetadata {
  const FineNoticeFileMetadata({
    this.id,
    this.fineNoticeId,
    required this.fileRole,
    required this.localPath,
    this.sha256,
    this.mimeType,
    this.sizeBytes,
    this.sourceType,
    this.parserRequestId,
    this.backupStatus = 'pending',
    this.metadataJson = const {},
  });

  final String? id;
  final String? fineNoticeId;
  final String fileRole;
  final String localPath;
  final String? sha256;
  final String? mimeType;
  final int? sizeBytes;
  final String? sourceType;
  final String? parserRequestId;
  final String backupStatus;
  final Map<String, dynamic> metadataJson;

  factory FineNoticeFileMetadata.fromParserJson(Map<String, dynamic> json) {
    return FineNoticeFileMetadata(
      id: _string(json['id'] ?? json['fileId']),
      fineNoticeId: _string(json['fineNoticeId'] ?? json['fine_notice_id']),
      fileRole: _string(json['fileRole']) ?? 'notice_original',
      localPath: _string(json['localPath']) ?? '',
      sha256: _string(json['sha256']),
      mimeType: _string(json['mimeType']),
      sizeBytes: _int(json['sizeBytes']),
      sourceType: _string(json['sourceType']),
      parserRequestId: _string(json['requestId'] ?? json['parserRequestId']),
      backupStatus: _string(json['backupStatus']) ?? 'pending',
      metadataJson: _map(json['metadataJson']),
    );
  }

  factory FineNoticeFileMetadata.fromRow(Map<String, dynamic> row) {
    return FineNoticeFileMetadata(
      id: _string(row['id']),
      fineNoticeId: _string(row['fine_notice_id']),
      fileRole: _string(row['file_role']) ?? 'unknown',
      localPath: _string(row['local_path']) ?? '',
      sha256: _string(row['sha256']),
      mimeType: _string(row['mime_type']),
      sizeBytes: _int(row['size_bytes']),
      sourceType: _string(row['source_type']),
      parserRequestId: _string(row['parser_request_id']),
      backupStatus: _string(row['backup_status']) ?? 'pending',
      metadataJson: _map(row['metadata_json']),
    );
  }

  Map<String, dynamic> toInsertRow(String fineNoticeId) {
    return {
      'fine_notice_id': fineNoticeId,
      'file_role': fileRole,
      'local_path': localPath,
      'sha256': sha256,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'source_type': sourceType,
      'parser_request_id': parserRequestId,
      'backup_status': backupStatus,
      'metadata_json': metadataJson,
    };
  }

  String get displayName {
    final name = _string(metadataJson['displayName'] ?? metadataJson['label']);
    if (name != null) return name;
    return switch (fileRole) {
      'notice_original' => '고지서 원본',
      'contract_original' => '계약서 원본',
      'contract_with_stamps' => '계약서 사본',
      'renter_change_application' => '임차인 변경 신청서',
      'vehicle_application_list' => '통행 목록',
      'submission_receipt' => '발송 확인',
      _ => fileRole,
    };
  }

  bool get isPackageDocument {
    final folderKind = _string(metadataJson['folderKind']);
    final sharePackage = metadataJson['sharePackage'] == true;
    if (folderKind != 'share' && !sharePackage) return false;
    return const {
      'notice_original',
      'contract_with_stamps',
      'renter_change_application',
      'vehicle_application_list',
    }.contains(fileRole);
  }
}

class FineNoticeContractCandidate {
  const FineNoticeContractCandidate({
    required this.sourceType,
    required this.sourceId,
    required this.sourceLabel,
    required this.customerName,
    required this.customerPhone,
    required this.carNumber,
    required this.rentalAt,
    required this.returnAt,
    required this.title,
    required this.matchReason,
    required this.rawJson,
  });

  final String sourceType;
  final String sourceId;
  final String sourceLabel;
  final String customerName;
  final String customerPhone;
  final String carNumber;
  final String rentalAt;
  final String returnAt;
  final String title;
  final String matchReason;
  final Map<String, dynamic> rawJson;

  factory FineNoticeContractCandidate.fromContractSearchJson(
    Map<String, dynamic> json,
  ) {
    final sourceType = _string(json['sourceType']);
    if (sourceType == 'ims_insurance_claim' ||
        _string(json['claimId']) != null) {
      return FineNoticeContractCandidate.fromInsuranceClaim(json);
    }
    return FineNoticeContractCandidate.fromNormalContract(json);
  }

  factory FineNoticeContractCandidate.fromNormalContract(
    Map<String, dynamic> json,
  ) {
    final sourceId =
        _string(json['contractId']) ??
        _string(json['normalContractId']) ??
        _string(json['detailId']) ??
        _string(json['reservationNumber']) ??
        _string(json['scheduleId']) ??
        '';
    return FineNoticeContractCandidate(
      sourceType: 'ims_normal_contract',
      sourceId: sourceId,
      sourceLabel: '일반계약',
      customerName: _string(json['customerName']) ?? '',
      customerPhone: _string(json['customerPhone']) ?? '',
      carNumber: _string(json['carNumber']) ?? '',
      rentalAt: _string(json['rentalAt']) ?? '',
      returnAt: _string(json['returnAt']) ?? '',
      title: _string(json['title']) ?? '',
      matchReason: '차량번호/일자 기준 IMS 일반계약 후보',
      rawJson: Map<String, dynamic>.from(json),
    );
  }

  factory FineNoticeContractCandidate.fromInsuranceClaim(
    Map<String, dynamic> json,
  ) {
    final sourceId = _string(json['claimId']) ?? '';
    return FineNoticeContractCandidate(
      sourceType: 'ims_insurance_claim',
      sourceId: sourceId,
      sourceLabel: '보험계약',
      customerName: _string(json['customerName']) ?? '',
      customerPhone: _string(json['customerPhone']) ?? '',
      carNumber: _string(json['carNumber']) ?? '',
      rentalAt: _string(json['rentalAt']) ?? '',
      returnAt: _string(json['returnAt']) ?? '',
      title: _string(json['title']) ?? '',
      matchReason: '차량번호/일자 기준 IMS 보험계약 후보',
      rawJson: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toRenterSnapshotJson() {
    final residentRegistrationNo =
        _string(rawJson['residentRegistrationNo']) ??
        _string(rawJson['identityNo']) ??
        _string(rawJson['customerIdNumber']);
    final driverLicenseNo =
        _string(rawJson['driverLicenseNo']) ??
        _string(rawJson['licenseNumber']) ??
        _string(rawJson['driver_license_number']);
    return {
      'sourceType': sourceType,
      'sourceId': sourceId,
      'sourceLabel': sourceLabel,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'residentRegistrationNo': residentRegistrationNo,
      'driverLicenseNo': driverLicenseNo,
      'carNumber': carNumber,
      'rentalAt': rentalAt,
      'returnAt': returnAt,
      'title': title,
      'matchReason': matchReason,
      'raw': rawJson,
    };
  }
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

num? _number(Object? value) {
  if (value is num) return value;
  final text = _string(value);
  if (text == null) return null;
  return num.tryParse(text.replaceAll(RegExp(r'[^0-9.-]'), ''));
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = _string(value);
  if (text == null) return null;
  return int.tryParse(text);
}

DateTime? _dateTime(Object? value) {
  final text = _string(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

String? _nullIfEmpty(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const [];
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>)
        item
      else if (item is Map)
        item.cast<String, dynamic>(),
  ];
}

String _formatAmount(num? value) {
  if (value == null) return '';
  if (value % 1 == 0) return value.toInt().toString();
  return value.toString();
}

List<String> _dedupeWarnings(Iterable<String> warnings) {
  final seen = <String>{};
  return [
    for (final warning in warnings.map((item) => item.trim()))
      if (warning.isNotEmpty && seen.add(warning)) warning,
  ];
}
