import 'package:rentcar00_ops/shared/utils/ops_kst_datetime.dart';

class ExternalReservationLink {
  const ExternalReservationLink({
    required this.id,
    required this.reservationId,
    required this.provider,
    required this.externalStatus,
    required this.linkKey,
    required this.lastPayloadJson,
    required this.lastResultJson,
    this.reservationRefId = '',
    this.externalReservationId = '',
    this.externalDetailId = '',
    this.linkedAt,
    this.lastCheckedAt,
    this.deletedAt,
    this.errorText = '',
  });

  final String id;
  final String reservationId;
  final String reservationRefId;
  final String provider;
  final String externalReservationId;
  final String externalDetailId;
  final String externalStatus;
  final String linkKey;
  final Map<String, dynamic> lastPayloadJson;
  final Map<String, dynamic> lastResultJson;
  final DateTime? linkedAt;
  final DateTime? lastCheckedAt;
  final DateTime? deletedAt;
  final String errorText;

  bool get isLinked => externalStatus == 'linked' && deletedAt == null;
  bool get isFailed => externalStatus == 'failed';
  bool get isDeleted => externalStatus == 'deleted' || deletedAt != null;
  bool get isUnlinked => externalStatus == 'unlinked';
  bool get isActiveBinding => isLinked;

  factory ExternalReservationLink.fromRow(Map<String, dynamic> row) {
    return ExternalReservationLink(
      id: row['id']?.toString() ?? '',
      reservationId: row['reservation_id']?.toString() ?? '',
      reservationRefId: row['reservation_ref_id']?.toString() ?? '',
      provider: row['provider']?.toString() ?? 'ims',
      externalReservationId: row['external_reservation_id']?.toString() ?? '',
      externalDetailId: row['external_detail_id']?.toString() ?? '',
      externalStatus: row['external_status']?.toString() ?? 'failed',
      linkKey: row['link_key']?.toString() ?? '',
      lastPayloadJson: _jsonMap(row['last_payload_json']),
      lastResultJson: _jsonMap(row['last_result_json']),
      linkedAt: _parseDateTime(row['linked_at']),
      lastCheckedAt: _parseDateTime(row['last_checked_at']),
      deletedAt: _parseDateTime(row['deleted_at']),
      errorText: row['error_text']?.toString() ?? '',
    );
  }
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

DateTime? _parseDateTime(dynamic value) {
  return opsParseKstDateTime(value);
}
