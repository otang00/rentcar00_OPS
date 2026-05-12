import 'package:rentcar00_ops/data/models/action_log_entry.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/reservation_tab.dart';

class ReservationRecord {
  const ReservationRecord({
    required this.reservationId,
    required this.reservationNumber,
    required this.customerName,
    required this.customerPhone,
    required this.customerBirthDate,
    required this.referralSource,
    required this.paymentAmount,
    required this.carNumber,
    required this.carName,
    required this.tab,
    required this.statusKey,
    required this.startAt,
    required this.endAt,
    required this.locationSummary,
    required this.noteText,
    required this.primaryBadges,
    required this.checkPayload,
    required this.actionLogs,
  });

  final String reservationId;
  final String reservationNumber;
  final String customerName;
  final String customerPhone;
  final String customerBirthDate;
  final String referralSource;
  final String paymentAmount;
  final String carNumber;
  final String carName;
  final ReservationTab tab;
  final String statusKey;
  final DateTime startAt;
  final DateTime endAt;
  final String locationSummary;
  final String noteText;
  final List<String> primaryBadges;
  final Map<String, String> checkPayload;
  final List<ActionLogEntry> actionLogs;

  ReservationRecord copyWith({
    String? reservationId,
    String? reservationNumber,
    String? customerName,
    String? customerPhone,
    String? customerBirthDate,
    String? referralSource,
    String? paymentAmount,
    String? carNumber,
    String? carName,
    ReservationTab? tab,
    String? statusKey,
    DateTime? startAt,
    DateTime? endAt,
    String? locationSummary,
    String? noteText,
    List<String>? primaryBadges,
    Map<String, String>? checkPayload,
    List<ActionLogEntry>? actionLogs,
  }) {
    return ReservationRecord(
      reservationId: reservationId ?? this.reservationId,
      reservationNumber: reservationNumber ?? this.reservationNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerBirthDate: customerBirthDate ?? this.customerBirthDate,
      referralSource: referralSource ?? this.referralSource,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      carNumber: carNumber ?? this.carNumber,
      carName: carName ?? this.carName,
      tab: tab ?? this.tab,
      statusKey: statusKey ?? this.statusKey,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      locationSummary: locationSummary ?? this.locationSummary,
      noteText: noteText ?? this.noteText,
      primaryBadges: primaryBadges ?? this.primaryBadges,
      checkPayload: checkPayload ?? this.checkPayload,
      actionLogs: actionLogs ?? this.actionLogs,
    );
  }
}
