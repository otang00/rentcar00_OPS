import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:rentcar00_ops/shared/constants/tab_keys.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/normalize_raw_to_projection.dart <db-password> [db-url] [sync-run-id]',
    );
    exitCode = 64;
    return;
  }

  final dbPassword = args[0];
  final dbUrl = args.length > 1
      ? args[1]
      : File('supabase/.temp/pooler-url').readAsStringSync().trim();
  final syncRunId = args.length > 2 ? args[2] : null;
  final fullDbUrl = dbUrl.contains('password=')
      ? dbUrl
      : '$dbUrl?sslmode=require&password=${Uri.encodeComponent(dbPassword)}';

  final conn = await Connection.openFromUrl(fullDbUrl);

  try {
    final targetSyncRunId = syncRunId ?? await _latestSyncRunId(conn);

    await conn.runTx((tx) async {
      await tx.execute('delete from public.rc00_ops_outbox');
      await tx.execute('delete from public.rc00_ops_action_logs');
      await tx.execute('delete from public.rc00_ops_reservation_states');
      await tx.execute('delete from public.rc00_ops_reservations');
    });

    final rawRows = await conn.execute(
      Sql.named('''
        select
          id::text as id,
          reservation_id,
          reservation_number,
          car_number,
          car_name,
          start_at_raw,
          end_at_raw,
          location_raw,
          customer_name,
          customer_phone,
          status_raw,
          payload_json::text as payload_json
        from public.rc00_ops_sheet_reservations_raw
        where sync_run_id = @sync_run_id::uuid
        order by sheet_row_number asc
      '''),
      parameters: {'sync_run_id': targetSyncRunId},
    );

    var reservationCount = 0;
    var stateCount = 0;

    for (final row in rawRows) {
      final mapped = row.toColumnMap();
      final reservationId = (mapped['reservation_id'] as String?)?.trim() ?? '';
      if (reservationId.isEmpty) {
        continue;
      }

      final reservationNumber =
          (mapped['reservation_number'] as String?)?.trim() ?? '';
      final carNumber = (mapped['car_number'] as String?)?.trim() ?? '';
      final carName = (mapped['car_name'] as String?)?.trim() ?? '';
      final customerName = (mapped['customer_name'] as String?)?.trim() ?? '';
      final customerPhone = (mapped['customer_phone'] as String?)?.trim() ?? '';
      final locationRaw = (mapped['location_raw'] as String?)?.trim() ?? '';
      final statusRaw = (mapped['status_raw'] as String?)?.trim() ?? '';
      final startAt = _parseDateTime(
        (mapped['start_at_raw'] as String?)?.trim(),
      );
      final endAt = _parseDateTime((mapped['end_at_raw'] as String?)?.trim());
      final metaJson = (mapped['payload_json'] as String?) ?? '{}';

      final reservationResult = await conn.execute(
        Sql.named('''
          insert into public.rc00_ops_reservations (
            reservation_id,
            reservation_number,
            car_number,
            car_name,
            customer_name,
            customer_phone,
            start_at,
            end_at,
            pickup_location,
            status_raw,
            source_sync_run_id,
            source_reservation_raw_id,
            last_synced_at,
            meta_json,
            updated_at
          ) values (
            @reservation_id,
            @reservation_number,
            @car_number,
            @car_name,
            @customer_name,
            @customer_phone,
            @start_at,
            @end_at,
            @pickup_location,
            @status_raw,
            @source_sync_run_id::uuid,
            @source_reservation_raw_id::uuid,
            now(),
            @meta_json::jsonb,
            now()
          )
          returning id::text
        '''),
        parameters: {
          'reservation_id': reservationId,
          'reservation_number': reservationNumber,
          'car_number': carNumber,
          'car_name': carName,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'start_at': startAt,
          'end_at': endAt,
          'pickup_location': locationRaw,
          'status_raw': statusRaw,
          'source_sync_run_id': targetSyncRunId,
          'source_reservation_raw_id': mapped['id'],
          'meta_json': metaJson,
        },
      );

      reservationCount++;
      final state = _deriveState(
        statusRaw: statusRaw,
        startAt: startAt,
        endAt: endAt,
        customerName: customerName,
        customerPhone: customerPhone,
        locationRaw: locationRaw,
      );

      if (!state.includeInTabs) {
        continue;
      }

      final reservationRefId = reservationResult.first[0] as String;
      await conn.execute(
        Sql.named('''
          insert into public.rc00_ops_reservation_states (
            reservation_id,
            reservation_ref_id,
            tab_key,
            needs_attention,
            warning_level,
            check_payload_json,
            memo_text,
            completed_at,
            updated_at
          ) values (
            @reservation_id,
            @reservation_ref_id::uuid,
            @tab_key,
            @needs_attention,
            @warning_level,
            @check_payload_json::jsonb,
            @memo_text,
            @completed_at,
            now()
          )
        '''),
        parameters: {
          'reservation_id': reservationId,
          'reservation_ref_id': reservationRefId,
          'tab_key': state.tabKey,
          'needs_attention': state.needsAttention,
          'warning_level': state.warningLevel,
          'check_payload_json': jsonEncode(state.checkPayload),
          'memo_text': state.memoText,
          'completed_at': state.completedAt,
        },
      );
      stateCount++;
    }

    stdout.writeln('normalized_sync_run_id=$targetSyncRunId');
    stdout.writeln('reservation_projection_count=$reservationCount');
    stdout.writeln('state_upsert_count=$stateCount');
  } finally {
    await conn.close();
  }
}

