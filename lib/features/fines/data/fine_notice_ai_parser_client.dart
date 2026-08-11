import 'dart:convert';
import 'dart:io';

import 'package:rentcar00_ops/shared/config/ops_parser_headers.dart';

import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';

class FineNoticeAiParserClient {
  FineNoticeAiParserClient({required this.baseUrl, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Future<bool> checkHealth() async {
    if (baseUrl.trim().isEmpty) return false;
    final uri = Uri.parse('${_normalizedBaseUrl()}/parse-fine-notice');
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    applyOpsParserTokenHeader(request);
    request.write(
      jsonEncode({
        'fixture': {
          'ok': true,
          'noticeProfile': 'health_check',
          'noticeType': 'health_check',
          'rawCandidate': {'carNumber': 'health-check'},
          'warnings': <String>[],
        },
      }),
    );
    final response = await request.close().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        request.abort();
        throw const FineNoticeAiParserException('AI파서 연결 확인 시간이 초과되었습니다.');
      },
    );
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final json = _decodeJsonObject(
      body,
      fallbackMessage: 'AI파서 연결 확인 응답을 해석하지 못했습니다.',
    );
    return json['ok'] == true;
  }

  Future<FineNoticeAiParseResult> parseImage({
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw const FineNoticeAiParserException('고지서 사진을 선택해 주세요.');
    }
    if (baseUrl.trim().isEmpty) {
      throw const FineNoticeAiParserException('AI파서 주소가 설정되지 않았습니다.');
    }

    final uri = Uri.parse('${_normalizedBaseUrl()}/parse-fine-notice');
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    applyOpsParserTokenHeader(request);
    request.write(
      jsonEncode({'imageBase64': base64Encode(bytes), 'mimeType': mimeType}),
    );

    final response = await request.close().timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        request.abort();
        throw const FineNoticeAiParserException('AI파서 응답 시간이 초과되었습니다.');
      },
    );
    final body = await utf8.decoder.bind(response).join();
    final json = _decodeJsonObject(
      body,
      fallbackMessage: 'AI파서 응답을 해석하지 못했습니다.',
      statusCode: response.statusCode,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FineNoticeAiParserException(
        (json['message'] as String?)?.trim().isNotEmpty == true
            ? json['message'] as String
            : 'AI파서 호출에 실패했습니다. (${response.statusCode})',
      );
    }

    return FineNoticeAiParseResult.fromJson(json);
  }

  String _normalizedBaseUrl() => baseUrl.replaceAll(RegExp(r'/+$'), '');
}

Map<String, dynamic> _decodeJsonObject(
  String body, {
  required String fallbackMessage,
  int? statusCode,
}) {
  if (body.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } on FormatException {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = compact.length > 80 ? compact.substring(0, 80) : compact;
    throw FineNoticeAiParserException(
      [
        fallbackMessage,
        if (statusCode != null) '상태코드 $statusCode',
        if (preview.isNotEmpty) preview,
      ].join('\n'),
    );
  }
  throw FineNoticeAiParserException(fallbackMessage);
}

class FineNoticeAiParseResult {
  const FineNoticeAiParseResult({
    required this.ok,
    required this.candidate,
    required this.warnings,
    required this.rawJson,
    this.file,
  });

  final bool ok;
  final FineNoticeCandidate candidate;
  final List<String> warnings;
  final Map<String, dynamic> rawJson;
  final FineNoticeFileMetadata? file;

  factory FineNoticeAiParseResult.fromJson(Map<String, dynamic> json) {
    return FineNoticeAiParseResult(
      ok: json['ok'] == true,
      candidate: FineNoticeCandidate.fromJson(json),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      rawJson: Map<String, dynamic>.from(json),
      file: json['file'] is Map
          ? FineNoticeFileMetadata.fromParserJson(
              (json['file'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class FineNoticeAiParserException implements Exception {
  const FineNoticeAiParserException(this.message);

  final String message;

  @override
  String toString() => message;
}
