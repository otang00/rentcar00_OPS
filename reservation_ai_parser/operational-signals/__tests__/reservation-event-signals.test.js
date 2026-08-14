import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildOpsImsBindingConflictSignal,
  buildOpsImsCreateRequiredBeforeProjectionSignal,
  buildOpsProjectionSignal,
  buildOpsReservationEventFailedSignal,
  buildOpsReservationEventImportedSignal,
  buildOpsReservationEventReceivedSignal,
  buildOpsReservationEventSignalsFromFailure,
  buildOpsReservationEventSignalsFromImportResult,
} from '../reservation-event-signals.js';
import { OPS_RESERVATION_EVENT_SIGNAL_CODES } from '../catalog.js';

test('received signal uses only safe receiver fields', () => {
  const signal = buildOpsReservationEventReceivedSignal({
    eventId: 'reservation.created:homepage:BO-1',
    eventType: 'reservation.created',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    deduped: false,
    status: 'received',
    payload: { customerName: '홍길동' },
    customerPhone: '01012345678',
    secret: 'SUPABASE_SERVICE_ROLE_KEY',
  });

  assert.deepEqual(signal, {
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_RECEIVED,
    severity: 'info',
    stage: 'receiver',
    status: 'received',
    eventId: 'reservation.created:homepage:BO-1',
    eventType: 'reservation.created',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    deduped: false,
  });
  assertPrivacySafe(signal);
});

test('received cancellation signal can represent pending review without import claim', () => {
  const signal = buildOpsReservationEventReceivedSignal({
    eventId: 'reservation.cancelled:carmore:CM-1',
    eventType: 'reservation.cancelled',
    provider: 'carmore',
    sourceReservationId: 'CM-1',
    deduped: true,
    reviewRequired: true,
  });

  assert.equal(signal.code, OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_RECEIVED);
  assert.equal(signal.status, 'pending_review');
  assert.equal(signal.reviewRequired, true);
  assert.equal(signal.deduped, true);
});

test('imported signal summarizes safe OPS and IMS result fields', () => {
  const signal = buildOpsReservationEventImportedSignal({
    eventId: 'reservation.created:zzimcar:ZZ-1',
    provider: 'zzimcar',
    sourceReservationId: 'ZZ-1',
    reservationId: 'EXT-zzimcar-ZZ-1',
    reservationRefId: 'ops-row-1',
    ops: {
      created: true,
      scheduleCreated: true,
      scheduleCount: 2,
      carMatched: true,
    },
    ims: {
      externalReservationId: 'IMS-1',
      requestBody: { customerName: '홍길동' },
    },
    payload: { customerPhone: '01012345678' },
  });

  assert.deepEqual(signal, {
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_IMPORTED,
    severity: 'info',
    stage: 'import',
    status: 'imported',
    eventId: 'reservation.created:zzimcar:ZZ-1',
    provider: 'zzimcar',
    sourceReservationId: 'ZZ-1',
    reservationId: 'EXT-zzimcar-ZZ-1',
    reservationRefId: 'ops-row-1',
    scheduleCreated: true,
    scheduleCount: 2,
    carMatched: true,
    imsExternalReservationId: 'IMS-1',
  });
  assertPrivacySafe(signal);
});

test('failed signal uses reason code and drops raw error message', () => {
  const signal = buildOpsReservationEventFailedSignal({
    eventId: 'reservation.created:homepage:BO-1',
    eventType: 'reservation.created',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    reservationId: 'WEB-BO-1',
    error: {
      code: 'ims_binding_conflict',
      message: '홍길동 01012345678 should not leak',
    },
  });

  assert.deepEqual(signal, {
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_FAILED,
    severity: 'error',
    stage: 'ims_binding',
    status: 'failed',
    eventId: 'reservation.created:homepage:BO-1',
    eventType: 'reservation.created',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    reservationId: 'WEB-BO-1',
    reasonCode: 'ims_binding_conflict',
  });
  assertPrivacySafe(signal);
});

test('IMS binding conflict signal is separate from generic failed signal', () => {
  const signal = buildOpsImsBindingConflictSignal({
    eventId: 'reservation.created:ims_partner:IMS-1',
    provider: 'ims_partner',
    sourceReservationId: 'IMS-1',
    reservationId: 'EXT-ims_partner-IMS-1',
    externalReservationId: 'IMS-1',
    details: { customerName: '홍길동' },
  });

  assert.deepEqual(signal, {
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.IMS_BINDING_CONFLICT,
    severity: 'error',
    stage: 'ims_binding',
    status: 'blocked',
    eventId: 'reservation.created:ims_partner:IMS-1',
    provider: 'ims_partner',
    sourceReservationId: 'IMS-1',
    reservationId: 'EXT-ims_partner-IMS-1',
    externalReservationId: 'IMS-1',
    reasonCode: 'ims_binding_conflict',
  });
  assertPrivacySafe(signal);
});

