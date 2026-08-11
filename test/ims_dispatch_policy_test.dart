import 'package:flutter_test/flutter_test.dart';
import 'package:rentcar00_ops/data/models/external_reservation_link.dart';
import 'package:rentcar00_ops/features/reservations/shared/domain/ims_dispatch_policy.dart';

void main() {
  test('daily and blank imported reservation types keep general dispatch', () {
    expect(
      resolveImsDispatchPolicy(
        _link(payload: {'reservationType': 'daily'}),
      ).carStatusAfterDispatch,
      '일반',
    );
    expect(resolveImsDispatchPolicy(_link()).carStatusAfterDispatch, '일반');
  });

  test('monthly imported reservation dispatches to long-term car status', () {
    final policy = resolveImsDispatchPolicy(
      _link(payload: {'reservationType': 'monthly'}),
    );

    expect(policy.carStatusAfterDispatch, '장기');
    expect(policy.carStatusActionAfterDispatch, '배차 장기');
  });

  test('insurance imported reservation dispatches to insurance car status', () {
    final policy = resolveImsDispatchPolicy(
      _link(payload: {'reservationType': 'insurance'}),
    );

    expect(policy.carStatusAfterDispatch, '보험');
    expect(policy.carStatusActionAfterDispatch, '배차 보험');
  });

  test('insurance claim source type always dispatches to insurance status', () {
    final policy = resolveImsDispatchPolicy(
      _link(
        sourceType: 'insurance_claim',
        payload: {'reservationType': 'daily'},
      ),
    );

    expect(policy.carStatusAfterDispatch, '보험');
    expect(policy.carStatusActionAfterDispatch, '배차 보험');
  });

  test('last result json is used when payload has no reservation type', () {
    final policy = resolveImsDispatchPolicy(
      _link(result: {'rental_type': 'monthly'}),
    );

    expect(policy.carStatusAfterDispatch, '장기');
  });

  test('unknown imported reservation types fall back to general dispatch', () {
    final policy = resolveImsDispatchPolicy(
      _link(payload: {'reservationType': 'partner_daily'}),
    );

    expect(policy.carStatusAfterDispatch, '일반');
    expect(policy.carStatusActionAfterDispatch, '일정완료');
  });
}

ExternalReservationLink _link({
  String sourceType = 'normal_schedule',
  Map<String, dynamic> payload = const {},
  Map<String, dynamic> result = const {},
}) {
  return ExternalReservationLink(
    id: 'link-1',
    reservationId: 'RES-1',
    provider: 'ims',
    externalStatus: 'linked',
    sourceType: sourceType,
    linkKey: 'ims:1',
    lastPayloadJson: payload,
    lastResultJson: result,
  );
}
