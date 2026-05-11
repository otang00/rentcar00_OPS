import 'dart:convert';

import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/status_board_record.dart';
import 'package:rentcar00_ops/data/models/sync_run_entry.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';
import 'package:rentcar00_ops/shared/constants/tab_keys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOpsRepository {
  SupabaseOpsRepository(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

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
      final statusRaw = (row['status_raw'] as String?) ?? '';
      final checkPayload = _toStringMap(state['check_payload_json']);
      final warningLevel = state['warning_level'] as String?;
      final noteParts = <String>[
        if ((state['memo_text'] as String?)?.isNotEmpty ?? false)
          state['memo_text'] as String,
        if (statusRaw.isNotEmpty) '원본상태: $statusRaw',
      ];

      records.add(
        ReservationRecord(
          reservationId: reservationId,
          reservationNumber: (row['reservation_number'] as String?) ?? '',
          customerName: (row['customer_name'] as String?) ?? '',
          customerPhone: (row['customer_phone'] as String?) ?? '',
          carNumber: (row['car_number'] as String?) ?? '',
          carName: (row['car_name'] as String?) ?? '',
          tab: _tabFromKey(tabKey),
          statusKey: statusRaw,
          startAt: _parseDateTime(row['start_at']) ?? DateTime(2000),
          endAt: _parseDateTime(row['end_at']) ?? DateTime(2000),
          locationSummary: (row['pickup_location'] as String?) ?? '',
          noteText: noteParts.join(' · '),
          primaryBadges: _deriveBadges(
            checkPayload: checkPayload,
            warningLevel: warningLevel,
            tabKey: tabKey,
            statusRaw: statusRaw,
          ),
          checkPayload: checkPayload,
          actionLogs: const [],
        ),
      );
    }

    return records;
  }

  Future<List<SyncRunEntry>> fetchSyncRuns() async {
    final response = await _client
        .from('rc00_ops_sheet_sync_runs')
        .select()
        .order('started_at', ascending: false)
        .limit(20);

    return response.map<SyncRunEntry>((row) {
      final meta = _toMap(row['meta_json']);
      final counts = <String>[
        if (meta['car_row_count'] != null) '시트1 ${meta['car_row_count']}',
        if (meta['reservation_raw_count'] != null)
          '예약 raw ${meta['reservation_raw_count']}',
        if (meta['schedule_raw_count'] != null)
          '일정 raw ${meta['schedule_raw_count']}',
      ].join(' / ');

      return SyncRunEntry(
        id: row['id'] as String,
        title: 'Google Sheets raw import',
        status: (row['status'] as String?) ?? 'unknown',
        note: counts.isEmpty ? 'spreadsheet sync' : counts,
        executedAt:
            _parseDateTime(row['started_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    }).toList();
  }

  Future<List<StatusBoardRecord>> fetchStatusBoardRecords() async {
    final syncRun = await _client
        .from('rc00_ops_sheet_sync_runs')
        .select('id')
        .eq('status', 'success')
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final syncRunId = syncRun?['id'] as String?;
    if (syncRunId == null || syncRunId.isEmpty) {
      return const [];
    }

    final carsResponse = await _client
        .from('rc00_ops_sheet_cars')
        .select()
        .eq('sync_run_id', syncRunId)
        .order('sheet_row_number', ascending: true);

    final schedulesResponse = await _client
        .from('rc00_ops_sheet_schedules_raw')
        .select()
        .eq('sync_run_id', syncRunId)
        .inFilter('schedule_type_raw', ['배차', '반납'])
        .order('sheet_row_number', ascending: true);

    final cars = carsResponse.map<StatusBoardRecord>(_toCarRecord).toList();
    final carByNumber = {
      for (final car in cars)
        if (car.carNumber.isNotEmpty) car.carNumber: car,
    };

    final schedules =
        schedulesResponse
            .where((row) => !_isTruthy(row['schedule_done_raw']))
            .map<StatusBoardRecord>(
              (row) => _toScheduleRecord(row, carByNumber),
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
      '대기' => StatusBoardTab.idle,
      '보험' => StatusBoardTab.insurance,
      '일반' => StatusBoardTab.general,
      '장기' => StatusBoardTab.longTerm,
      _ => StatusBoardTab.general,
    };
    final carWash = (row['car_wash'] as String? ?? '').trim();
    final interiorWash = (row['interior_wash'] as String? ?? '').trim();
    final noteText = (row['note_text'] as String? ?? '').trim();
    final statusAction = (row['status_action'] as String? ?? '').trim();

    return StatusBoardRecord(
      recordId: 'car:${row['id']}',
      tab: tab,
      sourceKind: 'car',
      carNumber: (row['car_number'] as String? ?? '').trim(),
      carName: (row['car_name'] as String? ?? '').trim(),
      status: status,
      customerName: (row['customer_name'] as String? ?? '').trim(),
      customerPhone: (row['customer_phone'] as String? ?? '').trim(),
      startAt: (row['start_at'] as String? ?? '').trim(),
      endAt: (row['end_at'] as String? ?? '').trim(),
      pickupLocation: (row['pickup_location'] as String? ?? '').trim(),
      parkingLocation: (row['parking_location'] as String? ?? '').trim(),
      noteText: noteText,
      statusAction: statusAction,
      carWash: carWash,
      interiorWash: interiorWash,
      timeLabel: _formatBoardPeriod(
        (row['start_at'] as String? ?? '').trim(),
        (row['end_at'] as String? ?? '').trim(),
      ),
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
          _parseFlexibleDateTime((row['end_at'] as String? ?? '').trim()) ??
          _parseFlexibleDateTime((row['start_at'] as String? ?? '').trim()),
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
  ) {
    final carNumber = (row['car_number'] as String? ?? '').trim();
    final linkedCar = carByNumber[carNumber];
    final scheduleType = (row['schedule_type_raw'] as String? ?? '').trim();
    final scheduleAtRaw = (row['schedule_at_raw'] as String? ?? '').trim();

    return StatusBoardRecord(
      recordId: 'schedule:${row['id']}',
      tab: StatusBoardTab.schedule,
      sourceKind: 'schedule',
      carNumber: carNumber,
      carName: (row['car_name'] as String? ?? '').trim().isNotEmpty
          ? (row['car_name'] as String).trim()
          : (linkedCar?.carName ?? ''),
      status: linkedCar?.status ?? scheduleType,
      customerName: linkedCar?.customerName ?? '',
      customerPhone: linkedCar?.customerPhone ?? '',
      startAt: scheduleAtRaw,
      endAt: '',
      pickupLocation: (row['location_raw'] as String? ?? '').trim(),
      parkingLocation: linkedCar?.parkingLocation ?? '',
      noteText: linkedCar?.noteText ?? '',
      statusAction: scheduleType,
      carWash: linkedCar?.carWash ?? '',
      interiorWash: linkedCar?.interiorWash ?? '',
      timeLabel: _formatScheduleLabel(scheduleAtRaw),
      locationSummary: (row['location_raw'] as String? ?? '').trim(),
      primaryBadges: [scheduleType],
      sortAt: _parseFlexibleDateTime(scheduleAtRaw),
      scheduleId: (row['schedule_id'] as String? ?? '').trim(),
      scheduleType: scheduleType,
      scheduleDone: (row['schedule_done_raw'] as String? ?? '').trim(),
      detailText: (row['detail_text'] as String? ?? '').trim(),
      reservationId: (row['reservation_id'] as String? ?? '').trim(),
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

  String _formatScheduleLabel(String value) {
    final parsed = _parseFlexibleDateTime(value);
    if (parsed == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[parsed.weekday - 1];
    return '${two(parsed.month)}/${two(parsed.day)}($weekday) ${two(parsed.hour)}:${two(parsed.minute)}';
  }

  String _joinNonEmpty(List<String> values, {String separator = ' · '}) {
    return values.where((value) => value.isNotEmpty).join(separator);
  }
}
