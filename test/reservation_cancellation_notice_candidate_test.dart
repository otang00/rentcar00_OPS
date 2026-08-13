import 'package:flutter_test/flutter_test.dart';
import 'package:rentcar00_ops/data/models/reservation_cancellation_notice.dart';
import 'package:rentcar00_ops/data/models/reservation_record.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';
import 'package:rentcar00_ops/features/reservations/shared/providers/reservation_providers.dart';

void main() {
  test(
    'keeps orphan cancellation notices visible when no OPS reservation matches',
    () {
      final notice = _notice(sourceReservationId: 'CM-1');
      final attached = attachCancellationCandidate(
        notice: notice,
        reservations: [
          _reservation(reservationNumber: 'OTHER', carNumber: '99하9999'),
        ],
      );

      expect(attached, isNotNull);
      expect(attached!.hasCandidate, isFalse);
    },
  );

  test(
    'attaches active candidate and keeps the notice open for manual cancellation',
    () {
      final notice = _notice(sourceReservationId: 'CM-1');
      final attached = attachCancellationCandidate(
        notice: notice,
        reservations: [
          _reservation(
            reservationId: 'R-1',
            reservationNumber: 'CM-1',
            statusKey: '예약중',
          ),
        ],
      );

      expect(attached, isNotNull);
      expect(attached!.candidateReservationId, 'R-1');
      expect(attached.hasActiveCandidate, isTrue);
      expect(attached.hasCancelledCandidate, isFalse);
    },
  );

  test(
    'keeps all-cancelled candidates visible so the event can be confirmed closed',
    () {
      final notice = _notice(sourceReservationId: 'CM-1');
      final attached = attachCancellationCandidate(
        notice: notice,
        reservations: [
          _reservation(
            reservationId: 'R-1',
            reservationNumber: 'CM-1',
            statusKey: '예약취소',
          ),
        ],
      );

      expect(attached, isNotNull);
      expect(attached!.candidateReservationId, 'R-1');
      expect(attached.hasActiveCandidate, isFalse);
      expect(attached.hasCancelledCandidate, isTrue);
    },
  );
}

ReservationCancellationNotice _notice({required String sourceReservationId}) {
  return ReservationCancellationNotice(
    id: 'event-row-1',
    eventId: 'reservation.cancelled:carmore:$sourceReservationId',
    provider: 'carmore',
    sourceReservationId: sourceReservationId,
    status: 'pending_review',
    receivedAt: DateTime(2026, 8, 13, 10),
    customerName: '홍길동',
    customerPhoneLast4: '1234',
    carNumber: '12가3456',
    pickupAt: DateTime(2026, 8, 13, 10),
    returnAt: DateTime(2026, 8, 13, 18),
  );
}

ReservationRecord _reservation({
  String reservationId = 'R-OTHER',
  required String reservationNumber,
  String statusKey = '예약중',
  String carNumber = '12가3456',
}) {
  return ReservationRecord(
    reservationId: reservationId,
    reservationNumber: reservationNumber,
    customerName: '홍길동',
    customerPhone: '010-0000-1234',
    customerBirthDate: '',
    referralSource: '',
    paymentAmount: '',
    carNumber: carNumber,
    carName: 'K5',
    tab: ReservationTab.pending,
    statusKey: statusKey,
    startAt: DateTime(2026, 8, 13, 9),
    endAt: DateTime(2026, 8, 13, 19),
    locationSummary: '',
    dropoffLocation: '',
    rawNoteText: '',
    noteText: '',
    primaryBadges: const [],
    checkPayload: const {},
    actionLogs: const [],
  );
}
