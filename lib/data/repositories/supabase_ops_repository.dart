import 'dart:convert';
import 'dart:math';

import 'package:rentcar00_ops/data/models/external_reservation_link.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';
import 'package:rentcar00_ops/shared/constants/tab_keys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOpsRepository {
  SupabaseOpsRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<String> createReservationFromVehicle({
    required StatusBoardRecord car,
    required String reservationNumber,
    required String customerName,
    required String customerPhone,
    required String customerBirthDate,
    required String referralSource,
    required String paymentAmount,
    required DateTime startAt,
    required DateTime endAt,
    required String pickupLocation,
    required String dropoffLocation,
    required String noteText,
    String createdVia = 'status_board_vehicle_detail',
  }) async {
    final normalizedReservationNumber = reservationNumber.trim();
    final normalizedCustomerName = customerName.trim();
    final normalizedCustomerPhone = _digitsOnly(customerPhone);
    final normalizedCustomerBirthDate = _normalizeBirthDate(customerBirthDate);
    final normalizedReferralSource = referralSource.trim();
    final normalizedPaymentAmount = _digitsOnly(paymentAmount);
    final normalizedPickupLocation = pickupLocation.trim();
    final normalizedDropoffLocation = dropoffLocation.trim();
    final normalizedNoteText = noteText.trim();

    final reservationId = _generateId(prefix: 'R');
    final insertedReservation = await _client
        .from('rc00_ops_reservations')
        .insert({
          'reservation_id': reservationId,
          'reservation_number': normalizedReservationNumber,
          'car_number': car.carNumber,
          'car_name': car.carName,
          'customer_name': normalizedCustomerName,
          'customer_phone': normalizedCustomerPhone,
          'customer_birth_date': normalizedCustomerBirthDate,
          'referral_source': normalizedReferralSource,
          'payment_amount': normalizedPaymentAmount,
          'start_at': _toDbTimestamp(startAt),
          'end_at': _toDbTimestamp(endAt),
          'pickup_location': normalizedPickupLocation,
          'dropoff_location': normalizedDropoffLocation,
          'reservation_status': '예약중',
          'note_text': normalizedNoteText,
          'meta_json': {
            'created_via': createdVia,
            'source_record_id': car.recordId,
          },
        })
        .select('id')
        .single();

    final reservationRefId = insertedReservation['id'] as String;
    final tabKey = _deriveReservationTabKey(startAt, endAt);
    final checkPayload = {
      'customer_name_verified': normalizedCustomerName.isEmpty
          ? 'pending'
          : 'done',
      'customer_phone_verified': normalizedCustomerPhone.isEmpty
          ? 'pending'
          : 'done',
      'pickup_location_verified': normalizedPickupLocation.isEmpty
          ? 'pending'
          : 'done',
    };

    await _client.from('rc00_ops_reservation_states').insert({
      'reservation_id': reservationId,
      'reservation_ref_id': reservationRefId,
      'tab_key': tabKey,
      'needs_attention': checkPayload.values.contains('pending'),
      'warning_level': checkPayload.values.contains('pending')
          ? 'warning'
          : null,
      'check_payload_json': checkPayload,
      'memo_text': normalizedNoteText.isEmpty ? null : normalizedNoteText,
      'last_action_at': DateTime.now().toIso8601String(),
    });

    final pickupScheduleId = _generateId(prefix: 'SCH');
    final returnScheduleId = _generateId(prefix: 'SCH');

    await _client.from('rc00_ops_schedules').insert([
      {
        'schedule_id': pickupScheduleId,
        'reservation_id': reservationId,
        'reservation_number': normalizedReservationNumber,
        'car_number': car.carNumber,
        'car_name': car.carName,
        'schedule_type': '배차',
        'schedule_at': _toDbTimestamp(startAt),
        'schedule_done': false,
        'location_text': normalizedPickupLocation,
        'detail_text': normalizedNoteText,
        'payload_json': {
          'created_via': createdVia,
          'reservation_id': reservationId,
          'reservation_number': normalizedReservationNumber,
          'status': '배차',
        },
      },
      {
        'schedule_id': returnScheduleId,
        'reservation_id': reservationId,
        'reservation_number': normalizedReservationNumber,
        'car_number': car.carNumber,
        'car_name': car.carName,
        'schedule_type': '반납',
        'schedule_at': _toDbTimestamp(endAt),
        'schedule_done': false,
        'location_text': normalizedDropoffLocation,
        'detail_text': normalizedNoteText,
        'payload_json': {
          'created_via': createdVia,
          'reservation_id': reservationId,
          'reservation_number': normalizedReservationNumber,
          'status': '반납',
        },
      },
    ]);

    return reservationId;
  }

  Future<ExternalReservationLink?> fetchExternalReservationLink({
    required String reservationId,
  }) async {
    final rows = await _client
        .from('rc00_ops_external_reservation_links')
        .select()
        .eq('provider', 'ims')
        .eq('reservation_id', reservationId.trim())
        .limit(1);

    if (rows.isEmpty) return null;
    return ExternalReservationLink.fromRow(rows.first);
  }

  Future<List<ExternalReservationLink>> fetchExternalReservationLinks() async {
    final rows = await _client
        .from('rc00_ops_external_reservation_links')
        .select()
        .eq('provider', 'ims')
        .order('created_at', ascending: false);

    return rows
        .map<ExternalReservationLink>(ExternalReservationLink.fromRow)
        .toList();
  }

  Future<void> upsertExternalReservationLink({
    required String reservationId,
    String? reservationRefId,
    String? externalReservationId,
    String? externalDetailId,
    required String externalStatus,
    required String linkKey,
    Map<String, dynamic> lastPayloadJson = const {},
    Map<String, dynamic> lastResultJson = const {},
    String? errorText,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from('rc00_ops_external_reservation_links').upsert({
      'reservation_id': reservationId.trim(),
      'reservation_ref_id': reservationRefId,
      'provider': 'ims',
      'external_reservation_id': externalReservationId?.trim(),
      'external_detail_id': externalDetailId?.trim(),
      'external_status': externalStatus.trim(),
      'link_key': linkKey.trim(),
      'last_payload_json': lastPayloadJson,
      'last_result_json': lastResultJson,
      'linked_at': externalStatus == 'linked' ? now : null,
      'last_checked_at': now,
      'deleted_at': externalStatus == 'deleted' ? now : null,
      'error_text': errorText?.trim(),
      'updated_at': now,
    }, onConflict: 'provider,reservation_id');
  }

  Future<void> markExternalReservationLinkDeleted({
    required String reservationId,
    Map<String, dynamic> lastResultJson = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client
        .from('rc00_ops_external_reservation_links')
        .update({
          'external_status': 'deleted',
          'deleted_at': now,
          'last_checked_at': now,
          'last_result_json': lastResultJson,
          'error_text': null,
          'updated_at': now,
        })
        .eq('provider', 'ims')
        .eq('reservation_id', reservationId.trim());
  }

  Future<void> markExternalReservationLinkFailed({
    required String reservationId,
    required String errorText,
    Map<String, dynamic> lastResultJson = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client
        .from('rc00_ops_external_reservation_links')
        .update({
          'external_status': 'failed',
          'last_checked_at': now,
          'last_result_json': lastResultJson,
          'error_text': errorText.trim(),
          'updated_at': now,
        })
        .eq('provider', 'ims')
        .eq('reservation_id', reservationId.trim());
  }

  Future<void> markExternalReservationLinkUnlinked({
    required String reservationId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client
        .from('rc00_ops_external_reservation_links')
        .update({
          'external_status': 'unlinked',
          'last_checked_at': now,
          'error_text': null,
          'updated_at': now,
        })
        .eq('provider', 'ims')
        .eq('reservation_id', reservationId.trim());
  }

  Future<void> updateCarInstantStatus({
    required String carRowId,
    required String status,
    required String statusAction,
    required String customerName,
    required String customerPhone,
    required DateTime? startAt,
    required DateTime? endAt,
    required String pickupLocation,
    required String parkingLocation,
    required String noteText,
  }) async {
    await _client
        .from('rc00_ops_cars')
        .update({
          'status': status,
          'status_action': statusAction,
          'customer_name': customerName.trim(),
          'customer_phone': customerPhone.trim(),
          'start_at_ts': startAt == null ? null : _toDbTimestamp(startAt),
          'end_at_ts': endAt == null ? null : _toDbTimestamp(endAt),
          'pickup_location': pickupLocation.trim(),
          'parking_location': parkingLocation.trim(),
          'note_text': noteText.trim(),
        })
        .eq('id', carRowId);
  }

  Future<void> completeCarReturn({required String carRowId}) async {
    await _client
        .from('rc00_ops_cars')
        .update({
          'status': '대기중',
          'status_action': '반납 완료',
          'car_wash': 'FALSE',
          'interior_wash': 'FALSE',
          'parking_location': '수푸레',
        })
        .eq('id', carRowId);
  }

  Future<void> createScheduleOnly({
    required String scheduleType,
    required DateTime scheduleAt,
    required String carNumber,
    required String carName,
    required String locationText,
    required String detailText,
  }) async {
    final normalizedScheduleType = scheduleType.trim();
    final normalizedCarNumber = carNumber.trim();
    final normalizedCarName = carName.trim();
    final normalizedLocationText = locationText.trim();
    final normalizedDetailText = detailText.trim();

    await _client.from('rc00_ops_schedules').insert({
      'schedule_id': _generateId(prefix: 'SCH'),
      'reservation_id': '',
      'reservation_number': '',
      'car_number': normalizedCarNumber,
      'car_name': normalizedCarName,
      'schedule_type': normalizedScheduleType,
      'schedule_at': _toDbTimestamp(scheduleAt),
      'schedule_done': false,
      'location_text': normalizedLocationText,
      'detail_text': normalizedDetailText,
      'payload_json': {
        'created_via': 'status_board_schedule_tab',
        'status': normalizedScheduleType,
      },
    });
  }

  Future<void> updateSchedule({
    required String scheduleRowId,
    required String reservationId,
    required String scheduleType,
    required DateTime scheduleAt,
    required String carNumber,
    required String carName,
    required String locationText,
    required String detailText,
  }) async {
    final normalizedScheduleType = scheduleType.trim();

    await _client
        .from('rc00_ops_schedules')
        .update({
          'schedule_type': normalizedScheduleType,
          'schedule_at': _toDbTimestamp(scheduleAt),
          'car_number': carNumber.trim(),
          'car_name': carName.trim(),
          'location_text': locationText.trim(),
          'detail_text': detailText.trim(),
          'payload_json': {
            'updated_via': 'status_board_schedule_detail',
            'status': normalizedScheduleType,
          },
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', scheduleRowId);

    await _syncReservationFromScheduleEdit(
      reservationId: reservationId,
      scheduleType: normalizedScheduleType,
      scheduleAt: scheduleAt,
      locationText: locationText,
    );
  }

  Future<void> completeSchedule({
    required String scheduleRowId,
    required String scheduleType,
    required String reservationId,
    required String carNumber,
  }) async {
    final normalizedScheduleType = scheduleType.trim();
    final normalizedReservationId = reservationId.trim();
    final normalizedCarNumber = carNumber.trim();
    final now = DateTime.now().toIso8601String();

    await _client
        .from('rc00_ops_schedules')
        .update({'schedule_done': true, 'updated_at': now})
        .eq('id', scheduleRowId);

    if (normalizedReservationId.isNotEmpty) {
      if (normalizedScheduleType == '배차') {
        await _updateReservationLifecycle(
          reservationId: normalizedReservationId,
          reservationStatus: '배차중',
          tabKey: TabKeys.inUse,
        );
      } else if (normalizedScheduleType == '반납') {
        await _updateReservationLifecycle(
          reservationId: normalizedReservationId,
          reservationStatus: '완료',
          tabKey: TabKeys.completed,
        );
      }
    }

    if (normalizedScheduleType == '반납') {
      if (normalizedCarNumber.isNotEmpty) {
        await _resetCarAfterReturnByNumber(normalizedCarNumber);
      }
      return;
    }

    if (normalizedScheduleType != '배차' || normalizedCarNumber.isEmpty) return;

    final reservationRow = normalizedReservationId.isEmpty
        ? null
        : await _client
              .from('rc00_ops_reservations')
              .select(
                'customer_name, customer_phone, pickup_location, start_at, end_at, note_text',
              )
              .eq('reservation_id', normalizedReservationId)
              .maybeSingle();

    final reservationStartAt = _parseDateTime(reservationRow?['start_at']);
    final reservationEndAt = _parseDateTime(reservationRow?['end_at']);
    final updatePayload = <String, dynamic>{
      'status': '일반',
      'status_action': '일정완료',
      if ((reservationRow?['customer_name'] as String?)?.trim().isNotEmpty ??
          false)
        'customer_name': (reservationRow?['customer_name'] as String).trim(),
      if ((reservationRow?['customer_phone'] as String?)?.trim().isNotEmpty ??
          false)
        'customer_phone': (reservationRow?['customer_phone'] as String).trim(),
      if ((reservationRow?['pickup_location'] as String?)?.trim().isNotEmpty ??
          false)
        'pickup_location': (reservationRow?['pickup_location'] as String)
            .trim(),
      if (reservationStartAt != null)
        'start_at_ts': _toDbTimestamp(reservationStartAt),
      if (reservationEndAt != null)
        'end_at_ts': _toDbTimestamp(reservationEndAt),
      if ((reservationRow?['note_text'] as String?)?.trim().isNotEmpty ?? false)
        'note_text': (reservationRow?['note_text'] as String).trim(),
    };

    await _client
        .from('rc00_ops_cars')
        .update(updatePayload)
        .eq('car_number', normalizedCarNumber);
  }

  Future<void> _syncReservationFromScheduleEdit({
    required String reservationId,
    required String scheduleType,
    required DateTime scheduleAt,
    required String locationText,
  }) async {
    final normalizedReservationId = reservationId.trim();
    if (normalizedReservationId.isEmpty) return;

    final normalizedScheduleType = scheduleType.trim();
    final updatePayload = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (normalizedScheduleType == '배차') {
      updatePayload['start_at'] = _toDbTimestamp(scheduleAt);
      updatePayload['pickup_location'] = locationText.trim();
    } else if (normalizedScheduleType == '반납') {
      updatePayload['end_at'] = _toDbTimestamp(scheduleAt);
      updatePayload['dropoff_location'] = locationText.trim();
    } else {
      return;
    }

    await _client
        .from('rc00_ops_reservations')
        .update(updatePayload)
        .eq('reservation_id', normalizedReservationId);
  }

  Future<void> _updateReservationLifecycle({
    required String reservationId,
    required String reservationStatus,
    required String tabKey,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client
        .from('rc00_ops_reservations')
        .update({'reservation_status': reservationStatus, 'updated_at': now})
        .eq('reservation_id', reservationId.trim());

    await _client
        .from('rc00_ops_reservation_states')
        .update({'tab_key': tabKey, 'last_action_at': now, 'updated_at': now})
        .eq('reservation_id', reservationId.trim());
  }

  Future<void> _resetCarAfterReturnByNumber(String carNumber) async {
    await _client
        .from('rc00_ops_cars')
        .update({
          'status': '대기중',
          'status_action': '반납 완료',
          'car_wash': 'FALSE',
          'interior_wash': 'FALSE',
          'parking_location': '수푸레',
        })
        .eq('car_number', carNumber.trim());
  }

  Future<void> deleteSchedule({required String scheduleRowId}) async {
    await _client.from('rc00_ops_schedules').delete().eq('id', scheduleRowId);
  }

  Future<void> updateParkingLocation({
    required String carRowId,
    required String parkingLocation,
  }) async {
    await _client
        .from('rc00_ops_cars')
        .update({
          'parking_location': parkingLocation.trim(),
          'status_action': '주차',
        })
        .eq('id', carRowId);
  }

  Future<void> updateCarManagementInfo({
    required String carRowId,
    required String carInspectionAt,
    required String carAgeExpiryAt,
  }) async {
    await _client
        .from('rc00_ops_cars')
        .update({
          'car_inspection_at': carInspectionAt.trim(),
          'car_age_expiry_at': carAgeExpiryAt.trim(),
        })
        .eq('id', carRowId);
  }

  Future<void> setCarWashFlag({
    required String carRowId,
    required bool interior,
    required bool active,
  }) async {
    await _client
        .from('rc00_ops_cars')
        .update({
          interior ? 'interior_wash' : 'car_wash': active ? 'TRUE' : 'FALSE',
        })
        .eq('id', carRowId);
  }

  Future<List<ReservationRecord>> fetchReservations() async {
    final reservationsResponse = await _client
        .from('rc00_ops_reservations')
        .select()
        .order('start_at', ascending: true);

    final statesResponse = await _client
        .from('rc00_ops_reservation_states')
        .select();

    final stateByReservationId = {
      for (final row in statesResponse) (row['reservation_id'] as String): row,
    };

    final records = <ReservationRecord>[];

    for (final row in reservationsResponse) {
      final reservationId = row['reservation_id'] as String;
      final state = stateByReservationId[reservationId];
      if (state == null) {
        continue;
      }

      final tabKey = state['tab_key'] as String? ?? TabKeys.pending;
      final reservationStatus = (row['reservation_status'] as String?) ?? '';
      final checkPayload = _toStringMap(state['check_payload_json']);
      final warningLevel = state['warning_level'] as String?;
      final noteParts = <String>[
        if ((state['memo_text'] as String?)?.isNotEmpty ?? false)
          state['memo_text'] as String,
        if (reservationStatus.isNotEmpty) '예약상태: $reservationStatus',
      ];

      records.add(
        ReservationRecord(
          reservationId: reservationId,
          reservationNumber: (row['reservation_number'] as String?) ?? '',
          customerName: (row['customer_name'] as String?) ?? '',
          customerPhone: (row['customer_phone'] as String?) ?? '',
          customerBirthDate: (row['customer_birth_date'] as String?) ?? '',
          referralSource: (row['referral_source'] as String?) ?? '',
          paymentAmount: (row['payment_amount'] as String?) ?? '',
          carNumber: (row['car_number'] as String?) ?? '',
          carName: (row['car_name'] as String?) ?? '',
          tab: _tabFromKey(tabKey),
          statusKey: reservationStatus,
          startAt: _parseDateTime(row['start_at']) ?? DateTime(2000),
          endAt: _parseDateTime(row['end_at']) ?? DateTime(2000),
          locationSummary: (row['pickup_location'] as String?) ?? '',
          noteText: noteParts.join(' · '),
          primaryBadges: _deriveBadges(
            checkPayload: checkPayload,
            warningLevel: warningLevel,
            tabKey: tabKey,
            statusRaw: reservationStatus,
          ),
          checkPayload: checkPayload,
          actionLogs: const [],
        ),
      );
    }

    return records;
  }

  Future<List<StatusBoardRecord>> fetchStatusBoardRecords() async {
    final carsResponse = await _client
        .from('rc00_ops_cars')
        .select()
        .order('car_number', ascending: true);

    final schedulesResponse = await _client
        .from('rc00_ops_schedules')
        .select()
        .inFilter('schedule_type', ['배차', '반납', '기타'])
        .eq('schedule_done', false)
        .order('schedule_at', ascending: true);

    final reservationsResponse = await _client
        .from('rc00_ops_reservations')
        .select(
          'reservation_id, customer_name, customer_phone, pickup_location, start_at, end_at, note_text, car_name, car_number',
        );

    final cars = carsResponse.map<StatusBoardRecord>(_toCarRecord).toList();
    final carByNumber = {
      for (final car in cars)
        if (car.carNumber.isNotEmpty) car.carNumber: car,
    };
    final reservationById = {
      for (final row in reservationsResponse)
        ((row['reservation_id'] as String?) ?? '').trim(): row,
    };

    final schedules =
        schedulesResponse
            .map<StatusBoardRecord>(
              (row) => _toScheduleRecord(row, carByNumber, reservationById),
            )
            .toList()
          ..sort((a, b) {
            final aAt = a.sortAt ?? DateTime(2999);
            final bAt = b.sortAt ?? DateTime(2999);
            return aAt.compareTo(bAt);
          });

    return [...cars, ...schedules];
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return const {};
  }

  Map<String, String> _toStringMap(dynamic value) {
    final mapped = _toMap(value);
    return mapped.map(
      (key, dynamic val) => MapEntry(key, val?.toString() ?? ''),
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  ReservationTab _tabFromKey(String key) {
    return ReservationTab.values.firstWhere(
      (tab) => tab.key == key,
      orElse: () => ReservationTab.pending,
    );
  }

  List<String> _deriveBadges({
    required Map<String, String> checkPayload,
    required String? warningLevel,
    required String tabKey,
    required String statusRaw,
  }) {
    final badges = <String>[];

    if (checkPayload['customer_name_verified'] != 'done') {
      badges.add('고객명 미확인');
    }
    if (checkPayload['customer_phone_verified'] != 'done') {
      badges.add('연락처 미확인');
    }
    if (checkPayload['pickup_location_verified'] != 'done') {
      badges.add('위치 미확인');
    }
    if (warningLevel == 'warning' && badges.isEmpty) {
      badges.add('확인 필요');
    }
    if (statusRaw == '반납완료') {
      badges.add('반납 완료');
    }
    if (tabKey == TabKeys.pickupToday) {
      badges.add('오늘배차');
    }

    return badges;
  }

  StatusBoardRecord _toCarRecord(Map<String, dynamic> row) {
    final status = (row['status'] as String? ?? '').trim();
    final tab = switch (status) {
      '대기' || '대기중' => StatusBoardTab.idle,
      '보험' => StatusBoardTab.insurance,
      '일반' => StatusBoardTab.general,
      '장기' => StatusBoardTab.longTerm,
      _ => StatusBoardTab.general,
    };
    final carWash = (row['car_wash'] as String? ?? '').trim();
    final interiorWash = (row['interior_wash'] as String? ?? '').trim();
    final noteText = (row['note_text'] as String? ?? '').trim();
    final statusAction = (row['status_action'] as String? ?? '').trim();
    final startAt = _parseDateTime(row['start_at_ts']);
    final endAt = _parseDateTime(row['end_at_ts']);
    final startAtDisplay = startAt == null
        ? _displayValue(row['start_at'])
        : _formatDisplayDateTime(startAt);
    final endAtDisplay = endAt == null
        ? _displayValue(row['end_at'])
        : _formatDisplayDateTime(endAt);

    return StatusBoardRecord(
      recordId: 'car:${row['id']}',
      tab: tab,
      sourceKind: 'car',
      carNumber: (row['car_number'] as String? ?? '').trim(),
      carName: (row['car_name'] as String? ?? '').trim(),
      status: status,
      customerName: (row['customer_name'] as String? ?? '').trim(),
      customerPhone: (row['customer_phone'] as String? ?? '').trim(),
      startAt: startAtDisplay,
      endAt: endAtDisplay,
      pickupLocation: (row['pickup_location'] as String? ?? '').trim(),
      parkingLocation: (row['parking_location'] as String? ?? '').trim(),
      noteText: noteText,
      statusAction: statusAction,
      carWash: carWash,
      interiorWash: interiorWash,
      timeLabel: _formatBoardPeriod(startAtDisplay, endAtDisplay),
      locationSummary: _joinNonEmpty([
        (row['pickup_location'] as String? ?? '').trim(),
        (row['parking_location'] as String? ?? '').trim(),
      ], separator: ' / '),
      primaryBadges: _boardBadges(
        carWash: carWash,
        interiorWash: interiorWash,
        noteText: noteText,
        statusAction: statusAction,
      ),
      sortAt:
          endAt ??
          startAt ??
          _parseFlexibleDateTime(_displayValue(row['end_at'])) ??
          _parseFlexibleDateTime(_displayValue(row['start_at'])),
      carRegisteredAt: (row['car_registered_at'] as String? ?? '').trim(),
      carInspectionAt: (row['car_inspection_at'] as String? ?? '').trim(),
      carAgeExpiryAt: (row['car_age_expiry_at'] as String? ?? '').trim(),
      carNumberFront: (row['car_number_front'] as String? ?? '').trim(),
      carNumberMiddle: (row['car_number_middle'] as String? ?? '').trim(),
      carNumberRear: (row['car_number_rear'] as String? ?? '').trim(),
      reservationId: '',
      reservationNumber: '',
    );
  }

  StatusBoardRecord _toScheduleRecord(
    Map<String, dynamic> row,
    Map<String, StatusBoardRecord> carByNumber,
    Map<String, dynamic> reservationById,
  ) {
    final carNumber = (row['car_number'] as String? ?? '').trim();
    final linkedCar = carByNumber[carNumber];
    final scheduleType = (row['schedule_type'] as String? ?? '').trim();
    final scheduleAt = _parseDateTime(row['schedule_at']);
    final scheduleAtDisplay = scheduleAt == null
        ? ''
        : _formatDisplayDateTime(scheduleAt);
    final rawReservationId = (row['reservation_id'] as String? ?? '').trim();
    final linkedReservation =
        reservationById[rawReservationId] as Map<String, dynamic>?;
    final linkedReservationId = linkedReservation == null
        ? ''
        : rawReservationId;

    return StatusBoardRecord(
      recordId: 'schedule:${row['id']}',
      tab: StatusBoardTab.schedule,
      sourceKind: 'schedule',
      carNumber: carNumber,
      carName: (row['car_name'] as String? ?? '').trim().isNotEmpty
          ? (row['car_name'] as String).trim()
          : ((linkedReservation?['car_name'] as String?)?.trim().isNotEmpty ??
                false)
          ? (linkedReservation?['car_name'] as String).trim()
          : (linkedCar?.carName ?? ''),
      status: linkedCar?.status ?? scheduleType,
      customerName:
          ((linkedReservation?['customer_name'] as String?) ?? '')
              .trim()
              .isNotEmpty
          ? (linkedReservation?['customer_name'] as String).trim()
          : (linkedCar?.customerName ?? ''),
      customerPhone:
          ((linkedReservation?['customer_phone'] as String?) ?? '')
              .trim()
              .isNotEmpty
          ? (linkedReservation?['customer_phone'] as String).trim()
          : (linkedCar?.customerPhone ?? ''),
      startAt: scheduleAtDisplay,
      endAt: ((linkedReservation?['end_at'] as String?) ?? '').trim(),
      pickupLocation:
          ((linkedReservation?['pickup_location'] as String?) ?? '')
              .trim()
              .isNotEmpty
          ? (linkedReservation?['pickup_location'] as String).trim()
          : (row['location_text'] as String? ?? '').trim(),
      parkingLocation: linkedCar?.parkingLocation ?? '',
      noteText:
          ((linkedReservation?['note_text'] as String?) ?? '').trim().isNotEmpty
          ? (linkedReservation?['note_text'] as String).trim()
          : (linkedCar?.noteText ?? ''),
      statusAction: scheduleType,
      carWash: linkedCar?.carWash ?? '',
      interiorWash: linkedCar?.interiorWash ?? '',
      timeLabel: scheduleAt == null
          ? ''
          : _formatScheduleLabelFromDate(scheduleAt),
      locationSummary: (row['location_text'] as String? ?? '').trim(),
      primaryBadges: [scheduleType],
      sortAt: scheduleAt,
      scheduleId: (row['schedule_id'] as String? ?? '').trim(),
      scheduleType: scheduleType,
      scheduleDone: row['schedule_done'] == true ? 'TRUE' : '',
      detailText: (row['detail_text'] as String? ?? '').trim(),
      reservationId: linkedReservationId,
      reservationNumber: (row['reservation_number'] as String? ?? '').trim(),
      carRegisteredAt: linkedCar?.carRegisteredAt ?? '',
      carInspectionAt: linkedCar?.carInspectionAt ?? '',
      carAgeExpiryAt: linkedCar?.carAgeExpiryAt ?? '',
      carNumberFront: linkedCar?.carNumberFront ?? '',
      carNumberMiddle: linkedCar?.carNumberMiddle ?? '',
      carNumberRear: linkedCar?.carNumberRear ?? '',
    );
  }

  List<String> _boardBadges({
    required String carWash,
    required String interiorWash,
    required String noteText,
    required String statusAction,
  }) {
    final badges = <String>[];
    if (_isTruthy(carWash)) badges.add('세차');
    if (_isTruthy(interiorWash)) badges.add('실내세차');
    if (statusAction.isNotEmpty) badges.add(statusAction);
    if (noteText.isNotEmpty) badges.add('비고');
    return badges.take(3).toList();
  }

  bool _isTruthy(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return raw == 'true' || raw == 'y' || raw == 'yes' || raw == '1';
  }

  DateTime? _parseFlexibleDateTime(String value) {
    if (value.isEmpty) return null;

    var normalized = value.trim();
    if (normalized.isEmpty) return null;

    normalized = normalized.replaceAll('.', '-').replaceAll('/', '-');
    normalized = normalized.replaceAll(RegExp(r'-+'), '-');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'-$'), '');

    final dateOnlyMatch = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
    ).firstMatch(normalized);
    if (dateOnlyMatch != null) {
      final year = int.tryParse(dateOnlyMatch.group(1)!);
      final month = int.tryParse(dateOnlyMatch.group(2)!);
      final day = int.tryParse(dateOnlyMatch.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }

    final dateTimeMatch = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$',
    ).firstMatch(normalized);
    if (dateTimeMatch != null) {
      final year = int.tryParse(dateTimeMatch.group(1)!);
      final month = int.tryParse(dateTimeMatch.group(2)!);
      final day = int.tryParse(dateTimeMatch.group(3)!);
      final hour = int.tryParse(dateTimeMatch.group(4)!);
      final minute = int.tryParse(dateTimeMatch.group(5)!);
      final second = int.tryParse(dateTimeMatch.group(6) ?? '0');
      if (year != null &&
          month != null &&
          day != null &&
          hour != null &&
          minute != null &&
          second != null) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    return DateTime.tryParse(normalized.replaceFirst(' ', 'T')) ??
        DateTime.tryParse(normalized);
  }

  String _formatBoardPeriod(String startAt, String endAt) {
    if (startAt.isEmpty && endAt.isEmpty) return '';
    if (startAt.isEmpty) return endAt;
    if (endAt.isEmpty) return startAt;
    return '$startAt → $endAt';
  }

  String _formatScheduleLabelFromDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[local.weekday - 1];
    return '${two(local.month)}/${two(local.day)}($weekday) ${two(local.hour)}:${two(local.minute)}';
  }

  String _joinNonEmpty(List<String> values, {String separator = ' · '}) {
    return values.where((value) => value.isNotEmpty).join(separator);
  }

  String _displayValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is DateTime) return value.toIso8601String();
    return value.toString().trim();
  }

  String _formatDisplayDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _toDbTimestamp(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  String _deriveReservationTabKey(DateTime startAt, DateTime endAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startAt.year, startAt.month, startAt.day);
    final endDay = DateTime(endAt.year, endAt.month, endAt.day);
    if (endDay.isBefore(today)) return TabKeys.completed;
    if (endDay == today) return TabKeys.returnDue;
    if (startDay == today) return TabKeys.pickupToday;
    if (startDay.isBefore(today)) return TabKeys.inUse;
    return TabKeys.pending;
  }

  String _generateId({required String prefix}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D+'), '');

  String _normalizeBirthDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';

    final compact = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (compact.length == 8) {
      return '${compact.substring(0, 4)}-${compact.substring(4, 6)}-${compact.substring(6, 8)}';
    }
    if (compact.length == 6) {
      final currentYearTwoDigits = DateTime.now().year % 100;
      final yy = int.tryParse(compact.substring(0, 2));
      if (yy == null) return text;
      final year = yy <= currentYearTwoDigits ? 2000 + yy : 1900 + yy;
      return '$year-${compact.substring(2, 4)}-${compact.substring(4, 6)}';
    }

    return text.replaceAll(RegExp(r'[./]'), '-');
  }
}
