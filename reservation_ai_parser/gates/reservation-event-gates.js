export const RESERVATION_EVENT_TYPES = Object.freeze([
  'reservation.created',
  'reservation.cancelled',
]);

export function allowGate(extra = {}) {
  return { ok: true, ...extra };
}

export function blockGate(status, code, message, extra = {}) {
  return { ok: false, status, code, message, ...extra };
}

export function evaluateReservationEventHeaderGate({ eventType, eventId } = {}) {
  if (!RESERVATION_EVENT_TYPES.includes(stringifyNullable(eventType).trim())) {
    return blockGate(400, 'invalid_event_type', 'X-Rentcar00-Event-Type must be reservation.created or reservation.cancelled');
  }
  if (!stringifyNullable(eventId).trim()) {
    return blockGate(400, 'missing_event_id', 'X-Rentcar00-Event-Id is required');
  }
  return allowGate({ eventType: stringifyNullable(eventType).trim(), eventId: stringifyNullable(eventId).trim() });
}

export function normalizeReservationEventSourceProvider(value) {
  const rawSourceProvider = firstText(value);
  const text = rawSourceProvider.toLowerCase();
  if (text === 'carmore' || text === '카모아') {
    return { sourceProvider: 'carmore', rawSourceProvider, usedHomepageFallback: false };
  }
  if (text === 'zzimcar' || text === '찜카') {
    return { sourceProvider: 'zzimcar', rawSourceProvider, usedHomepageFallback: false };
  }
  if (['ims_partner', 'ims-partner', 'imspartner', 'ims partner', 'ims'].includes(text)) {
    return { sourceProvider: 'ims_partner', rawSourceProvider, usedHomepageFallback: false };
  }
  return {
    sourceProvider: 'homepage',
    rawSourceProvider,
    usedHomepageFallback: true,
    fallbackReason: rawSourceProvider ? 'unknown_source_provider' : 'missing_source_provider',
  };
}

export function buildReservationCreatedEventPayload({ body, eventId, eventType } = {}) {
  const bodyGate = evaluateReservationEventBodyIdentityGate({ body, eventId, eventType });
  if (!bodyGate.ok) return bodyGate;

  const booking = body?.booking && typeof body.booking === 'object' ? body.booking : null;
  if (!booking) return blockGate(400, 'invalid_payload', 'booking object is required');
  const input = body?.reservationInput && typeof body.reservationInput === 'object' ? body.reservationInput : {};

  const bookingOrderId = firstNonEmpty(
    booking.bookingOrderId,
    input.bookingOrderId,
  );
  const sourceReservationId = firstNonEmpty(
    booking.sourceReservationId,
    booking.externalReservationId,
    booking.external_reservation_id,
    booking.providerReservationId,
    input.sourceReservationId,
    input.externalReservationId,
    input.external_reservation_id,
    input.providerReservationId,
  );
  const reservationCode = firstNonEmpty(
    booking.reservationCode,
    booking.reservationNumber,
    input.reservationCode,
    input.reservationNumber,
    booking.sourceReservationNo,
    booking.externalReservationNo,
    booking.external_reservation_no,
    input.sourceReservationNo,
    input.externalReservationNo,
    input.external_reservation_no,
    sourceReservationId,
  );
  if (!bookingOrderId && !reservationCode && !sourceReservationId) {
    return blockGate(400, 'invalid_payload', 'booking bookingOrderId, reservationCode or sourceReservationId is required');
  }

  return allowGate({
    payload: {
      eventId,
      eventType,
      bookingOrderId,
      reservationCode,
      payload: body,
      status: 'received',
    },
  });
}

export function buildReservationCancelledEventPayload({ body, eventId, eventType } = {}) {
  const bodyGate = evaluateReservationEventBodyIdentityGate({ body, eventId, eventType });
  if (!bodyGate.ok) return bodyGate;

  const booking = body?.booking && typeof body.booking === 'object' ? body.booking : {};
  const input = body?.reservationInput && typeof body.reservationInput === 'object' ? body.reservationInput : {};
  const provider = firstNonEmpty(
    body?.provider,
    booking.sourceProvider,
    input.sourceProvider,
  );
  const sourceReservationId = firstNonEmpty(
    booking.sourceReservationId,
    booking.externalReservationId,
    booking.external_reservation_id,
    input.sourceReservationId,
    input.externalReservationId,
    input.external_reservation_id,
  );
  const reservationCode = firstNonEmpty(
    booking.reservationCode,
    booking.reservationNumber,
    booking.sourceReservationNo,
    booking.externalReservationNo,
    booking.external_reservation_no,
    input.reservationCode,
    input.reservationNumber,
    input.sourceReservationNo,
    input.externalReservationNo,
    input.external_reservation_no,
    sourceReservationId,
  );
  const bookingOrderId = firstNonEmpty(
    booking.bookingOrderId,
    input.bookingOrderId,
    provider && sourceReservationId ? `external-provider:${provider}:${sourceReservationId}` : '',
  );

  if (!provider || !sourceReservationId) {
    return blockGate(400, 'invalid_payload', 'provider and source reservation id are required for cancellation event');
  }

  return allowGate({
    payload: {
      eventId,
      eventType,
      bookingOrderId,
      reservationCode,
      provider,
      sourceReservationId,
      payload: body,
      status: 'pending_review',
    },
  });
}

