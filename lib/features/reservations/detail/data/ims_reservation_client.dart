import 'dart:convert';
import 'dart:io';

import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_payload.dart';

class ImsReservationClient {
  ImsReservationClient({required this.baseUrl, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Future<ImsReservationExecutionResult> createReservation(
    ImsReservationPayload payload,
  ) async {
    if (baseUrl.trim().isEmpty) {
      throw const ImsReservationClientException('AI파서 주소가 설정되지 않았습니다.');
    }

    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/ims/create-reservation',
    );
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload.toJson()));

    final response = await request.close().timeout(
      const Duration(seconds: 360),
      onTimeout: () {
        request.abort();
        throw const ImsReservationClientException('IMS 예약추가 응답 시간이 초과되었습니다.');
      },
    );

    final body = await utf8.decoder.bind(response).join();
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (json['result'] as Map?)?['message']?.toString().trim();
      throw ImsReservationClientException(
        message != null && message.isNotEmpty
            ? message
            : 'IMS 예약추가 호출에 실패했습니다. (${response.statusCode})',
      );
    }

    return ImsReservationExecutionResult.fromJson(json);
  }
}

class ImsReservationExecutionResult {
  const ImsReservationExecutionResult({
    required this.ok,
    required this.code,
    required this.message,
    required this.externalStatus,
    required this.externalReservationId,
    required this.externalDetailId,
    required this.linkKey,
    required this.errorText,
    required this.resultJson,
  });

  final bool ok;
  final String code;
  final String message;
  final String externalStatus;
  final String externalReservationId;
  final String externalDetailId;
  final String linkKey;
  final String errorText;
  final Map<String, dynamic> resultJson;

  bool get isSuccess => ok && (code == 'SUCCESS' || code == 'DRY_RUN');
  bool get hasLinkedExternalId =>
      externalStatus == 'linked' && externalReservationId.isNotEmpty;

  factory ImsReservationExecutionResult.fromJson(Map<String, dynamic> json) {
    final result =
        (json['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ImsReservationExecutionResult(
      ok: json['ok'] == true,
      code: result['code']?.toString() ?? 'UNKNOWN',
      message: result['message']?.toString() ?? '',
      externalStatus: result['externalStatus']?.toString() ?? '',
      externalReservationId: result['externalReservationId']?.toString() ?? '',
      externalDetailId: result['externalDetailId']?.toString() ?? '',
      linkKey: result['linkKey']?.toString() ?? '',
      errorText: result['errorText']?.toString() ?? '',
      resultJson: result,
    );
  }
}

class ImsReservationClientException implements Exception {
  const ImsReservationClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