test('IMS create-required signal blocks projection without fallback projection claim', () => {
  const signal = buildOpsImsCreateRequiredBeforeProjectionSignal({
    eventId: 'reservation.created:carmore:CM-1',
    provider: 'carmore',
    sourceReservationId: 'CM-1',
    reservationId: 'EXT-carmore-CM-1',
    errorText: 'IMS 생성 실패',
  });

  assert.equal(signal.code, OPS_RESERVATION_EVENT_SIGNAL_CODES.IMS_CREATE_REQUIRED_BEFORE_PROJECTION);
  assert.equal(signal.stage, 'ims_binding');
  assert.equal(signal.status, 'blocked');
  assert.equal(signal.reasonCode, 'ims_create_required_before_ops');
  assertPrivacySafe(signal);
});

test('projection signal distinguishes created and reused outcomes', () => {
  const created = buildOpsProjectionSignal({
    eventId: 'reservation.created:homepage:BO-1',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    reservationId: 'WEB-BO-1',
    reservationRefId: 'ops-row-1',
    ops: {
      created: true,
      reused: false,
      scheduleCreated: true,
      scheduleCount: 2,
      carMatched: false,
    },
  });
  assert.equal(created.code, OPS_RESERVATION_EVENT_SIGNAL_CODES.PROJECTION_CREATED);
  assert.equal(created.status, 'created');
  assert.equal(created.scheduleCount, 2);
  assert.equal(created.carMatched, false);

  const reused = buildOpsProjectionSignal({
    eventId: 'reservation.created:homepage:BO-1',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    reservationId: 'WEB-BO-1',
    reservationRefId: 'ops-row-1',
    ops: {
      created: false,
      reused: true,
      scheduleCreated: true,
      scheduleCount: 2,
      carMatched: true,
    },
  });
  assert.equal(reused.code, OPS_RESERVATION_EVENT_SIGNAL_CODES.PROJECTION_REUSED);
  assert.equal(reused.status, 'reused');
  assertPrivacySafe(created);
  assertPrivacySafe(reused);
});

test('import result signal list includes imported plus projection signal', () => {
  const signals = buildOpsReservationEventSignalsFromImportResult({
    eventId: 'reservation.created:homepage:BO-1',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    reservationId: 'WEB-BO-1',
    reservationRefId: 'ops-row-1',
    ops: {
      created: true,
      scheduleCreated: true,
      scheduleCount: 2,
      carMatched: true,
    },
    ims: { externalReservationId: 'IMS-1' },
  });

  assert.deepEqual(signals.map((signal) => signal.code), [
    OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_IMPORTED,
    OPS_RESERVATION_EVENT_SIGNAL_CODES.PROJECTION_CREATED,
  ]);
});

test('failure signal list includes specialized IMS signals when reason matches', () => {
  const conflictSignals = buildOpsReservationEventSignalsFromFailure({
    eventId: 'reservation.created:homepage:BO-1',
    provider: 'homepage',
    sourceReservationId: 'BO-1',
    reservationId: 'WEB-BO-1',
    externalReservationId: 'IMS-1',
    error: { code: 'ims_binding_conflict' },
  });
  assert.deepEqual(conflictSignals.map((signal) => signal.code), [
    OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_FAILED,
    OPS_RESERVATION_EVENT_SIGNAL_CODES.IMS_BINDING_CONFLICT,
  ]);

  const createRequiredSignals = buildOpsReservationEventSignalsFromFailure({
    error: { code: 'ims_create_required_before_ops' },
  });
  assert.deepEqual(createRequiredSignals.map((signal) => signal.code), [
    OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_FAILED,
    OPS_RESERVATION_EVENT_SIGNAL_CODES.IMS_CREATE_REQUIRED_BEFORE_PROJECTION,
  ]);
});

function assertPrivacySafe(signal) {
  const serialized = JSON.stringify(signal);
  assert.equal(serialized.includes('홍길동'), false, serialized);
  assert.equal(serialized.includes('01012345678'), false, serialized);
  assert.equal(serialized.includes('SUPABASE_SERVICE_ROLE_KEY'), false, serialized);
  assert.equal(serialized.includes('service_role'), false, serialized);
  assert.equal(Object.hasOwn(signal, 'payload'), false);
  assert.equal(Object.hasOwn(signal, 'rawPayload'), false);
  assert.equal(Object.hasOwn(signal, 'booking'), false);
  assert.equal(Object.hasOwn(signal, 'reservationInput'), false);
  assert.equal(Object.hasOwn(signal, 'customerName'), false);
  assert.equal(Object.hasOwn(signal, 'customerPhone'), false);
  assert.equal(Object.hasOwn(signal, 'secret'), false);
}
