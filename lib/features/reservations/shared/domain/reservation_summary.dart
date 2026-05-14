import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';

class ReservationSummary {
  const ReservationSummary({
    required this.reservationId,
    required this.reservationNumber,
    required this.customerName,
    required this.customerPhone,
    required this.carNumber,
    required this.carName,
    required this.tab,
    required this.statusKey,
    required this.displayAt,
    required this.timeLabel,
    required this.locationSummary,
    required this.noteText,
    required this.primaryBadges,
  });

  final String reservationId;
  final String reservationNumber;
  final String customerName;
  final String customerPhone;
  final String carNumber;
  final String carName;
  final ReservationTab tab;
  final String statusKey;
  final DateTime displayAt;
  final String timeLabel;
  final String locationSummary;
  final String noteText;
  final List<String> primaryBadges;
}
