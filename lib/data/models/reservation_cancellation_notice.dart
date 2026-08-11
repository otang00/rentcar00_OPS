import 'package:rentcar00_ops/shared/utils/ops_kst_datetime.dart';

class ReservationCancellationNotice {
  const ReservationCancellationNotice({
    required this.id,
    required this.eventId,
    required this.provider,
    required this.sourceReservationId,
    required this.status,
    required this.receivedAt,
    this.bookingOrderId = '',
    this.reservationCode = '',
    this.sourceReservationNo = '',
    this.customerName = '',
    this.customerPhoneLast4 = '',
    this.carNumber = '',
    this.carName = '',
    this.pickupAt,
    this.returnAt,
    this.candidateReservationId = '',
    this.candidateReservationNumber = '',
    this.candidateStatus = '',
    this.candidateCount = 0,
  });

  final String id;
  final String eventId;
  final String bookingOrderId;
  final String reservationCode;
  final String provider;
  final String sourceReservationId;
  final String sourceReservationNo;
  final String customerName;
  final String customerPhoneLast4;
  final String carNumber;
  final String carName;
  final DateTime? pickupAt;
  final DateTime? returnAt;
  final DateTime receivedAt;
  final String status;
  final String candidateReservationId;
  final String candidateReservationNumber;
  final String candidateStatus;
  final int candidateCount;

  bool get hasCandidate => candidateReservationId.trim().isNotEmpty;

  ReservationCancellationNotice copyWithCandidate({
    required String reservationId,
    required String reservationNumber,
    required String status,
    required int count,
  }) {
    return ReservationCancellationNotice(
      id: id,
      eventId: eventId,
      bookingOrderId: bookingOrderId,
      reservationCode: reservationCode,
      provider: provider,
      sourceReservationId: sourceReservationId,
      sourceReservationNo: sourceReservationNo,
      customerName: customerName,
      customerPhoneLast4: customerPhoneLast4,
      carNumber: carNumber,
      carName: carName,
      pickupAt: pickupAt,
      returnAt: returnAt,
      receivedAt: receivedAt,
      status: this.status,
      candidateReservationId: reservationId,
      candidateReservationNumber: reservationNumber,
      candidateStatus: status,
      candidateCount: count,
    );
  }

  factory ReservationCancellationNotice.fromRow(Map<String, dynamic> row) {
    final payload = _jsonMap(row['payload_json']);
    final booking = _jsonMap(payload['booking']);
    final input = _jsonMap(payload['reservationInput']);
    final provider = _firstText(
      payload['provider'],
      booking['sourceProvider'],
      input['sourceProvider'],
    );
    final sourceReservationId = _firstText(
      booking['sourceReservationId'],
      booking['externalReservationId'],
      booking['external_reservation_id'],
      input['sourceReservationId'],
      input['externalReservationId'],
      input['external_reservation_id'],
    );
    final sourceReservationNo = _firstText(
      booking['sourceReservationNo'],
      booking['externalReservationNo'],
      booking['external_reservation_no'],
      input['sourceReservationNo'],
      input['externalReservationNo'],
      input['external_reservation_no'],
    );

    return ReservationCancellationNotice(
      id: row['id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      bookingOrderId: row['booking_order_id']?.toString() ?? '',
      reservationCode: row['reservation_code']?.toString() ?? '',
      provider: provider,
      sourceReservationId: sourceReservationId,
      sourceReservationNo: sourceReservationNo,
      customerName: _firstText(booking['customerName'], input['customerName']),
      customerPhoneLast4: _firstText(
        booking['customerPhoneLast4'],
        input['customerPhoneLast4'],
      ),
      carNumber: _firstText(booking['carNumber'], input['carNumber']),
      carName: _firstText(booking['carName'], input['carName']),
      pickupAt: opsParseKstDateTime(
        _firstText(booking['pickupAt'], input['pickupAt']),
      ),
      returnAt: opsParseKstDateTime(
        _firstText(booking['returnAt'], input['returnAt']),
      ),
      receivedAt:
          opsParseKstDateTime(row['received_at']) ??
          opsParseKstDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: row['status']?.toString() ?? '',
    );
  }
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

String _firstText(
  Object? first, [
  Object? second,
  Object? third,
  Object? fourth,
  Object? fifth,
  Object? sixth,
]) {
  for (final value in [first, second, third, fourth, fifth, sixth]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}
