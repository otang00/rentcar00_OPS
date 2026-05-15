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
    required this.reservationId,
    this.dryRun = false,
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
  final String reservationId;
  final bool dryRun;

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
      'reservationId': reservationId,
      'dryRun': dryRun,
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
    reservationId: reservation.reservationId.trim(),
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

  if (!_isImsDateTimeFormatted(payload.rentalAt)) {
    errors.add('rentalAt_invalid');
  }
  if (!_isImsDateTimeFormatted(payload.returnAt)) {
    errors.add('returnAt_invalid');
  }
  if (payload.carNumber.isEmpty) errors.add('carNumber_missing');
  if (!_isPositiveDigits(payload.totalFee)) errors.add('totalFee_invalid');
  if (payload.customerName.isEmpty) errors.add('customerName_missing');
  if (!_isPhoneDigits(payload.customerPhone)) {
    errors.add('customerPhone_invalid');
  }
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
    if (reservation.reservationId.trim().isNotEmpty)
      'OPS:${reservation.reservationId.trim()}',
    if (reservation.reservationNumber.trim().isNotEmpty)
      '외부예약:${reservation.reservationNumber.trim()}',
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

String imsPayloadErrorLabel(String code) {
  return switch (code) {
    'rentalAt_invalid' => '배차일시는 YYYY-MM-DD HH:mm 형식이어야 합니다',
    'returnAt_invalid' => '반납일시는 YYYY-MM-DD HH:mm 형식이어야 합니다',
    'carNumber_missing' => '차량번호가 필요합니다',
    'totalFee_invalid' => '가격은 0보다 큰 숫자여야 합니다',
    'customerName_missing' => '고객명이 필요합니다',
    'customerPhone_invalid' => '고객번호는 숫자 10~11자리여야 합니다',
    'pickupLocation_missing' => '배차지가 필요합니다',
    'customerBirthDate_invalid' => '생년월일은 YYYY-MM-DD 형식의 실제 날짜여야 합니다',
    'invalid_datetime_window' => '반납일시는 배차일시 이후여야 합니다',
    'memo_too_long' => 'IMS 메모는 $kImsMemoMaxLength자 이하여야 합니다',
    _ => code,
  };
}

String _formatImsDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D+'), '');

bool _isPositiveDigits(String value) {
  final amount = int.tryParse(value);
  return amount != null && amount > 0;
}

bool _isPhoneDigits(String value) {
  return RegExp(r'^\d{10,11}$').hasMatch(value.trim());
}

bool _isImsDateTimeFormatted(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final parsed = DateTime(year, month, day, hour, minute);
  return parsed.year == year &&
      parsed.month == month &&
      parsed.day == day &&
      parsed.hour == hour &&
      parsed.minute == minute;
}

bool _isBirthDateFormatted(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}
