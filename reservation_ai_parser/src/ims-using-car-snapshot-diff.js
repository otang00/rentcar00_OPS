#!/usr/bin/env node
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile } from './parser-core.js';
import {
  fetchImsAccessToken,
  fetchImsInsuranceClaimDetail,
  fetchImsNormalScheduleDetail,
  fetchImsUsingCarInsuranceClaims,
  fetchImsUsingCarNormalSchedules,
  findMatchingInsuranceReturnContract,
  normalizeCarNumber,
  normalizeImsDateTime,
  readImsInsuranceClaimState,
  readImsNormalScheduleCarNumber,
  readImsNormalScheduleStatus,
  readJsonResponse,
} from './ims-api-client.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const SOURCE_TYPES = Object.freeze({
  normal: 'normal_schedule',
  insurance: 'insurance_claim',
});

export const LIFECYCLE_EVENT_TYPES = Object.freeze({
  dispatch: 'ims.lifecycle.dispatch_detected',
  return: 'ims.lifecycle.return_detected',
});

export function parseArgs(argv = process.argv.slice(2)) {
  const args = { mode: 'report' };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;
    const [rawKey, inlineValue] = token.slice(2).split('=');
    const key = rawKey.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
    if (inlineValue != null) args[key] = inlineValue;
    else if (argv[index + 1] && !argv[index + 1].startsWith('--')) args[key] = argv[++index];
    else args[key] = true;
  }
  return args;
}

export function normalizeSourceType(value) {
  const sourceType = text(value).trim();
  return sourceType === SOURCE_TYPES.normal || sourceType === SOURCE_TYPES.insurance ? sourceType : '';
}

export function normalizeUsingCarSnapshotRow(sourceType, row = {}, { seenAt = new Date() } = {}) {
  const normalizedSourceType = normalizeSourceType(sourceType);
  if (!normalizedSourceType) return null;
  const normalReservation = row?.reservation || row?.detail || {};
  const isNormal = normalizedSourceType === SOURCE_TYPES.normal;
  const externalId = isNormal
    ? text(row?.id || row?.schedule_id || row?.scheduleId)
    : text(row?.id || row?.claim_id || row?.claimId);
  if (!externalId) return null;
  const carNumber = isNormal
    ? text(
      row?.car?.car_identity
      || row?.car_identity
      || row?.car_number
      || normalReservation?.car?.car_identity
      || normalReservation?.car_identity
      || normalReservation?.car_number,
    )
    : text(row?.rent_car_number || row?.car_number || row?.car?.car_identity);
  return {
    key: snapshotKey(normalizedSourceType, externalId),
    source_type: normalizedSourceType,
    external_id: externalId,
    external_detail_id: isNormal
      ? text(normalReservation?.id || row?.detail_id || row?.reservation_id)
      : externalId,
    car_number: carNumber,
    customer_name: isNormal
      ? text(normalReservation?.customer_name || row?.customer_name)
      : text(row?.customer_name),
    rental_at: normalizeImsDateTime(isNormal ? row?.start_at : row?.delivered_at),
    return_at: normalizeImsDateTime(isNormal ? row?.end_at : row?.expect_return_date || row?.return_date),
    raw_status: isNormal
      ? text(row?.status || row?.state || normalReservation?.status || normalReservation?.state)
      : text(row?.claim_state || row?.state || row?.status),
    raw_payload_json: row,
    snapshot_seen_at: toIsoString(seenAt),
    active: true,
  };
}

export function normalizeUsingCarSnapshotRows({ normalRows = [], insuranceRows = [], seenAt = new Date() } = {}) {
  return [
    ...normalRows.map((row) => normalizeUsingCarSnapshotRow(SOURCE_TYPES.normal, row, { seenAt })),
    ...insuranceRows.map((row) => normalizeUsingCarSnapshotRow(SOURCE_TYPES.insurance, row, { seenAt })),
  ].filter(Boolean);
}

