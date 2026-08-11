import 'dart:convert';
import 'dart:io';

import 'package:rentcar00_ops/shared/config/ops_parser_headers.dart';

import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';

class FineNoticeContractMatchingClient {
  FineNoticeContractMatchingClient({
    required this.baseUrl,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Future<List<FineNoticeContractCandidate>> searchCandidates({
    required String carNumber,
    required DateTime occurredDate,
  }) async {
    final items = await _postItems(
      path: '/ims/search-fine-notice-contracts',
      payload: {
        'carNumber': carNumber.trim(),
        'rentalDate': _formatDate(occurredDate),
      },
      timeoutMessage: 'IMS 과태료 계약검색 시간이 초과되었습니다.',
      failureMessage: 'IMS 과태료 계약검색에 실패했습니다.',
    );

    return items
        .map(FineNoticeContractCandidate.fromContractSearchJson)
        .where((item) => item.sourceId.trim().isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _postItems({
    required String path,
    required Map<String, dynamic> payload,
    required String timeoutMessage,
    required String failureMessage,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw const FineNoticeContractMatchingException(
        'AI/IMS 파서 주소가 설정되지 않았습니다.',
      );
    }

    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    applyOpsParserTokenHeader(request);
    request.write(jsonEncode(payload));

    final response = await request.close().timeout(
      const Duration(seconds: 180),
      onTimeout: () {
        request.abort();
        throw FineNoticeContractMatchingException(timeoutMessage);
      },
    );
    final body = await utf8.decoder.bind(response).join();
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FineNoticeContractMatchingException(
        (json['message'] as String?)?.trim().isNotEmpty == true
            ? json['message'] as String
            : '$failureMessage (${response.statusCode})',
      );
    }

    final result =
        (json['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ((result['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }
}

class FineNoticeContractMatchingException implements Exception {
  const FineNoticeContractMatchingException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