Future<String> _latestSyncRunId(Connection conn) async {
  final result = await conn.execute('''
    select id::text
    from public.rc00_ops_sheet_sync_runs
    order by started_at desc
    limit 1
  ''');

  if (result.isEmpty) {
    throw StateError('No sync run found. Run raw import first.');
  }

  return result.first[0] as String;
}

DateTime? _parseDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final normalized = raw.replaceAll(' ', ' ').trim();
  final direct = DateTime.tryParse(normalized);
  if (direct != null) return direct;

  final slashMatch = RegExp(
    r'^(\d{4})/(\d{2})/(\d{2}),\s*(\d{1,2}):(\d{2})$',
  ).firstMatch(normalized);
  if (slashMatch != null) {
    return DateTime(
      int.parse(slashMatch.group(1)!),
      int.parse(slashMatch.group(2)!),
      int.parse(slashMatch.group(3)!),
      int.parse(slashMatch.group(4)!),
      int.parse(slashMatch.group(5)!),
    );
  }

  return null;
}

_NormalizedState _deriveState({
  required String statusRaw,
  required DateTime? startAt,
  required DateTime? endAt,
  required String customerName,
  required String customerPhone,
  required String locationRaw,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDay = startAt == null
      ? null
      : DateTime(startAt.year, startAt.month, startAt.day);
  final endDay = endAt == null
      ? null
      : DateTime(endAt.year, endAt.month, endAt.day);

  final missingCustomer = customerName.isEmpty;
  final missingPhone = customerPhone.isEmpty;
  final missingLocation = locationRaw.isEmpty;
  final isPending = statusRaw == '예약중';
  final isCanceled = statusRaw == '예약취소';
  final isInUse = statusRaw == '배차중';
  final isCompleted = statusRaw == '반납완료';
  final isPickupToday = startDay != null && startDay == today;
  final isReturnToday = endDay != null && endDay == today;

  final checkPayload = <String, String>{
    'customer_name_verified': missingCustomer ? 'pending' : 'done',
    'customer_phone_verified': missingPhone ? 'pending' : 'done',
    'pickup_location_verified': missingLocation ? 'pending' : 'done',
    'status_raw': statusRaw,
  };

  if (isCanceled) {
    return _NormalizedState(
      includeInTabs: false,
      tabKey: null,
      needsAttention: false,
      warningLevel: null,
      checkPayload: checkPayload,
      memoText: '예약취소 건은 기본 탭에서 제외',
      completedAt: null,
    );
  }

  if (isCompleted) {
    return _NormalizedState(
      includeInTabs: true,
      tabKey: TabKeys.completed,
      needsAttention: false,
      warningLevel: null,
      checkPayload: checkPayload,
      memoText: '원본 상태가 반납완료로 확인됨',
      completedAt: endAt,
    );
  }

  if (isInUse && isReturnToday) {
    return _NormalizedState(
      includeInTabs: true,
      tabKey: TabKeys.returnDue,
      needsAttention: missingLocation,
      warningLevel: missingLocation ? 'warning' : null,
      checkPayload: checkPayload,
      memoText: '배차중 상태에서 오늘 반납 대상',
      completedAt: null,
    );
  }

  if (isInUse) {
    return _NormalizedState(
      includeInTabs: true,
      tabKey: TabKeys.inUse,
      needsAttention: false,
      warningLevel: null,
      checkPayload: checkPayload,
      memoText: '원본 상태가 배차중으로 확인됨',
      completedAt: null,
    );
  }

  if (isPending && isPickupToday) {
    return _NormalizedState(
      includeInTabs: true,
      tabKey: TabKeys.pickupToday,
      needsAttention: missingCustomer || missingPhone || missingLocation,
      warningLevel: (missingCustomer || missingPhone || missingLocation)
          ? 'warning'
          : null,
      checkPayload: checkPayload,
      memoText: '예약중 상태에서 오늘 배차 대상',
      completedAt: null,
    );
  }

  return _NormalizedState(
    includeInTabs: true,
    tabKey: TabKeys.pending,
    needsAttention: missingCustomer || missingPhone,
    warningLevel: (missingCustomer || missingPhone) ? 'warning' : null,
    checkPayload: checkPayload,
    memoText: isPending ? '예약중 기본 분류' : '정의되지 않은 상태값은 예약중으로 임시 분류',
    completedAt: null,
  );
}

class _NormalizedState {
  const _NormalizedState({
    required this.includeInTabs,
    required this.tabKey,
    required this.needsAttention,
    required this.warningLevel,
    required this.checkPayload,
    required this.memoText,
    required this.completedAt,
  });

  final bool includeInTabs;
  final String? tabKey;
  final bool needsAttention;
  final String? warningLevel;
  final Map<String, String> checkPayload;
  final String memoText;
  final DateTime? completedAt;
}
