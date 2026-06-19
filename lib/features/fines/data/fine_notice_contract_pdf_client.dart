import 'dart:convert';
import 'dart:io';

import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';

class FineNoticeContractPdfClient {
  FineNoticeContractPdfClient({required this.baseUrl, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Future<FineNoticeFileMetadata> saveContractPdf({
    required String fineNoticeId,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw const FineNoticeContractPdfException('AI/IMS 파서 주소가 설정되지 않았습니다.');
    }

    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/fine-notices/save-contract-pdf',
    );
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'fineNoticeId': fineNoticeId}));

    final response = await request.close().timeout(
      const Duration(seconds: 180),
      onTimeout: () {
        request.abort();
        throw const FineNoticeContractPdfException(
          'IMS 계약서 PDF 저장 시간이 초과되었습니다.',
        );
      },
    );
    final body = await utf8.decoder.bind(response).join();
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FineNoticeContractPdfException(
        (json['message'] as String?)?.trim().isNotEmpty == true
            ? json['message'] as String
            : 'IMS 계약서 PDF 저장에 실패했습니다. (${response.statusCode})',
      );
    }

    final file = (json['file'] as Map?)?.cast<String, dynamic>();
    if (file == null) {
      throw const FineNoticeContractPdfException('계약서 PDF 저장 응답에 파일 정보가 없습니다.');
    }
    return FineNoticeFileMetadata.fromParserJson(file);
  }
}

class FineNoticeContractPdfException implements Exception {
  const FineNoticeContractPdfException(this.message);

  final String message;

  @override
  String toString() => message;
}
