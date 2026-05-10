import 'package:rentcar00_ops/features/status_board/shared/domain/status_board_tab.dart';

class StatusBoardRecord {
  const StatusBoardRecord({
    required this.recordId,
    required this.tab,
    required this.sourceKind,
    required this.carNumber,
    required this.carName,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.startAt,
    required this.endAt,
    required this.pickupLocation,
    required this.parkingLocation,
    required this.noteText,
    required this.statusAction,
    required this.carWash,
    required this.interiorWash,
    required this.timeLabel,
    required this.locationSummary,
    required this.primaryBadges,
    required this.sortAt,
    this.scheduleId = '',
    this.scheduleType = '',
    this.scheduleDone = '',
    this.detailText = '',
    this.carRegisteredAt = '',
    this.carInspectionAt = '',
    this.carAgeExpiryAt = '',
    this.carNumberFront = '',
    this.carNumberMiddle = '',
    this.carNumberRear = '',
  });

  final String recordId;
  final StatusBoardTab tab;
  final String sourceKind;
  final String carNumber;
  final String carName;
  final String status;
  final String customerName;
  final String customerPhone;
  final String startAt;
  final String endAt;
  final String pickupLocation;
  final String parkingLocation;
  final String noteText;
  final String statusAction;
  final String carWash;
  final String interiorWash;
  final String timeLabel;
  final String locationSummary;
  final List<String> primaryBadges;
  final DateTime? sortAt;
  final String scheduleId;
  final String scheduleType;
  final String scheduleDone;
  final String detailText;
  final String carRegisteredAt;
  final String carInspectionAt;
  final String carAgeExpiryAt;
  final String carNumberFront;
  final String carNumberMiddle;
  final String carNumberRear;

  bool get isScheduleEntry => sourceKind == 'schedule';
}
