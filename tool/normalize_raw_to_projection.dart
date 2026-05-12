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
        from public.rc00_ops_reservations_raw
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
      final customerBirthDate =
          (mapped['customer_birth_date_raw'] as String?)?.trim() ?? '';
      final referralSource =
          (mapped['referral_source'] as String?)?.trim() ?? '';
      final paymentAmount =
          (mapped['payment_amount_raw'] as String?)?.trim() ?? '';
      final locationRaw = (mapped['location_raw'] as String?)?.trim() ?? '';
      final reservationStatus = (mapped['status_raw'] as String?)?.trim() ?? '';
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
            customer_birth_date,
            referral_source,
            payment_amount,
            start_at,
            end_at,
            pickup_location,
            reservation_status,
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
            @customer_birth_date,
            @referral_source,
            @payment_amount,
            @start_at,
            @end_at,
            @pickup_location,
            @reservation_status,
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
          'customer_birth_date': customerBirthDate,
          'referral_source': referralSource,
          'payment_amount': paymentAmount,
          'start_at': startAt,
          'end_at': endAt,
          'pickup_location': locationRaw,
          'reservation_status': reservationStatus,
          'meta_json': metaJson,
        },
      );

      reservationCount++;
      final state = _deriveState(
        statusRaw: reservationStatus,
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

    final carCount = await _refreshOpsCars(conn, targetSyncRunId);
    final scheduleCount = await _refreshOpsSchedules(conn, targetSyncRunId);

    stdout.writeln('normalized_sync_run_id=$targetSyncRunId');
    stdout.writeln('reservation_projection_count=$reservationCount');
    stdout.writeln('state_upsert_count=$stateCount');
    stdout.writeln('ops_car_upsert_count=$carCount');
    stdout.writeln('ops_schedule_upsert_count=$scheduleCount');
  } finally {
    await conn.close();
  }
}

Future<String> _latestSyncRunId(Connection conn) async {
  final result = await conn.execute('''
    select id::text
    from public.rc00_ops_import_runs
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

Future<int> _refreshOpsCars(Connection conn, String syncRunId) async {
  await conn.execute(
    'delete from public.rc00_ops_cars where source_car_raw_id is not null',
  );

  final result = await conn.execute(
    Sql.named('''
      insert into public.rc00_ops_cars (
        car_number,
        car_name,
        status,
        car_wash,
        interior_wash,
        start_at,
        end_at,
        customer_name,
        pickup_location,
        customer_phone,
        note_text,
        parking_location,
        car_registered_at,
        car_inspection_at,
        car_age_expiry_at,
        car_number_front,
        car_number_middle,
        car_number_rear,
        status_action,
        source_import_run_id,
        source_car_raw_id,
        payload_json,
        last_synced_at,
        updated_at
      )
      select
        raw.car_number,
        raw.car_name,
        raw.status,
        raw.car_wash,
        raw.interior_wash,
        raw.start_at,
        raw.end_at,
        raw.customer_name,
        raw.pickup_location,
        raw.customer_phone,
        raw.note_text,
        raw.parking_location,
        raw.car_registered_at,
        raw.car_inspection_at,
        raw.car_age_expiry_at,
        raw.car_number_front,
        raw.car_number_middle,
        raw.car_number_rear,
        raw.status_action,
        raw.sync_run_id,
        raw.id,
        raw.payload_json,
        now(),
        now()
      from public.rc00_ops_cars_raw raw
      where raw.sync_run_id = @sync_run_id::uuid
        and raw.car_number is not null
        and btrim(raw.car_number) <> ''
    '''),
    parameters: {'sync_run_id': syncRunId},
  );
  return result.affectedRows;
}

Future<int> _refreshOpsSchedules(Connection conn, String syncRunId) async {
  await conn.execute(
    'delete from public.rc00_ops_schedules where source_schedule_raw_id is not null',
  );

  final result = await conn.execute(
    Sql.named('''
      insert into public.rc00_ops_schedules (
        schedule_id,
        reservation_id,
        reservation_number,
        car_number,
        car_name,
        schedule_type_raw,
        schedule_at_raw,
        location_text,
        detail_text,
        partial_return_raw,
        schedule_done_raw,
        source_import_run_id,
        source_schedule_raw_id,
        payload_json,
        updated_at
      )
      select
        raw.schedule_id,
        raw.reservation_id,
        raw.reservation_number,
        raw.car_number,
        raw.car_name,
        raw.schedule_type_raw,
        raw.schedule_at_raw,
        raw.location_raw,
        raw.detail_text,
        raw.partial_return_raw,
        raw.schedule_done_raw,
        raw.sync_run_id,
        raw.id,
        raw.payload_json,
        now()
      from public.rc00_ops_schedules_raw raw
      where raw.sync_run_id = @sync_run_id::uuid
        and raw.schedule_type_raw in ('배차', '반납')
    '''),
    parameters: {'sync_run_id': syncRunId},
  );
  return result.affectedRows;
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