export function buildSnapshotDiff({
  previousRows = [],
  currentRows = [],
  collectionErrors = [],
  minCurrentRatio = 0.5,
  allowEmptyCurrent = false,
} = {}) {
  const previous = dedupeSnapshotRows(previousRows).filter((row) => row.active !== false);
  const current = dedupeSnapshotRows(currentRows);
  const quality = evaluateSnapshotQuality({
    previousCount: previous.length,
    currentCount: current.length,
    collectionErrors,
    minCurrentRatio,
    allowEmptyCurrent,
  });
  if (!quality.ok) {
    return {
      status: 'snapshot_invalid',
      bootstrap: false,
      quality,
      appeared: [],
      disappeared: [],
      unchanged: [],
    };
  }
  if (previous.length === 0) {
    return {
      status: 'bootstrap',
      bootstrap: true,
      quality,
      appeared: [],
      disappeared: [],
      unchanged: [],
      bootstrapRows: current,
    };
  }

  const previousByKey = new Map(previous.map((row) => [row.key || snapshotKey(row.source_type, row.external_id), row]));
  const currentByKey = new Map(current.map((row) => [row.key || snapshotKey(row.source_type, row.external_id), row]));
  const appeared = [];
  const disappeared = [];
  const unchanged = [];

  for (const [key, row] of currentByKey.entries()) {
    if (!previousByKey.has(key)) appeared.push({ diffKind: 'appeared', row });
    else unchanged.push({ diffKind: 'unchanged', row, previous: previousByKey.get(key) });
  }
  for (const [key, row] of previousByKey.entries()) {
    if (!currentByKey.has(key)) disappeared.push({ diffKind: 'disappeared', row });
  }

  return {
    status: 'diff',
    bootstrap: false,
    quality,
    appeared,
    disappeared,
    unchanged,
  };
}

export function evaluateSnapshotQuality({
  previousCount = 0,
  currentCount = 0,
  collectionErrors = [],
  minCurrentRatio = 0.5,
  allowEmptyCurrent = false,
} = {}) {
  if (collectionErrors.length > 0) {
    return { ok: false, reason: 'collection_error', previousCount, currentCount, collectionErrors };
  }
  if (!allowEmptyCurrent && previousCount > 0 && currentCount === 0) {
    return { ok: false, reason: 'empty_current_snapshot', previousCount, currentCount, collectionErrors };
  }
  if (previousCount > 0 && currentCount / previousCount < minCurrentRatio) {
    return { ok: false, reason: 'current_snapshot_count_drop', previousCount, currentCount, collectionErrors };
  }
  return { ok: true, reason: 'ok', previousCount, currentCount, collectionErrors };
}

export async function collectCurrentUsingCarSnapshot({
  token,
  startDate,
  endDate,
  maxPages = 20,
  fetchNormalUsingCar = fetchImsUsingCarNormalSchedules,
  fetchInsuranceUsingCar = fetchImsUsingCarInsuranceClaims,
  seenAt = new Date(),
} = {}) {
  const [normal, insurance] = await Promise.all([
    fetchNormalUsingCar({ token, startDate, endDate, maxPages }),
    fetchInsuranceUsingCar({ token, startDate, endDate, maxPages }),
  ]);
  return {
    rows: normalizeUsingCarSnapshotRows({
      normalRows: normal.rows || [],
      insuranceRows: insurance.rows || [],
      seenAt,
    }),
    collection: { normal, insurance },
    errors: [
      ...(normal.errors || []).map((message) => ({ sourceType: SOURCE_TYPES.normal, message })),
      ...(insurance.errors || []).map((message) => ({ sourceType: SOURCE_TYPES.insurance, message })),
    ],
  };
}