export function evaluateReservationEventBodyIdentityGate({ body, eventId, eventType } = {}) {
  const bodyEventId = stringifyNullable(body?.eventId).trim();
  const bodyEventType = stringifyNullable(body?.eventType).trim();
  if (bodyEventId && bodyEventId !== eventId) {
    return blockGate(400, 'event_id_mismatch', 'header and body eventId do not match');
  }
  if (bodyEventType && bodyEventType !== eventType) {
    return blockGate(400, 'event_type_mismatch', 'header and body eventType do not match');
  }
  return allowGate();
}

export function evaluateImsBindingPreparationGate({ mapped, existingLink } = {}) {
  if (!mapped) return blockGate(400, 'mapped_reservation_missing', 'mapped reservation is required');

  if (existingLink?.external_status === 'linked' && existingLink?.external_reservation_id) {
    if (mapped.sourceProvider === 'ims_partner') {
      const expectedBinding = buildExistingImsPartnerBindingResult(mapped);
      if (!expectedBinding.ok) return expectedBinding;
      if (String(expectedBinding.bindingResult.externalReservationId) !== String(existingLink.external_reservation_id)) {
        return blockGate(409, 'ims_binding_conflict', `IMS partner event points to ${expectedBinding.bindingResult.externalReservationId}, but OPS reservation is linked to ${existingLink.external_reservation_id}`);
      }
    }
    return allowGate({ action: 'reuse_existing_link' });
  }

  if (mapped.sourceProvider === 'ims_partner') {
    return buildExistingImsPartnerBindingResult(mapped);
  }

  return allowGate({ action: 'create_or_reuse_ims' });
}

export function buildExistingImsPartnerBindingResult(mapped = {}) {
  const input = mapped.metaJson?.reservation_input && typeof mapped.metaJson.reservation_input === 'object'
    ? mapped.metaJson.reservation_input
    : {};
  const externalReservationId = firstNonEmpty(
    mapped.sourceReservationId,
    input.imsReservationId,
    input.externalReservationId,
    input.external_reservation_id,
  );
  if (!externalReservationId) {
    return blockGate(400, 'ims_partner_identity_required', 'IMS partner event requires an existing IMS reservation id');
  }
  const externalDetailId = firstNonEmpty(
    input.externalDetailId,
    input.external_detail_id,
    input.imsDetailId,
    input.ims_detail_id,
    mapped.reservationNumber,
  );
  return allowGate({
    action: 'use_existing_ims_partner_binding',
    bindingResult: {
      attempted: false,
      created: false,
      reused: true,
      reusedExisting: true,
      externalReservationId,
      externalDetailId,
      externalStatus: 'linked',
      sourceType: 'normal_schedule',
      linkKey: `IMS:${externalReservationId}`,
      error: null,
    },
  });
}

export function evaluateImsLinkedAfterCreateGate(bindingResult = {}) {
  const imsLinked = bindingResult?.externalStatus === 'linked' && Boolean(bindingResult?.externalReservationId);
  if (!imsLinked) {
    return blockGate(
      409,
      'ims_create_required_before_ops',
      stringifyErrorText(bindingResult?.errorText || bindingResult?.message) || 'IMS 생성 성공 전에는 OPS 예약을 생성하지 않습니다.',
    );
  }
  return allowGate();
}

export function evaluateImsBindingAvailabilityIdentityGate({ externalReservationId, reservationId } = {}) {
  const externalId = stringifyNullable(externalReservationId).trim();
  const targetReservationId = stringifyNullable(reservationId).trim();
  if (!externalId || !targetReservationId) {
    return blockGate(400, 'ims_binding_identity_required', 'IMS external ID and OPS reservation ID are required');
  }
  return allowGate({ externalId, targetReservationId });
}

export function evaluateImsBindingConflictRowsGate({ rows = [], reservationId, externalReservationId } = {}) {
  const identityGate = evaluateImsBindingAvailabilityIdentityGate({ externalReservationId, reservationId });
  if (!identityGate.ok) return identityGate;
  const conflicts = (Array.isArray(rows) ? rows : []).filter((row) => stringifyNullable(row.reservation_id) !== identityGate.targetReservationId);
  if (conflicts.length > 0) {
    return blockGate(409, 'ims_binding_conflict', `IMS reservation ${identityGate.externalId} is already linked to another OPS reservation`, { conflicts });
  }
  return allowGate({ conflicts: [] });
}

export function evaluateOpsProjectionIdentityGate({ mapped, reservationRefId } = {}) {
  if (!mapped?.reservationId || !reservationRefId) {
    return blockGate(500, 'ops_projection_identity_required', 'OPS projection identity is required');
  }
  return allowGate({ reservationId: mapped.reservationId, reservationRefId });
}

export function firstNonEmpty(...values) {
  for (const value of values) {
    const text = stringifyNullable(value).trim();
    if (text) return text;
  }
  return '';
}

export function firstText(...values) {
  return firstNonEmpty(...values);
}

export function stringifyNullable(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}

export function stringifyErrorText(value) {
  if (value === null || value === undefined || value === '') return '';
  if (typeof value === 'string') return value;
  if (value instanceof Error) return value.message || '';
  if (typeof value === 'object') {
    const direct = value.message || value.msg || value.error || value.reason || value.detail || value.details || value.code;
    if (direct && direct !== value) return stringifyErrorText(direct);
    try {
      return JSON.stringify(value);
    } catch {
      return 'unknown_object_error';
    }
  }
  try {
    return String(value);
  } catch {
    return '';
  }
}
