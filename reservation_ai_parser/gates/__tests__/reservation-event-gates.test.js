import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildExistingImsPartnerBindingResult,
  buildReservationCancelledEventPayload,
  buildReservationCreatedEventPayload,
  evaluateImsBindingAvailabilityIdentityGate,
  evaluateImsBindingConflictRowsGate,
  evaluateImsBindingPreparationGate,
  evaluateImsLinkedAfterCreateGate,
  evaluateOpsProjectionIdentityGate,
  evaluateReservationEventBodyIdentityGate,
  evaluateReservationEventHeaderGate,
  normalizeReservationEventSourceProvider,
} from '../reservation-event-gates.js';

test('receiver header gate preserves existing event type and id errors', () => {
  assert.deepEqual(evaluateReservationEventHeaderGate({ eventType: 'x', eventId: 'evt-1' }), {
    ok: false,
    status: 400,
    code: 'invalid_event_type',
    message: 'X-Rentcar00-Event-Type must be reservation.created or reservation.cancelled',
  });
  assert.deepEqual(evaluateReservationEventHeaderGate({ eventType: 'reservation.created', eventId: '' }), {
    ok: false,
    status: 400,
    code: 'missing_event_id',
    message: 'X-Rentcar00-Event-Id is required',
  });
  assert.deepEqual(evaluateReservationEventHeaderGate({ eventType: 'reservation.created', eventId: 'evt-1' }), {
    ok: true,
    eventType: 'reservation.created',
    eventId: 'evt-1',
  });
});

test('receiver body identity gate preserves mismatch errors', () => {
  assert.deepEqual(evaluateReservationEventBodyIdentityGate({
    body: { eventId: 'body-evt' },
    eventId: 'header-evt',
    eventType: 'reservation.created',
  }), {
    ok: false,
    status: 400,
    code: 'event_id_mismatch',
    message: 'header and body eventId do not match',
  });
  assert.deepEqual(evaluateReservationEventBodyIdentityGate({
    body: { eventType: 'reservation.cancelled' },
    eventId: 'evt-1',
    eventType: 'reservation.created',
  }), {
    ok: false,
    status: 400,
    code: 'event_type_mismatch',
    message: 'header and body eventType do not match',
  });
});

test('created payload gate requires booking and one reservation identity', () => {
  assert.equal(buildReservationCreatedEventPayload({
    body: {},
    eventId: 'evt-1',
    eventType: 'reservation.created',
  }).code, 'invalid_payload');

  assert.deepEqual(buildReservationCreatedEventPayload({
    body: { booking: {} },
    eventId: 'evt-1',
    eventType: 'reservation.created',
  }), {
    ok: false,
    status: 400,
    code: 'invalid_payload',
    message: 'booking bookingOrderId, reservationCode or sourceReservationId is required',
  });

  const result = buildReservationCreatedEventPayload({
    body: { booking: { bookingOrderId: 'BO-1' } },
    eventId: 'evt-1',
    eventType: 'reservation.created',
  });
  assert.equal(result.ok, true);
  assert.equal(result.payload.bookingOrderId, 'BO-1');
  assert.equal(result.payload.status, 'received');
});

test('cancelled payload gate requires provider and source reservation id', () => {
  assert.deepEqual(buildReservationCancelledEventPayload({
    body: { booking: { sourceProvider: 'carmore' } },
    eventId: 'evt-1',
    eventType: 'reservation.cancelled',
  }), {
    ok: false,
    status: 400,
    code: 'invalid_payload',
    message: 'provider and source reservation id are required for cancellation event',
  });

  const result = buildReservationCancelledEventPayload({
    body: {
      booking: {
        sourceProvider: 'carmore',
        sourceReservationId: 'CM-1',
      },
    },
    eventId: 'evt-1',
    eventType: 'reservation.cancelled',
  });
  assert.equal(result.ok, true);
  assert.equal(result.payload.bookingOrderId, 'external-provider:carmore:CM-1');
  assert.equal(result.payload.status, 'pending_review');
});

test('source provider compatibility preserves implicit homepage fallback', () => {
  assert.deepEqual(normalizeReservationEventSourceProvider('카모아'), {
    sourceProvider: 'carmore',
    rawSourceProvider: '카모아',
    usedHomepageFallback: false,
  });
  assert.deepEqual(normalizeReservationEventSourceProvider('ims-partner'), {
    sourceProvider: 'ims_partner',
    rawSourceProvider: 'ims-partner',
    usedHomepageFallback: false,
  });
  assert.deepEqual(normalizeReservationEventSourceProvider(''), {
    sourceProvider: 'homepage',
    rawSourceProvider: '',
    usedHomepageFallback: true,
    fallbackReason: 'missing_source_provider',
  });
  assert.deepEqual(normalizeReservationEventSourceProvider('new-mall'), {
    sourceProvider: 'homepage',
    rawSourceProvider: 'new-mall',
    usedHomepageFallback: true,
    fallbackReason: 'unknown_source_provider',
  });
});

