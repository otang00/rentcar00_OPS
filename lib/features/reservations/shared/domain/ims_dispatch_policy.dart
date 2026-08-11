import 'package:rentcar00_ops/data/models/external_reservation_link.dart';

class ImsDispatchPolicy {
  const ImsDispatchPolicy({
    required this.carStatusAfterDispatch,
    required this.carStatusActionAfterDispatch,
  });

  final String carStatusAfterDispatch;
  final String carStatusActionAfterDispatch;
}

const kDefaultImsDispatchPolicy = ImsDispatchPolicy(
  carStatusAfterDispatch: '일반',
  carStatusActionAfterDispatch: '일정완료',
);

ImsDispatchPolicy resolveImsDispatchPolicy(ExternalReservationLink? link) {
  final sourceType = link?.sourceType.trim().toLowerCase() ?? '';
  if (sourceType == 'insurance_claim') return _dispatchPolicyForStatus('보험');

  switch (_readReservationType(link)) {
    case 'insurance':
      return _dispatchPolicyForStatus('보험');
    case 'monthly':
      return _dispatchPolicyForStatus('장기');
    case 'daily':
    default:
      return kDefaultImsDispatchPolicy;
  }
}

String _readReservationType(ExternalReservationLink? link) {
  if (link == null) return '';
  final payloadType = _readReservationTypeFromJson(link.lastPayloadJson);
  if (payloadType.isNotEmpty) return payloadType;
  return _readReservationTypeFromJson(link.lastResultJson);
}

String _readReservationTypeFromJson(Map<String, dynamic> json) {
  final value =
      json['reservationType'] ??
      json['reservation_type'] ??
      json['rentalType'] ??
      json['rental_type'];
  return value?.toString().trim().toLowerCase() ?? '';
}

ImsDispatchPolicy _dispatchPolicyForStatus(String status) {
  return ImsDispatchPolicy(
    carStatusAfterDispatch: status,
    carStatusActionAfterDispatch: '배차 $status',
  );
}