export async function buildUsingCarSnapshotDiffReport(options = {}) {
  const mode = text(options.mode || 'report');
  if (mode === 'send-events') {
    throw new Error('send_events_disabled');
  }
  if (options.allowOpsHandoffSend === true) {
    throw new Error('ops_handoff_send_disabled');
  }
  const shouldWriteSnapshot = mode === 'save-snapshot' || mode === 'save-signals';
  if (shouldWriteSnapshot && options.allowDbWrite !== true) {
    throw new Error('allow_db_write_required');
  }

  const config = options.config || buildConfig(process.env);
  const current = options.currentSnapshot
    || await collectCurrentSnapshotForReport({ ...options, config });
  const previousRows = options.previousRows
    || (options.loadPreviousFromDb ? await fetchActiveSnapshotRows({ config }) : []);
  const diff = buildSnapshotDiff({
    previousRows,
    currentRows: current.rows || [],
    collectionErrors: current.errors || [],
    minCurrentRatio: options.minCurrentRatio ?? 0.5,
    allowEmptyCurrent: options.allowEmptyCurrent === true,
  });

  const signals = await verifyDiffCandidates({
    diff,
    token: options.token || null,
    getToken: options.getToken || null,
    links: options.links,
    reservations: options.reservations,
    schedules: options.schedules,
    fetchNormalDetail: options.fetchNormalDetail || fetchImsNormalScheduleDetail,
    fetchInsuranceDetail: options.fetchInsuranceDetail || fetchImsInsuranceClaimDetail,
    fetchLinksByExternalIds: options.fetchLinksByExternalIds || fetchExactImsLinksBySnapshotRows,
    fetchReservationsByIds: options.fetchReservationsByIds || fetchReservationsByIds,
    fetchSchedulesByReservationIds: options.fetchSchedulesByReservationIds || fetchSchedulesByReservationIds,
    config,
  });

  let snapshotSave = { status: 'skipped', count: 0 };
  const signalSave = {
    status: 'disabled',
    count: 0,
    reason: 'automatic_lifecycle_disabled',
  };
  const handoffSend = {
    status: 'disabled',
    sent: 0,
    failed: 0,
    skipped: signals.filter((row) => row.status === 'signal').length,
    reason: 'automatic_lifecycle_disabled',
    results: [],
  };
  if (shouldWriteSnapshot) {
    snapshotSave = await saveSnapshotRows({ config, rows: current.rows || [], diff });
  }

  return {
    schemaVersion: 'ims-using-car-snapshot-diff.report.v1',
    mode,
    readOnly: !shouldWriteSnapshot,
    writeApplied: shouldWriteSnapshot,
    currentCount: current.rows?.length || 0,
    previousCount: previousRows.length,
    diffStatus: diff.status,
    quality: diff.quality,
    appearedCount: diff.appeared.length,
    disappearedCount: diff.disappeared.length,
    unchangedCount: diff.unchanged.length,
    detailCandidateCount: diff.appeared.length + diff.disappeared.length,
    signalCount: signals.filter((row) => row.status === 'signal').length,
    signals,
    snapshotSave,
    signalSave,
    handoffSend,
    secretValuesPrinted: false,
    rawPayloadPrinted: false,
  };
}

export async function verifyDiffCandidates({
  diff,
  token,
  getToken,
  links,
  reservations,
  schedules,
  fetchNormalDetail,
  fetchInsuranceDetail,
  fetchLinksByExternalIds,
  fetchReservationsByIds: fetchReservations,
  fetchSchedulesByReservationIds: fetchSchedules,
  config,
} = {}) {
  if (!diff || diff.status !== 'diff') return [];
  const candidates = [...diff.appeared, ...diff.disappeared];
  if (candidates.length === 0) return [];
  const candidateRows = candidates.map((candidate) => candidate.row);
  const linkMap = links || await fetchLinksByExternalIds({ config, rows: candidateRows });
  const linkRows = [...linkMap.values()].filter(Boolean);
  const reservationIds = linkRows.map((row) => row.reservation_id).filter(Boolean);
  const reservationMap = reservations || await fetchReservations({ config, reservationIds });
  const scheduleMap = schedules || await fetchSchedules({ config, reservationIds });
  let cachedToken = token || null;
  const resolveToken = async () => {
    if (cachedToken) return cachedToken;
    if (getToken) {
      cachedToken = await getToken();
      return cachedToken;
    }
    cachedToken = await fetchImsAccessToken();
    return cachedToken;
  };

  const results = [];
  for (const candidate of candidates) {
    results.push(await inspectDiffCandidate({
      candidate,
      token: cachedToken,
      getToken: resolveToken,
      links: linkMap,
      reservations: reservationMap,
      schedules: scheduleMap,
      fetchNormalDetail,
      fetchInsuranceDetail,
    }));
  }
  return results;
}