test('IMS binding preparation gate reuses linked rows and blocks ims partner mismatches', () => {
  assert.equal(evaluateImsBindingPreparationGate({ mapped: null }).code, 'mapped_reservation_missing');

  assert.deepEqual(evaluateImsBindingPreparationGate({
    mapped: { sourceProvider: 'homepage', reservationId: 'WEB-1' },
    existingLink: { external_status: 'linked', external_reservation_id: 'IMS-1' },
  }), {
    ok: true,
    action: 'reuse_existing_link',
  });

  const conflict = evaluateImsBindingPreparationGate({
    mapped: { sourceProvider: 'ims_partner', reservationId: 'EXT-1', sourceReservationId: 'IMS-2', metaJson: { reservation_input: {} } },
    existingLink: { external_status: 'linked', external_reservation_id: 'IMS-1' },
  });
  assert.equal(conflict.ok, false);
  assert.equal(conflict.status, 409);
  assert.equal(conflict.code, 'ims_binding_conflict');
});

test('IMS partner binding result preserves existing linked-source shape', () => {
  const result = buildExistingImsPartnerBindingResult({
    sourceReservationId: 'IMS-5684',
    reservationNumber: 'DETAIL-5684',
    metaJson: { reservation_input: {} },
  });
  assert.equal(result.ok, true);
  assert.deepEqual(result.bindingResult, {
    attempted: false,
    created: false,
    reused: true,
    reusedExisting: true,
    externalReservationId: 'IMS-5684',
    externalDetailId: 'DETAIL-5684',
    externalStatus: 'linked',
    sourceType: 'normal_schedule',
    linkKey: 'IMS:IMS-5684',
    error: null,
  });

  assert.equal(buildExistingImsPartnerBindingResult({ metaJson: { reservation_input: {} } }).code, 'ims_partner_identity_required');
});

test('IMS create result gate blocks OPS projection until linked', () => {
  assert.deepEqual(evaluateImsLinkedAfterCreateGate({ externalStatus: 'failed', message: 'no match' }), {
    ok: false,
    status: 409,
    code: 'ims_create_required_before_ops',
    message: 'no match',
  });
  assert.equal(evaluateImsLinkedAfterCreateGate({ externalStatus: 'failed', errorText: { message: 'object message' } }).message, 'object message');
  assert.deepEqual(evaluateImsLinkedAfterCreateGate({ externalStatus: 'linked', externalReservationId: 'IMS-1' }), {
    ok: true,
  });
});

test('IMS binding availability gate preserves identity and conflict errors', () => {
  assert.equal(evaluateImsBindingAvailabilityIdentityGate({ externalReservationId: '', reservationId: 'OPS-1' }).code, 'ims_binding_identity_required');

  const conflict = evaluateImsBindingConflictRowsGate({
    rows: [{ reservation_id: 'OPS-2', external_reservation_id: 'IMS-1', external_status: 'linked' }],
    reservationId: 'OPS-1',
    externalReservationId: 'IMS-1',
  });
  assert.equal(conflict.ok, false);
  assert.equal(conflict.status, 409);
  assert.equal(conflict.code, 'ims_binding_conflict');

  assert.deepEqual(evaluateImsBindingConflictRowsGate({
    rows: [{ reservation_id: 'OPS-1', external_reservation_id: 'IMS-1', external_status: 'linked' }],
    reservationId: 'OPS-1',
    externalReservationId: 'IMS-1',
  }), {
    ok: true,
    conflicts: [],
  });
});

test('OPS projection identity gate preserves missing identity error', () => {
  assert.deepEqual(evaluateOpsProjectionIdentityGate({ mapped: { reservationId: '' }, reservationRefId: 'ref-1' }), {
    ok: false,
    status: 500,
    code: 'ops_projection_identity_required',
    message: 'OPS projection identity is required',
  });
  assert.deepEqual(evaluateOpsProjectionIdentityGate({ mapped: { reservationId: 'WEB-1' }, reservationRefId: 'ref-1' }), {
    ok: true,
    reservationId: 'WEB-1',
    reservationRefId: 'ref-1',
  });
});
