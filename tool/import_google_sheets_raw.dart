import 'dart:convert';
import 'dart:io';

import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:postgres/postgres.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart run tool/import_google_sheets_raw.dart <service-account.json> <spreadsheet-id> <db-password> [db-url]',
    );
    exitCode = 64;
    return;
  }

  final credentialPath = args[0];
  final spreadsheetId = args[1];
  final dbPassword = args[2];
  final dbUrl = args.length > 3
      ? args[3]
      : File('supabase/.temp/pooler-url').readAsStringSync().trim();

  final credentials = ServiceAccountCredentials.fromJson(
    jsonDecode(await File(credentialPath).readAsString())
        as Map<String, dynamic>,
  );

  final authClient = await clientViaServiceAccount(credentials, const [
    SheetsApi.spreadsheetsReadonlyScope,
  ]);

  Connection? conn;
  String? syncRunId;

  try {
    final sheetsApi = SheetsApi(authClient);
    final carRows = await _readSheet(sheetsApi, spreadsheetId, '시트1!A1:Z');
    final reservationRows = await _readSheet(
      sheetsApi,
      spreadsheetId,
      '예약!A1:Z',
    );
    final scheduleRows = await _readSheet(sheetsApi, spreadsheetId, '일정!A1:Z');

    final fullDbUrl = dbUrl.contains('password=')
        ? dbUrl
        : '$dbUrl?sslmode=require&password=${Uri.encodeComponent(dbPassword)}';

    conn = await Connection.openFromUrl(fullDbUrl);

    syncRunId = await _createSyncRun(conn, spreadsheetId);

    final carCount = await _insertCarRows(conn, syncRunId, carRows);

    final reservationCount = await _insertReservationRows(
      conn,
      syncRunId,
      reservationRows,
    );
    final scheduleCount = await _insertScheduleRows(
      conn,
      syncRunId,
      scheduleRows,
    );

    await conn.execute(
      Sql.named('''
        update public.rc00_ops_import_runs
        set status = @status,
            finished_at = now(),
            meta_json = @meta::jsonb
        where id = @id
      '''),
      parameters: {
        'status': 'success',
        'meta': jsonEncode({
          'spreadsheet_id': spreadsheetId,
          'car_row_count': carCount,
          'reservation_raw_count': reservationCount,
          'schedule_raw_count': scheduleCount,
        }),
        'id': syncRunId,
      },
    );

    stdout.writeln('sync_run_id=$syncRunId');
    stdout.writeln('car_row_count=$carCount');
    stdout.writeln('reservation_raw_count=$reservationCount');
    stdout.writeln('schedule_raw_count=$scheduleCount');
  } catch (error) {
    if (conn != null && syncRunId != null) {
      await conn.execute(
        Sql.named('''
          update public.rc00_ops_import_runs
          set status = @status,
              finished_at = now(),
              error_text = @error_text
          where id = @id
        '''),
        parameters: {
          'status': 'failed',
          'error_text': error.toString(),
          'id': syncRunId,
        },
      );
    }
    stderr.writeln(error);
    rethrow;
  } finally {
    await conn?.close();
    authClient.close();
  }
}

Future<int> _insertCarRows(
  Connection conn,
  String syncRunId,
  List<List<String>> rows,
) async {
  if (rows.isEmpty) return 0;
  final headers = rows.first;
  var inserted = 0;

  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    final mapped = _mapRow(headers, row);
    if (_isBlankRow(mapped)) continue;

    await conn.execute(
      Sql.named('''
        insert into public.rc00_ops_cars_raw (
          sync_run_id,
          sheet_row_number,
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
          payload_json
        ) values (
          @sync_run_id::uuid,
          @sheet_row_number,
          @car_number,
          @car_name,
          @status,
          @car_wash,
          @interior_wash,
          @start_at,
          @end_at,
          @customer_name,
          @pickup_location,
          @customer_phone,
          @note_text,
          @parking_location,
          @car_registered_at,
          @car_inspection_at,
          @car_age_expiry_at,
          @car_number_front,
          @car_number_middle,
          @car_number_rear,
          @status_action,
          @payload_json::jsonb
        )
      '''),
      parameters: {
        'sync_run_id': syncRunId,
        'sheet_row_number': index + 1,
        'car_number': mapped['차량번호'],
        'car_name': mapped['차종'],
        'status': mapped['상태'],
        'car_wash': mapped['세차'],
        'interior_wash': mapped['실내세차'],
        'start_at': mapped['대여일'],
        'end_at': mapped['반납일'],
        'customer_name': mapped['임차인'],
        'pickup_location': mapped['배차지'],
        'customer_phone': mapped['고객번호'],
        'note_text': (mapped['비      고'] ?? '').isNotEmpty
            ? mapped['비      고']
            : mapped['비고'],
        'parking_location': mapped['주차지'],
        'car_registered_at': mapped['차량등록일'],
        'car_inspection_at': mapped['차량검사일'],
        'car_age_expiry_at': mapped['차령만료일'],
        'car_number_front': mapped['차량번호(앞)'],
        'car_number_middle': mapped['차량번호(중)'],
        'car_number_rear': mapped['차량번호(네자리)'],
        'status_action': mapped['상태액션'],
        'payload_json': jsonEncode(mapped),
      },
    );
    inserted++;
  }

  return inserted;
}

