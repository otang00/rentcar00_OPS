import 'dart:convert';
import 'dart:io';

import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/inspect_google_sheets.dart <service-account.json> <spreadsheet-id> [sheet names...]',
    );
    exitCode = 64;
    return;
  }

  final credentialPath = args[0];
  final spreadsheetId = args[1];
  final targetSheets = args.length > 2 ? args.sublist(2) : const ['예약', '일정'];

  final credentialFile = File(credentialPath);
  if (!credentialFile.existsSync()) {
    stderr.writeln('Credential file not found: $credentialPath');
    exitCode = 66;
    return;
  }

  final credentialJson =
      jsonDecode(await credentialFile.readAsString()) as Map<String, dynamic>;
  final credentials = ServiceAccountCredentials.fromJson(credentialJson);

  final client = await clientViaServiceAccount(credentials, const [
    SheetsApi.spreadsheetsReadonlyScope,
  ]);

  try {
    final api = SheetsApi(client);
    final spreadsheet = await api.spreadsheets.get(spreadsheetId);

    final availableSheets =
        spreadsheet.sheets
            ?.map((sheet) => sheet.properties?.title)
            .whereType<String>()
            .toList() ??
        const <String>[];

    stdout.writeln(
      'Spreadsheet: ${spreadsheet.properties?.title ?? spreadsheetId}',
    );
    stdout.writeln('Available sheets: ${availableSheets.join(', ')}');
    stdout.writeln('---');

    for (final sheetName in targetSheets) {
      final range = '$sheetName!A1:Z30';
      final response = await api.spreadsheets.values.get(spreadsheetId, range);
      final rows = response.values ?? const <List<Object?>>[];

      stdout.writeln('Sheet: $sheetName');
      stdout.writeln('Row count (sample): ${rows.length}');

      if (rows.isEmpty) {
        stdout.writeln('Headers: []');
        stdout.writeln('Preview: []');
        stdout.writeln('---');
        continue;
      }

      final headers = rows.first.map((cell) => cell?.toString() ?? '').toList();
      stdout.writeln('Headers: ${jsonEncode(headers)}');

      final preview = rows.skip(1).take(5).map((row) {
        final cells = row.map((cell) => cell?.toString() ?? '').toList();
        return {
          for (var i = 0; i < headers.length; i++)
            headers[i]: i < cells.length ? cells[i] : '',
        };
      }).toList();

      stdout.writeln(const JsonEncoder.withIndent('  ').convert(preview));
      stdout.writeln('---');
    }
  } finally {
    client.close();
  }
}
