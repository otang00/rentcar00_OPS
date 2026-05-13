import 'dart:convert';
import 'dart:io';

class ReservationAiParserClient {
  ReservationAiParserClient({required this.baseUrl, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Future<bool> checkHealth() async {
    if (baseUrl.trim().isEmpty) return false;
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/health');
    final request = await _httpClient.getUrl(uri);
    final response = await request.close().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        request.abort();
        throw const ReservationAiParserException('AI파서 연결 확인 시간이 초과되었습니다.');
      },
    );
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;
    return json['ok'] == true;
  }

  Future<ReservationAiParseResult> parseText(String text) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const ReservationAiParserException('예약 원문을 입력해 주세요.');
    }
    if (baseUrl.trim().isEmpty) {
      throw const ReservationAiParserException('AI파서 주소가 설정되지 않았습니다.');
    }

    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/parse-reservation',
    );
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'text': normalizedText}));

    final response = await request.close().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        request.abort();
        throw const ReservationAiParserException('AI파서 응답 시간이 초과되었습니다.');
      },
    );
    final body = await utf8.decoder.bind(response).join();
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReservationAiParserException(
        (json['message'] as String?)?.trim().isNotEmpty == true
            ? json['message'] as String
            : 'AI파서 호출에 실패했습니다. (${response.statusCode})',
      );
    }

    return ReservationAiParseResult.fromJson(json);
  }
}

class ReservationAiParseResult {
  ReservationAiParseResult({
    required this.ok,
    required this.fields,
    required this.missing,
    required this.warnings,
  });

  final bool ok;
  final ReservationAiFields fields;
  final List<String> missing;
  final List<String> warnings;

  factory ReservationAiParseResult.fromJson(Map<String, dynamic> json) {
    return ReservationAiParseResult(
      ok: json['ok'] == true,
      fields: ReservationAiFields.fromJson(
        (json['fields'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      missing: ((json['missing'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }
}

class ReservationAiFields {
  ReservationAiFields({
    required this.reservationNumber,
    required this.customerName,
    required this.customerPhone,
    required this.birthDate,
    required this.referrer,
    required this.price,
    required this.carNumber,
    required this.carName,
    required this.pickupAt,
    required this.returnAt,
    required this.pickupLocation,
    required this.returnLocation,
    required this.note,
  });

  final String? reservationNumber;
  final String? customerName;
  final String? customerPhone;
  final String? birthDate;
  final String? referrer;
  final String? price;
  final String? carNumber;
  final String? carName;
  final String? pickupAt;
  final String? returnAt;
  final String? pickupLocation;
  final String? returnLocation;
  final String? note;

  factory ReservationAiFields.fromJson(Map<String, dynamic> json) {
    String? read(String key) {
      final value = json[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return ReservationAiFields(
      reservationNumber: read('reservationNumber'),
      customerName: read('customerName'),
      customerPhone: read('customerPhone'),
      birthDate: read('birthDate'),
      referrer: read('referrer'),
      price: read('price'),
      carNumber: read('carNumber'),
      carName: read('carName'),
      pickupAt: read('pickupAt'),
      returnAt: read('returnAt'),
      pickupLocation: read('pickupLocation'),
      returnLocation: read('returnLocation'),
      note: read('note'),
    );
  }
}

class ReservationAiParserException implements Exception {
  const ReservationAiParserException(this.message);

  final String message;

  @override
  String toString() => message;
}