export async function inspectDiffCandidate({
  candidate,
  token,
  getToken,
  links = new Map(),
  reservations = new Map(),
  schedules = new Map(),
  fetchNormalDetail,
  fetchInsuranceDetail,
} = {}) {
  const row = candidate?.row || {};
  const sourceType = normalizeSourceType(row.source_type);
  const externalId = text(row.external_id);
  const base = {
    diffKind: candidate?.diffKind || '',
    sourceType,
    externalId,
    status: '',
    reason: '',
    eventId: null,
    eventType: null,
    scheduleId: null,
    scheduleType: null,
    detailFetched: false,
  };
  if (!sourceType || !externalId) return { ...base, status: 'manual_review', reason: 'snapshot_identity_missing' };

  const link = links.get(snapshotKey(sourceType, externalId)) || null;
  if (!link) return { ...base, status: 'manual_review', reason: 'exact_link_not_found' };
  const reservation = reservations.get(text(link.reservation_id)) || null;
  if (!reservation) return { ...base, status: 'manual_review', reason: 'ops_reservation_not_found' };
  const reservationSchedules = schedules.get(text(link.reservation_id)) || [];

  let detail;
  try {
    const apiToken = token || await getToken();
    if (sourceType === SOURCE_TYPES.normal) {
      detail = await fetchNormalDetail({ token: apiToken, scheduleId: externalId });
    } else {
      detail = await fetchInsuranceDetail({ token: apiToken, claimId: externalId });
    }
  } catch (error) {
    return { ...base, status: 'lookup_failed', reason: error?.message || String(error), detailFetched: true };
  }

  const classification = sourceType === SOURCE_TYPES.normal
    ? classifyNormalDiffCandidate({ candidate, link, reservation, schedules: reservationSchedules, detail })
    : classifyInsuranceDiffCandidate({ candidate, link, reservation, schedules: reservationSchedules, claim: detail });

  return {
    ...base,
    status: classification.status,
    reason: classification.reason,
    eventId: classification.event?.eventId || null,
    eventType: classification.event?.eventType || null,
    scheduleId: classification.schedule?.id || null,
    scheduleType: classification.scheduleType || null,
    imsStatus: classification.imsStatus || null,
    detailFetched: true,
    event: classification.event || null,
  };
}

export function classifyNormalDiffCandidate({ candidate = {}, link = {}, reservation = {}, schedules = [], detail = {} } = {}) {
  const diffKind = candidate.diffKind;
  const imsStatus = normalizeToken(readImsNormalScheduleStatus(detail));
  const imsCarNumber = readImsNormalScheduleCarNumber(detail);
  const opsCarNumber = reservation.car_number || reservation.carNumber || '';
  if (imsCarNumber && opsCarNumber && normalizeCarNumber(imsCarNumber) !== normalizeCarNumber(opsCarNumber)) {
    return manualReview('normal_schedule_car_mismatch', { imsStatus });
  }
  if (diffKind === 'appeared') {
    if (imsStatus !== 'using_car') return noSignal(`appeared_status_${imsStatus || 'unknown'}`, { imsStatus });
    return buildScheduleSignalCandidate({
      eventKind: 'dispatch',
      scheduleType: '배차',
      reason: 'snapshot_appeared_using_car',
      imsStatus,
      diffKind,
      link,
      reservation,
      schedules,
    });
  }
  if (diffKind === 'disappeared') {
    if (imsStatus === 'returned') {
      return buildScheduleSignalCandidate({
        eventKind: 'return',
        scheduleType: '반납',
        reason: 'snapshot_disappeared_returned',
        imsStatus,
        diffKind,
        link,
        reservation,
        schedules,
      });
    }
    if (imsStatus === 'overdue_return') return noSignal('snapshot_disappeared_overdue_return', { imsStatus });
    return manualReview(`snapshot_disappeared_status_${imsStatus || 'unknown'}`, { imsStatus });
  }
  return noSignal('diff_kind_not_actionable', { imsStatus });
}

