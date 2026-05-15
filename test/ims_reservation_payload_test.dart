import 'package:flutter_test/flutter_test.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/features/reservations/detail/data/ims_reservation_payload.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';

void main() {
  test('valid IMS reservation payload has no errors', () {
    final result = buildImsReservationPayload(_reservation());

    expect(result.errors, isEmpty);
    expect(
      result.payload.toJson(),
      containsPair('rentalAt', '2026-05-21 09:00'),
    );
    expect(
      result.payload.toJson(),
      containsPair('returnAt', '2026-05-22 09:00'),
    );
    expect(result.payload.toJson(), containsPair('totalFee', '80000'));
    expect(
      result.payload.toJson(),
      containsPair('customerPhone', '01012345678'),
    );
    expect(result.payload.toJson(), containsPair('reservationId', 'draft'));
    expect(result.payload.memo, contains('OPS:draft'));
  });

  test('invalid IMS fields are blocked before create', () {
    final result = buildImsReservationPayload(
      _reservation(
        customerPhone: '123',
        customerBirthDate: '2026-02-31',
        paymentAmount: '0',
        endAt: DateTime(2026, 5, 21, 9),
      ),
    );

    expect(result.errors, contains('customerPhone_invalid'));
    expect(result.errors, contains('customerBirthDate_invalid'));
    expect(result.errors, contains('totalFee_invalid'));
    expect(result.errors, contains('invalid_datetime_window'));
  });
}

ReservationRecord _reservation({
  String customerPhone = '010-1234-5678',
  String customerBirthDate = '1990-01-31',
  String paymentAmount = '80,000',
  DateTime? endAt,
}) {
  return ReservationRecord(
    reservationId: 'draft',
    reservationNumber: 'R-001',
    customerName: '홍길동',
    customerPhone: customerPhone,
    customerBirthDate: customerBirthDate,
    referralSource: '전화',
    paymentAmount: paymentAmount,
    carNumber: '123허4567',
    carName: 'K5',
    tab: ReservationTab.pending,
    statusKey: '예약중',
    startAt: DateTime(2026, 5, 21, 9),
    endAt: endAt ?? DateTime(2026, 5, 22, 9),
    locationSummary: '김포공항',
    noteText: '',
    primaryBadges: const [],
    checkPayload: const {},
    actionLogs: const [],
  );
}