Future<List<List<String>>> _readSheet(
  SheetsApi api,
  String spreadsheetId,
  String range,
) async {
  final response = await api.spreadsheets.values.get(spreadsheetId, range);
  final values = response.values ?? const <List<Object?>>[];
  return values
      .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
      .toList();
}

Future<String> _createSyncRun(Connection conn, String spreadsheetId) async {
  final result = await conn.execute(
    Sql.named('''
      insert into public.rc00_ops_import_runs (
        source_type,
        status,
        meta_json
      ) values (
        @source_type,
        @status,
        @meta::jsonb
      )
      returning id::text
    '''),
    parameters: {
      'source_type': 'google_sheets',
      'status': 'running',
      'meta': jsonEncode({'spreadsheet_id': spreadsheetId}),
    },
  );

  return result.first[0] as String;
}

Future<int> _insertReservationRows(
  Connection conn,
  String syncRunId,
  List<List<String>> rows,
) async {
  if (rows.isEmpty) return 0;
  final headers = rows.first;
  var inserted = 0;

  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    final mapped = _mapRow(headers, row);
    if (_isBlankRow(mapped)) continue;

    await conn.execute(
      Sql.named('''
        insert into public.rc00_ops_reservations_raw (
          sync_run_id,
          sheet_row_number,
          reservation_id,
          reservation_number,
          car_number,
          car_name,
          start_at_raw,
          end_at_raw,
          location_raw,
          customer_name,
          customer_phone,
          customer_birth_date_raw,
          referral_source,
          payment_amount_raw,
          status_raw,
          payload_json
        ) values (
          @sync_run_id::uuid,
          @sheet_row_number,
          @reservation_id,
          @reservation_number,
          @car_number,
          @car_name,
          @start_at_raw,
          @end_at_raw,
          @location_raw,
          @customer_name,
          @customer_phone,
          @customer_birth_date_raw,
          @referral_source,
          @payment_amount_raw,
          @status_raw,
          @payload_json::jsonb
        )
      '''),
      parameters: {
        'sync_run_id': syncRunId,
        'sheet_row_number': index + 1,
        'reservation_id': mapped['예약ID'],
        'reservation_number': mapped['예약번호'],
        'car_number': mapped['차량번호'],
        'car_name': mapped['차종'],
        'start_at_raw': mapped['대여일'],
        'end_at_raw': mapped['반납일'],
        'location_raw': mapped['배반차위치'],
        'customer_name': mapped['임차인'],
        'customer_phone': mapped['고객번호'],
        'customer_birth_date_raw': mapped['생년월일'],
        'referral_source': mapped['소개처'],
        'payment_amount_raw': mapped['결제금액'],
        'status_raw': mapped['예약상태'],
        'payload_json': jsonEncode(mapped),
      },
    );
    inserted++;
  }

  return inserted;
}

Future<int> _insertScheduleRows(
  Connection conn,
  String syncRunId,
  List<List<String>> rows,
) async {
  if (rows.isEmpty) return 0;
  final headers = rows.first;
  var inserted = 0;

  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    final mapped = _mapRow(headers, row);
    if (_isBlankRow(mapped)) continue;

    await conn.execute(
      Sql.named('''
        insert into public.rc00_ops_schedules_raw (
          sync_run_id,
          sheet_row_number,
          schedule_id,
          reservation_id,
          reservation_number,
          car_number,
          car_name,
          schedule_type_raw,
          schedule_at_raw,
          location_raw,
          detail_text,
          partial_return_raw,
          schedule_done_raw,
          payload_json
        ) values (
          @sync_run_id::uuid,
          @sheet_row_number,
          @schedule_id,
          @reservation_id,
          @reservation_number,
          @car_number,
          @car_name,
          @schedule_type_raw,
          @schedule_at_raw,
          @location_raw,
          @detail_text,
          @partial_return_raw,
          @schedule_done_raw,
          @payload_json::jsonb
        )
      '''),
      parameters: {
        'sync_run_id': syncRunId,
        'sheet_row_number': index + 1,
        'schedule_id': mapped['일정번호'],
        'reservation_id': mapped['예약ID'],
        'reservation_number': mapped['예약번호'],
        'car_number': mapped['차량번호'],
        'car_name': mapped['차종'],
        'schedule_type_raw': mapped['Status'],
        'schedule_at_raw': mapped['Date'],
        'location_raw': mapped['위치'],
        'detail_text': mapped['상세정보'],
        'partial_return_raw': mapped['가반납'],
        'schedule_done_raw': mapped['일정완료'],
        'payload_json': jsonEncode(mapped),
      },
    );
    inserted++;
  }

  return inserted;
}

Map<String, String> _mapRow(List<String> headers, List<String> row) {
  return {
    for (var i = 0; i < headers.length; i++)
      headers[i]: i < row.length ? row[i].trim() : '',
  };
}

bool _isBlankRow(Map<String, String> mapped) {
  return mapped.values.every((value) => value.trim().isEmpty);
}