export function classifyInsuranceDiffCandidate({ candidate = {}, link = {}, reservation = {}, schedules = [], claim = {} } = {}) {
  const diffKind = candidate.diffKind;
  const imsStatus = normalizeToken(readImsInsuranceClaimState(claim));
  if (diffKind === 'appeared') {
    const dispatchRows = schedules.filter((row) => text(row.schedule_type) === '배차');
    if (dispatchRows.some((row) => row.schedule_done === true)) {
      return alreadyApplied('insurance_dispatch_already_done', { imsStatus });
    }
    return manualReview('insurance_dispatch_not_completed_locally', { imsStatus });
  }
  if (diffKind === 'disappeared') {
    if (imsStatus !== 'send_claim' && imsStatus !== 'done_claim') {
      return manualReview(`insurance_disappeared_status_${imsStatus || 'unknown'}`, { imsStatus });
    }
    const contractMatch = findMatchingInsuranceReturnContract({
      claim,
      carNumber: reservation.car_number || reservation.carNumber || '',
    });
    if (!contractMatch.ok) return manualReview(contractMatch.reason, { imsStatus });
    return buildScheduleSignalCandidate({
      eventKind: 'return',
      scheduleType: '반납',
      reason: 'snapshot_disappeared_insurance_returned',
      imsStatus,
      imsReturnAt: contractMatch.returnDate,
      diffKind,
      link,
      reservation,
      schedules,
    });
  }
  return noSignal('diff_kind_not_actionable', { imsStatus });
}

export function buildScheduleSignalCandidate({
  eventKind,
  scheduleType,
  reason,
  imsStatus,
  imsReturnAt = '',
  diffKind,
  link,
  reservation,
  schedules = [],
} = {}) {
  const rows = schedules.filter((row) => text(row.schedule_type) === scheduleType);
  const pendingRows = rows.filter((row) => row.schedule_done !== true);
  if (pendingRows.length === 0) {
    if (rows.some((row) => row.schedule_done === true)) return alreadyApplied(`${scheduleType}_schedule_already_done`, { imsStatus });
    return manualReview(`${scheduleType}_schedule_not_found`, { imsStatus });
  }
  if (pendingRows.length > 1) return manualReview(`${scheduleType}_schedule_ambiguous`, { imsStatus });
  const schedule = pendingRows[0];
  return {
    status: 'signal',
    reason,
    eventKind,
    eventType: LIFECYCLE_EVENT_TYPES[eventKind],
    scheduleType,
    schedule,
    imsStatus,
    event: buildLifecycleEventPayload({
      eventKind,
      eventType: LIFECYCLE_EVENT_TYPES[eventKind],
      scheduleType,
      reason,
      imsStatus,
      imsReturnAt,
      diffKind,
      link,
      reservation,
      schedule,
    }),
  };
}

export function buildLifecycleEventPayload({
  eventKind,
  eventType,
  scheduleType,
  reason,
  imsStatus,
  imsReturnAt = '',
  diffKind,
  link = {},
  reservation = {},
  schedule = {},
  now = new Date(),
} = {}) {
  const sourceType = normalizeSourceType(link.source_type);
  const externalId = text(link.external_reservation_id);
  const reservationId = text(link.reservation_id || reservation.reservation_id);
  const eventId = `ims.lifecycle.${eventKind}:${sourceType}:${externalId}:${reservationId}:${scheduleType}`;
  return {
    eventId,
    eventType,
    occurredAt: now.toISOString(),
    source: 'rentcar00_OPS.ims-using-car-snapshot-diff',
    diffKind,
    ims: {
      sourceType,
      externalId,
      externalDetailId: text(link.external_detail_id),
      status: imsStatus || null,
      reason,
      returnAt: imsReturnAt || null,
    },
    ops: {
      reservationId,
      reservationRefId: text(link.reservation_ref_id || reservation.id),
      scheduleId: text(schedule.id),
      scheduleType,
      carNumber: text(reservation.car_number),
    },
    link: {
      id: text(link.id),
      linkKey: text(link.link_key),
    },
    rawPayloadPrinted: false,
    secretValuesPrinted: false,
  };
}

async function collectCurrentSnapshotForReport(options = {}) {
  if (options.currentSnapshot) return options.currentSnapshot;
  const token = options.token || await (options.fetchImsAccessToken || fetchImsAccessToken)();
  return collectCurrentUsingCarSnapshot({
    token,
    startDate: options.startDate || '',
    endDate: options.endDate || '',
    maxPages: toPositiveInt(options.maxPages, 20),
    fetchNormalUsingCar: options.fetchNormalUsingCar || fetchImsUsingCarNormalSchedules,
    fetchInsuranceUsingCar: options.fetchInsuranceUsingCar || fetchImsUsingCarInsuranceClaims,
  });
}

