import 'package:rentcar00_ops/data/models/reservation_record.dart';

const int kImsMemoMaxLength = 120;

class ImsReservationPayload {
  const ImsReservationPayload({
    required this.rentalAt,
    required this.returnAt,
    required this.carNumber,
    required this.totalFee,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.useDelivery,
    required this.memo,
  });

  final String rentalAt;
  final String returnAt;
  final String carNumber;
  final String totalFee;
  final String customerName;
  final String customerPhone;
  final String address;
  final bool useDelivery;
  final String memo;

  Map<String, dynamic> toJson() {
    return {
      'rentalAt': rentalAt,
      'returnAt': returnAt,
      'carNumber': carNumber,
      'totalFee': totalFee,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'address': address,
      'useDelivery': useDelivery,
      'memo': memo,
    };
  }
}

class ImsReservationPayloadBuildResult {
  const ImsReservationPayloadBuildResult({
    required this.payload,
    required this.errors,
  });

  final ImsReservationPayload payload;
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

ImsReservationPayloadBuildResult buildImsReservationPayload(
  ReservationRecord reservation,
) {
  final payload = ImsReservationPayload(
    rentalAt: _formatImsDateTime(reservation.startAt),
    returnAt: _formatImsDateTime(reservation.endAt),
    carNumber: reservation.carNumber.trim(),
    totalFee: _digitsOnly(reservation.paymentAmount),
    customerName: reservation.customerName.trim(),
    customerPhone: _digitsOnly(reservation.customerPhone),
    address: _primaryAddress(reservation),
    useDelivery: true,
    memo: buildImsReservationMemo(reservation),
  );

  return ImsReservationPayloadBuildResult(
    payload: payload,
    errors: validateImsReservationPayload(payload, reservation),
  );
}

List<String> validateImsReservationPayload(
  ImsReservationPayload payload,
  ReservationRecord reservation,
) {
  final errors = <String>[];

  if (payload.rentalAt.isEmpty) errors.add('pickupAt_missing');
  if (payload.returnAt.isEmpty) errors.add('returnAt_missing');
  if (payload.carNumber.isEmpty) errors.add('carNumber_missing');
  if (payload.totalFee.isEmpty) errors.add('totalFee_missing');
  if (payload.customerName.isEmpty) errors.add('customerName_missing');
  if (payload.customerPhone.isEmpty) errors.add('customerPhone_missing');
  if (payload.address.isEmpty) errors.add('pickupLocation_missing');
  if (!_isBirthDateFormatted(reservation.customerBirthDate)) {
    errors.add('customerBirthDate_invalid');
  }
  if (!reservation.endAt.isAfter(reservation.startAt)) {
    errors.add('invalid_datetime_window');
  }
  if (payload.memo.length > kImsMemoMaxLength) {
    errors.add('memo_too_long');
  }

  return errors;
}

String buildImsReservationMemo(ReservationRecord reservation) {
  final parts = <String>[
    if (reservation.reservationNumber.trim().isNotEmpty)
      '예약:${reservation.reservationNumber.trim()}',
    if (_isBirthDateFormatted(reservation.customerBirthDate))
      '생년:${reservation.customerBirthDate.trim()}',
  ];

  final sourceNote = reservation.noteText.trim();
  if (sourceNote.isNotEmpty) {
    parts.add(sourceNote.replaceAll(RegExp(r'\s+'), ' '));
  }

  final memo = parts.join(' | ').trim();
  if (memo.length <= kImsMemoMaxLength) return memo;
  return memo.substring(0, kImsMemoMaxLength);
}

String _primaryAddress(ReservationRecord reservation) {
  final summary = reservation.locationSummary.trim();
  if (summary.isNotEmpty) return summary;
  return '';
}

String _formatImsDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D+'), '');

bool _isBirthDateFormatted(String value) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim());
}
