import { OPS_RESERVATION_EVENT_SIGNAL_CODES } from './catalog.js';

export function buildOpsReservationEventReceivedSignal(input = {}) {
  return buildSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_RECEIVED,
    severity: 'info',
    stage: 'receiver',
    status: normalizeStatus(input.status, input.reviewRequired ? 'pending_review' : 'received'),
    eventId: input.eventId,
    eventType: input.eventType,
    provider: input.provider,
    sourceReservationId: input.sourceReservationId,
    deduped: normalizeOptionalBoolean(input.deduped),
    reviewRequired: normalizeOptionalBoolean(input.reviewRequired),
  });
}

export function buildOpsReservationEventImportedSignal(importResult = {}) {
  const ops = objectOrEmpty(importResult.ops);
  const ims = objectOrEmpty(importResult.ims);
  return buildSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_IMPORTED,
    severity: 'info',
    stage: 'import',
    status: 'imported',
    eventId: importResult.eventId,
    provider: importResult.provider,
    sourceReservationId: importResult.sourceReservationId,
    reservationId: importResult.reservationId,
    reservationRefId: importResult.reservationRefId,
    scheduleCreated: normalizeOptionalBoolean(ops.scheduleCreated),
    scheduleCount: normalizeOptionalNumber(ops.scheduleCount),
    carMatched: normalizeOptionalBoolean(ops.carMatched),
    imsExternalReservationId: ims.externalReservationId,
  });
}

export function buildOpsReservationEventFailedSignal(input = {}) {
  const reasonCode = normalizeReasonCode(input.reasonCode || input.error);
  return buildSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.RESERVATION_EVENT_FAILED,
    severity: 'error',
    stage: inferFailureStage(reasonCode),
    status: 'failed',
    eventId: input.eventId,
    eventType: input.eventType,
    provider: input.provider,
    sourceReservationId: input.sourceReservationId,
    reservationId: input.reservationId,
    reasonCode,
  });
}

export function buildOpsImsBindingConflictSignal(input = {}) {
  return buildSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.IMS_BINDING_CONFLICT,
    severity: 'error',
    stage: 'ims_binding',
    status: 'blocked',
    eventId: input.eventId,
    provider: input.provider,
    sourceReservationId: input.sourceReservationId,
    reservationId: input.reservationId,
    externalReservationId: input.externalReservationId,
    reasonCode: 'ims_binding_conflict',
  });
}

export function buildOpsImsCreateRequiredBeforeProjectionSignal(input = {}) {
  return buildSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.IMS_CREATE_REQUIRED_BEFORE_PROJECTION,
    severity: 'error',
    stage: 'ims_binding',
    status: 'blocked',
    eventId: input.eventId,
    provider: input.provider,
    sourceReservationId: input.sourceReservationId,
    reservationId: input.reservationId,
    reasonCode: 'ims_create_required_before_ops',
  });
}

export function buildOpsProjectionSignal(importResult = {}) {
  const ops = objectOrEmpty(importResult.ops);
  if (ops.created === true) {
    return buildOpsProjectionCreatedSignal(importResult);
  }
  if (ops.reused === true) {
    return buildOpsProjectionReusedSignal(importResult);
  }
  return null;
}

export function buildOpsProjectionCreatedSignal(importResult = {}) {
  return buildProjectionSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.PROJECTION_CREATED,
    status: 'created',
    importResult,
  });
}

export function buildOpsProjectionReusedSignal(importResult = {}) {
  return buildProjectionSignal({
    code: OPS_RESERVATION_EVENT_SIGNAL_CODES.PROJECTION_REUSED,
    status: 'reused',
    importResult,
  });
}

export function buildOpsReservationEventSignalsFromImportResult(importResult = {}) {
  const signals = [buildOpsReservationEventImportedSignal(importResult)];
  const projectionSignal = buildOpsProjectionSignal(importResult);
  if (projectionSignal) signals.push(projectionSignal);
  return signals;
}

export function buildOpsReservationEventSignalsFromFailure(input = {}) {
  const failed = buildOpsReservationEventFailedSignal(input);
  if (failed.reasonCode === 'ims_binding_conflict') {
    return [failed, buildOpsImsBindingConflictSignal(input)];
  }
  if (failed.reasonCode === 'ims_create_required_before_ops') {
    return [failed, buildOpsImsCreateRequiredBeforeProjectionSignal(input)];
  }
  return [failed];
}

function buildProjectionSignal({ code, status, importResult } = {}) {
  const ops = objectOrEmpty(importResult.ops);
  return buildSignal({
    code,
    severity: 'info',
    stage: 'ops_projection',
    status,
    eventId: importResult.eventId,
    provider: importResult.provider,
    sourceReservationId: importResult.sourceReservationId,
    reservationId: importResult.reservationId || ops.reservationId,
    reservationRefId: importResult.reservationRefId || ops.reservationRefId,
    scheduleCreated: normalizeOptionalBoolean(ops.scheduleCreated),
    scheduleCount: normalizeOptionalNumber(ops.scheduleCount),
    carMatched: normalizeOptionalBoolean(ops.carMatched),
  });
}

function buildSignal(fields = {}) {
  const signal = {};
  for (const [key, value] of Object.entries(fields)) {
    const normalized = normalizeSignalValue(value);
    if (normalized !== undefined) signal[key] = normalized;
  }
  return signal;
}

function normalizeSignalValue(value) {
  if (value === null || value === undefined || value === '') return undefined;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return Number.isFinite(value) ? value : undefined;
  return String(value).trim() || undefined;
}

function normalizeStatus(value, fallback) {
  return stringifyNullable(value).trim() || fallback;
}

function normalizeOptionalBoolean(value) {
  return typeof value === 'boolean' ? value : undefined;
}

function normalizeOptionalNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : undefined;
}

function normalizeReasonCode(value) {
  if (typeof value === 'string') return value.trim() || 'unknown_error';
  if (value && typeof value === 'object') {
    return stringifyNullable(value.code || value.reasonCode || value.name).trim() || 'unknown_error';
  }
  return 'unknown_error';
}

function inferFailureStage(reasonCode) {
  if (String(reasonCode || '').startsWith('ims_')) return 'ims_binding';
  if (String(reasonCode || '').startsWith('ops_projection_')) return 'ops_projection';
  return 'import';
}

function objectOrEmpty(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function stringifyNullable(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}
