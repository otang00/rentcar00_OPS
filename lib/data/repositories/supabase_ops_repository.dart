import 'dart:convert';

import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/data/models/sync_run_entry.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/shared/constants/status_keys.dart';
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

    return reservationsResponse.map<ReservationRecord>((row) {
      final reservationId = row['reservation_id'] as String;
      final state = stateByReservationId[reservationId];

      final tabKey = state?['tab_key'] as String? ?? TabKeys.pending;
      final statusKey = state?['status_key'] as String? ?? StatusKeys.pending;
      final checkPayload = _toStringMap(state?['check_payload_json']);
      final warningLevel = state?['warning_level'] as String?;
      final noteParts = <String>[
        if ((state?['memo_text'] as String?)?.isNotEmpty ?? false)
          state!['memo_text'] as String,
        if ((row['status_raw'] as String?)?.isNotEmpty ?? false)
          '원본상태: ${row['status_raw']}',
      ];

      return ReservationRecord(
        reservationId: reservationId,
        reservationNumber: (row['reservation_number'] as String?) ?? '',
        customerName: (row['customer_name'] as String?) ?? '',
        customerPhone: (row['customer_phone'] as String?) ?? '',
        carNumber: (row['car_number'] as String?) ?? '',
        tab: _tabFromKey(tabKey),
        statusKey: statusKey,
        startAt: _parseDateTime(row['start_at']) ?? DateTime(2000),
        endAt: _parseDateTime(row['end_at']) ?? DateTime(2000),
        locationSummary: (row['pickup_location'] as String?) ?? '',
        noteText: noteParts.join(' · '),
        primaryBadges: _deriveBadges(
          checkPayload: checkPayload,
          warningLevel: warningLevel,
          statusKey: statusKey,
          statusRaw: (row['status_raw'] as String?) ?? '',
        ),
        checkPayload: checkPayload,
        actionLogs: const [],
      );
    }).toList();
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
    required String statusKey,
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
    if (statusKey == StatusKeys.hold || statusRaw.contains('취소')) {
      badges.add('예약취소');
    }
    if (statusKey == StatusKeys.done) {
      badges.add('반납 완료');
    }
    if (statusKey == StatusKeys.readyForDispatch) {
      badges.add('오늘배차');
    }

    return badges.take(2).toList();
  }
}
