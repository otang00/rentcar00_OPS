import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rentcar00_ops/features/fines/domain/fine_notice_models.dart';
import 'package:share_plus/share_plus.dart';

class FineNoticeDocumentClient {
  FineNoticeDocumentClient({required this.baseUrl, HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  Future<List<FineNoticeFileMetadata>> generateDocuments({
    required String fineNoticeId,
  }) async {
    final json = await _postJson('/fine-notices/generate-documents', {
      'fineNoticeId': fineNoticeId,
    }, timeout: const Duration(seconds: 180));
    final files = json['files'];
    if (files is! List) {
      throw const FineNoticeDocumentException('문서생성 응답에 파일 목록이 없습니다.');
    }
    return [
      for (final file in files)
        if (file is Map)
          FineNoticeFileMetadata.fromParserJson(file.cast<String, dynamic>()),
    ];
  }

  Future<List<FineNoticeFileMetadata>> listPackageFiles({
    required String fineNoticeId,
  }) async {
    final uri = _uri('/fine-notice-file-packages', {
      'fineNoticeId': fineNoticeId,
    });
    final json = await _getJson(uri);
    final files = json['files'];
    if (files is! List) return const [];
    return [
      for (final file in files)
        if (file is Map)
          FineNoticeFileMetadata.fromParserJson(file.cast<String, dynamic>()),
    ];
  }

  Future<File> downloadFile(FineNoticeFileMetadata file) async {
    final fileId = file.id;
    if (fileId == null || fileId.trim().isEmpty) {
      throw const FineNoticeDocumentException('다운로드할 파일 ID가 없습니다.');
    }
    final uri = _uri('/fine-notice-files/download', {'fileId': fileId});
    final request = await _httpClient.getUrl(uri);
    final response = await request.close().timeout(
      const Duration(seconds: 120),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw FineNoticeDocumentException(
        _extractMessage(body) ?? '파일 다운로드에 실패했습니다. (${response.statusCode})',
      );
    }
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'fine_notice_packages'));
    await targetDir.create(recursive: true);
    final target = File(p.join(targetDir.path, _safeFileName(file)));
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<void> openDownloadedFile(FineNoticeFileMetadata file) async {
    final downloaded = await downloadFile(file);
    await OpenFilex.open(downloaded.path);
  }

  Future<void> sharePackageFiles(List<FineNoticeFileMetadata> files) async {
    final packageFiles = files.where((file) => file.isPackageDocument).toList()
      ..sort(_comparePackageFiles);
    if (packageFiles.isEmpty) {
      throw const FineNoticeDocumentException('공유할 문서가 아직 없습니다.');
    }
    final downloaded = <XFile>[];
    for (final file in packageFiles) {
      final saved = await downloadFile(file);
      downloaded.add(
        XFile(
          saved.path,
          mimeType: file.mimeType,
          name: p.basename(saved.path),
        ),
      );
    }
    await SharePlus.instance.share(
      ShareParams(files: downloaded, text: '임차인 변경 신청 문서'),
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw const FineNoticeDocumentException('AI/IMS 파서 주소가 설정되지 않았습니다.');
    }
    final request = await _httpClient.postUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(
      timeout,
      onTimeout: () {
        request.abort();
        throw const FineNoticeDocumentException('문서 처리 시간이 초과되었습니다.');
      },
    );
    final bodyText = await utf8.decoder.bind(response).join();
    final json = bodyText.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(bodyText) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FineNoticeDocumentException(
        (json['message'] as String?)?.trim().isNotEmpty == true
            ? json['message'] as String
            : '문서 처리에 실패했습니다. (${response.statusCode})',
        missingFields: _extractMissingFields(json),
      );
    }
    return json;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    if (baseUrl.trim().isEmpty) {
      throw const FineNoticeDocumentException('AI/IMS 파서 주소가 설정되지 않았습니다.');
    }
    final request = await _httpClient.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await utf8.decoder.bind(response).join();
    final json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FineNoticeDocumentException(
        (json['message'] as String?)?.trim().isNotEmpty == true
            ? json['message'] as String
            : '파일 목록을 불러오지 못했습니다. (${response.statusCode})',
      );
    }
    return json;
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path',
    ).replace(queryParameters: query);
  }

  static String? _extractMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['message'] as String?)?.trim();
    } catch (_) {
      return body.trim().isEmpty ? null : body.trim();
    }
  }

  static List<String> _extractMissingFields(Map<String, dynamic> json) {
    final fields = json['missingFields'];
    if (fields is! List) return const [];
    return [
      for (final field in fields)
        if (field != null && field.toString().trim().isNotEmpty)
          field.toString().trim(),
    ];
  }

  static String _safeFileName(FineNoticeFileMetadata file) {
    final ext = _extensionFor(file);
    final base =
        '${file.displayName}_${file.id ?? file.sha256 ?? file.fileRole}'
            .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
            .replaceAll(RegExp(r'\s+'), '_');
    return base.endsWith(ext) ? base : '$base$ext';
  }

  static String _extensionFor(FineNoticeFileMetadata file) {
    final localExt = p.extension(file.localPath).toLowerCase();
    if (localExt.isNotEmpty && localExt.length <= 6) return localExt;
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.contains('jpeg') || mime.contains('jpg')) return '.jpg';
    if (mime.contains('png')) return '.png';
    return '.pdf';
  }

  static int _comparePackageFiles(
    FineNoticeFileMetadata a,
    FineNoticeFileMetadata b,
  ) {
    const order = {
      'renter_change_application': 1,
      'notice_original': 2,
      'contract_with_stamps': 3,
      'vehicle_application_list': 4,
    };
    return (order[a.fileRole] ?? 99).compareTo(order[b.fileRole] ?? 99);
  }
}

class FineNoticeDocumentException implements Exception {
  const FineNoticeDocumentException(
    this.message, {
    this.missingFields = const [],
  });

  final String message;
  final List<String> missingFields;

  @override
  String toString() => message;
}