async function fetchActiveSnapshotRows({ config } = {}) {
  const url = new URL('/rest/v1/rc00_ops_ims_using_car_snapshots', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('select', 'source_type,external_id,external_detail_id,car_number,customer_name,rental_at,return_at,raw_status,raw_payload_json,last_seen_at,active');
  url.searchParams.set('active', 'eq.true');
  url.searchParams.set('limit', '5000');
  const rows = await supabaseJson({ config, url });
  return (Array.isArray(rows) ? rows : []).map((row) => ({
    ...row,
    key: snapshotKey(row.source_type, row.external_id),
  }));
}

async function fetchExactImsLinksBySnapshotRows({ config, rows = [] } = {}) {
  const idsBySource = groupExternalIdsBySource(rows);
  const linkMap = new Map();
  for (const [sourceType, ids] of idsBySource.entries()) {
    if (ids.length === 0) continue;
    const url = new URL('/rest/v1/rc00_ops_external_reservation_links', normalizeSupabaseBaseUrl(config.supabaseUrl));
    url.searchParams.set('select', 'id,reservation_id,reservation_ref_id,source_type,external_reservation_id,external_detail_id,external_status,link_key,deleted_at');
    url.searchParams.set('provider', 'eq.ims');
    url.searchParams.set('external_status', 'eq.linked');
    url.searchParams.set('source_type', `eq.${sourceType}`);
    url.searchParams.set('external_reservation_id', `in.(${ids.map(escapePostgrestListValue).join(',')})`);
    url.searchParams.set('deleted_at', 'is.null');
    url.searchParams.set('limit', '1000');
    const fetched = await supabaseJson({ config, url });
    for (const link of Array.isArray(fetched) ? fetched : []) {
      linkMap.set(snapshotKey(link.source_type, link.external_reservation_id), link);
    }
  }
  return linkMap;
}

async function fetchReservationsByIds({ config, reservationIds = [] } = {}) {
  const ids = unique(reservationIds);
  if (ids.length === 0) return new Map();
  const url = new URL('/rest/v1/rc00_ops_reservations', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('select', 'id,reservation_id,reservation_status,car_number,start_at,end_at,customer_name');
  url.searchParams.set('reservation_id', `in.(${ids.map(escapePostgrestListValue).join(',')})`);
  url.searchParams.set('limit', '1000');
  const rows = await supabaseJson({ config, url });
  return new Map((Array.isArray(rows) ? rows : []).map((row) => [text(row.reservation_id), row]));
}

async function fetchSchedulesByReservationIds({ config, reservationIds = [] } = {}) {
  const ids = unique(reservationIds);
  if (ids.length === 0) return new Map();
  const url = new URL('/rest/v1/rc00_ops_schedules', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('select', 'id,reservation_id,schedule_type,schedule_at,schedule_done,car_number');
  url.searchParams.set('reservation_id', `in.(${ids.map(escapePostgrestListValue).join(',')})`);
  url.searchParams.set('limit', '2000');
  const rows = await supabaseJson({ config, url });
  const byReservationId = new Map();
  for (const row of Array.isArray(rows) ? rows : []) {
    const key = text(row.reservation_id);
    byReservationId.set(key, [...(byReservationId.get(key) || []), row]);
  }
  return byReservationId;
}

async function saveSnapshotRows({ config, rows = [], diff = {} } = {}) {
  const url = new URL('/rest/v1/rc00_ops_ims_using_car_snapshots', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('on_conflict', 'source_type,external_id');
  url.searchParams.set('select', 'source_type,external_id');
  const now = new Date().toISOString();
  const currentRows = rows.map((row) => ({
    source_type: row.source_type,
    external_id: row.external_id,
    external_detail_id: row.external_detail_id || null,
    car_number: row.car_number || null,
    customer_name: row.customer_name || null,
    rental_at: row.rental_at || null,
    return_at: row.return_at || null,
    raw_status: row.raw_status || null,
    raw_payload_json: row.raw_payload_json || {},
    first_seen_at: now,
    last_seen_at: now,
    missing_since: null,
    active: true,
    updated_at: now,
  }));
  const disappearedRows = (diff.disappeared || []).map((candidate) => ({
    source_type: candidate.row.source_type,
    external_id: candidate.row.external_id,
    external_detail_id: candidate.row.external_detail_id || null,
    car_number: candidate.row.car_number || null,
    customer_name: candidate.row.customer_name || null,
    rental_at: candidate.row.rental_at || null,
    return_at: candidate.row.return_at || null,
    raw_status: candidate.row.raw_status || null,
    raw_payload_json: candidate.row.raw_payload_json || {},
    first_seen_at: candidate.row.first_seen_at || now,
    last_seen_at: candidate.row.last_seen_at || now,
    missing_since: now,
    active: false,
    updated_at: now,
  }));
  const body = [...currentRows, ...disappearedRows];
  if (body.length === 0) return { status: 'skipped_empty', count: 0 };
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      ...buildSupabaseServiceHeaders(config),
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) throw new Error(resolveSupabaseErrorMessage(json, response.status, 'snapshot upsert failed'));
  return { status: 'saved', count: Array.isArray(json) ? json.length : body.length };
}

async function supabaseJson({ config, url }) {
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders(config) });
  const json = await readJsonResponse(response);
  if (!response.ok) throw new Error(resolveSupabaseErrorMessage(json, response.status, 'Supabase lookup failed'));
  return json;
}

function buildSupabaseServiceHeaders(config = {}) {
  return {
    apikey: config.supabaseServiceRoleKey,
    Authorization: `Bearer ${config.supabaseServiceRoleKey}`,
  };
}

function normalizeSupabaseBaseUrl(value) {
  return text(value).replace(/\/$/, '');
}

function resolveSupabaseErrorMessage(json, status, fallback) {
  return text(json?.message || json?.msg || json?.error || json?.detail || json?.raw) || `${fallback} (${status})`;
}

function groupExternalIdsBySource(rows = []) {
  const map = new Map();
  for (const row of rows) {
    const sourceType = normalizeSourceType(row.source_type);
    const externalId = text(row.external_id);
    if (!sourceType || !externalId) continue;
    map.set(sourceType, [...(map.get(sourceType) || []), externalId]);
  }
  return new Map([...map.entries()].map(([sourceType, ids]) => [sourceType, unique(ids)]));
}

function dedupeSnapshotRows(rows = []) {
  const map = new Map();
  for (const row of rows) {
    const sourceType = normalizeSourceType(row.source_type);
    const externalId = text(row.external_id);
    if (!sourceType || !externalId) continue;
    map.set(snapshotKey(sourceType, externalId), {
      ...row,
      key: snapshotKey(sourceType, externalId),
      source_type: sourceType,
      external_id: externalId,
    });
  }
  return [...map.values()];
}

function snapshotKey(sourceType, externalId) {
  return `${normalizeSourceType(sourceType)}:${text(externalId)}`;
}

function noSignal(reason, extra = {}) {
  return { status: 'no_signal', reason, ...extra };
}

function manualReview(reason, extra = {}) {
  return { status: 'manual_review', reason, ...extra };
}

function alreadyApplied(reason, extra = {}) {
  return { status: 'already_applied', reason, ...extra };
}

function normalizeToken(value) {
  return text(value).trim().toLowerCase();
}

function unique(values = []) {
  return [...new Set(values.map(text).filter(Boolean))];
}

function escapePostgrestListValue(value) {
  return `"${text(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function toPositiveInt(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function toIsoString(value) {
  if (value instanceof Date) return value.toISOString();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
}

function text(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}

async function main() {
  await loadEnvFile(path.resolve(__dirname, '../.env'));
  const args = parseArgs();
  const report = await buildUsingCarSnapshotDiffReport({
    mode: args.mode || 'report',
    allowDbWrite: args.allowDbWrite === true || args.allowDbWrite === 'true',
    loadPreviousFromDb: args.loadPreviousFromDb === true || args.loadPreviousFromDb === 'true',
    startDate: args.startDate || '',
    endDate: args.endDate || '',
    maxPages: args.maxPages || 20,
    env: process.env,
  });
  console.log(JSON.stringify(report, null, 2));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(JSON.stringify({
      ok: false,
      error: error?.message || String(error),
      secretValuesPrinted: false,
      rawPayloadPrinted: false,
    }, null, 2));
    process.exitCode = 1;
  });
}
