import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const SIGNAL_TYPES = Object.freeze({
  DISPATCH_DETECTED: 'dispatch_detected',
  RETURN_DETECTED: 'return_detected',
  RETURN_OVERDUE: 'return_overdue',
  NO_CHANGE: 'no_change',
  MANUAL_REVIEW: 'manual_review',
  LOOKUP_FAILED: 'lookup_failed',
});

export function classifyImsLifecycleSignal({ imsStatus, imsStatusRaw, duplicateImsLink = false, opsReservationStatus = '', opsDispatchDone = false, opsReturnDone = false } = {}) {
  if (duplicateImsLink) {
    return { signalType: SIGNAL_TYPES.MANUAL_REVIEW, reason: 'duplicate_ims_link' };
  }

  const normalizedRaw = normalizeToken(imsStatusRaw);
  const normalizedStatus = normalizeToken(imsStatus);
  const normalizedOpsStatus = normalizeText(opsReservationStatus);

  if (normalizedRaw === 'returned' || normalizedStatus === 'completed') {
    if (opsReturnDone || normalizedOpsStatus === '완료') {
      return { signalType: SIGNAL_TYPES.NO_CHANGE, reason: 'ops_return_already_done' };
    }
    return { signalType: SIGNAL_TYPES.RETURN_DETECTED, reason: 'ims_returned' };
  }

  if (normalizedRaw === 'using_car') {
    if (opsDispatchDone || normalizedOpsStatus === '배차중' || normalizedOpsStatus === '완료') {
      return { signalType: SIGNAL_TYPES.NO_CHANGE, reason: 'ops_dispatch_already_done' };
    }
    return { signalType: SIGNAL_TYPES.DISPATCH_DETECTED, reason: 'ims_using_car' };
  }

  if (normalizedRaw === 'overdue_return') {
    return { signalType: SIGNAL_TYPES.RETURN_OVERDUE, reason: 'ims_overdue_return' };
  }

  return { signalType: SIGNAL_TYPES.NO_CHANGE, reason: normalizedRaw || normalizedStatus || 'unknown_status' };
}

export function buildDuplicateImsIdSet(links = []) {
  const counts = new Map();
  for (const link of links) {
    const imsId = stringify(link.external_reservation_id);
    if (!imsId) continue;
    counts.set(imsId, (counts.get(imsId) || 0) + 1);
  }
  return new Set([...counts.entries()].filter(([, count]) => count > 1).map(([imsId]) => imsId));
}

export async function buildImsLinkedLifecycleReport({ config = buildConfig(process.env), limit = 50, includeLiveIms = true } = {}) {
  const links = await fetchLinkedImsLinks({ config, limit });
  const duplicateImsIds = buildDuplicateImsIdSet(links.allLinkedForDuplicateCheck);
  const reservationsById = await fetchReservationsByIds({ config, reservationIds: links.rows.map((row) => row.reservation_id).filter(Boolean) });
  const schedulesByReservationId = await fetchSchedulesByReservationIds({ config, reservationIds: links.rows.map((row) => row.reservation_id).filter(Boolean) });
  const token = includeLiveIms && links.rows.length > 0 ? await fetchImsAccessToken() : null;

  const rows = [];
  for (const link of links.rows) {
    const reservation = reservationsById.get(stringify(link.reservation_id));
    const schedules = schedulesByReservationId.get(stringify(link.reservation_id)) || [];
    const dispatchSchedule = schedules.find((row) => row.schedule_type === '배차');
    const returnSchedule = schedules.find((row) => row.schedule_type === '반납');
    let imsDetail = null;
    let lookupError = null;

    if (token && link.external_reservation_id) {
      try {
        imsDetail = await fetchImsScheduleDetail({ token, scheduleId: link.external_reservation_id });
      } catch (error) {
        lookupError = error?.message || String(error);
      }
    }

    const imsStatus = extractImsStatus(imsDetail);
    const imsStatusRaw = extractImsStatusRaw(imsDetail);
    const duplicateImsLink = duplicateImsIds.has(stringify(link.external_reservation_id));
    const classification = lookupError
      ? { signalType: SIGNAL_TYPES.LOOKUP_FAILED, reason: 'ims_lookup_failed' }
      : classifyImsLifecycleSignal({
          imsStatus,
          imsStatusRaw,
          duplicateImsLink,
          opsReservationStatus: reservation?.reservation_status,
          opsDispatchDone: dispatchSchedule?.schedule_done === true,
          opsReturnDone: returnSchedule?.schedule_done === true,
        });

    rows.push({
      reservationId: stringify(link.reservation_id),
      reservationRefId: stringify(link.reservation_ref_id),
      imsScheduleId: stringify(link.external_reservation_id),
      imsDetailId: stringify(link.external_detail_id),
      duplicateImsLink,
      opsReservationStatus: stringify(reservation?.reservation_status),
      opsDispatchDone: dispatchSchedule?.schedule_done === true,
      opsReturnDone: returnSchedule?.schedule_done === true,
      imsStatus: stringify(imsStatus),
      imsStatusRaw: stringify(imsStatusRaw),
      signalType: classification.signalType,
      reason: classification.reason,
      lookupError,
    });
  }

  const counts = rows.reduce((acc, row) => {
    acc[row.signalType] = (acc[row.signalType] || 0) + 1;
    return acc;
  }, {});

  return {
    schemaVersion: 'ims-linked-lifecycle-watcher.report.v1',
    mode: 'read-only',
    writeApplied: false,
    inspectedCount: rows.length,
    totalLinkedCount: links.totalLinkedCount,
    duplicateImsLinkCount: duplicateImsIds.size,
    counts,
    rows,
  };
}

async function fetchLinkedImsLinks({ config, limit }) {
  const totalRows = await supabaseGet({
    config,
    table: 'rc00_ops_external_reservation_links',
    params: {
      select: 'id,reservation_id,reservation_ref_id,external_reservation_id,external_detail_id,external_status,updated_at',
      provider: 'eq.ims',
      external_status: 'eq.linked',
      external_reservation_id: 'not.is.null',
      order: 'updated_at.desc',
      limit: '1000',
    },
  });
  return {
    totalLinkedCount: totalRows.length,
    allLinkedForDuplicateCheck: totalRows,
    rows: totalRows.slice(0, limit),
  };
}

async function fetchReservationsByIds({ config, reservationIds }) {
  const ids = unique(reservationIds);
  if (ids.length === 0) return new Map();
  const rows = await supabaseGet({
    config,
    table: 'rc00_ops_reservations',
    params: {
      select: 'id,reservation_id,reservation_status,start_at,end_at,car_number,customer_name',
      reservation_id: `in.(${ids.map(escapePostgrestListValue).join(',')})`,
      limit: '1000',
    },
  });
  return new Map(rows.map((row) => [stringify(row.reservation_id), row]));
}

async function fetchSchedulesByReservationIds({ config, reservationIds }) {
  const ids = unique(reservationIds);
  if (ids.length === 0) return new Map();
  const rows = await supabaseGet({
    config,
    table: 'rc00_ops_schedules',
    params: {
      select: 'id,reservation_id,schedule_type,schedule_at,schedule_done,partial_return_at',
      reservation_id: `in.(${ids.map(escapePostgrestListValue).join(',')})`,
      limit: '2000',
    },
  });
  const map = new Map();
  for (const row of rows) {
    const key = stringify(row.reservation_id);
    map.set(key, [...(map.get(key) || []), row]);
  }
  return map;
}

async function supabaseGet({ config, table, params }) {
  const url = new URL(`/rest/v1/${table}`, normalizeSupabaseBaseUrl(config.supabaseUrl));
  for (const [key, value] of Object.entries(params || {})) url.searchParams.set(key, value);
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders(config) });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new Error(`${table} lookup failed: ${resolveApiErrorMessage(json, response.status)}`);
  }
  return Array.isArray(json) ? json : [];
}

async function fetchImsScheduleDetail({ token, scheduleId }) {
  const response = await fetch(
    `https://api.rencar.co.kr/v2/company-car-schedules/${encodeURIComponent(scheduleId)}`,
    { headers: buildImsApiHeaders(token) },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) throw new Error(resolveApiErrorMessage(json, response.status, 'IMS schedule detail lookup failed'));
  return json?.schedule || json;
}

async function fetchImsAccessToken() {
  const username = stringify(process.env.IMS_ID).trim();
  const rawPassword = stringify(process.env.IMS_PW || process.env.IMS_PASSWORD).trim();
  if (!username || !rawPassword) throw new Error('missing IMS_ID or IMS_PW');
  const password = /^[a-f0-9]{64}$/i.test(rawPassword)
    ? rawPassword
    : crypto.createHash('sha256').update(rawPassword).digest('hex');
  const response = await fetch('https://api.rencar.co.kr/auth', {
    method: 'POST',
    headers: buildImsApiHeaders('', { contentType: true, auth: false }),
    body: JSON.stringify({ username, password }),
  });
  const json = await readJsonResponse(response);
  const token = stringify(json?.access_token);
  if (!response.ok || !token) throw new Error(resolveApiErrorMessage(json, response.status, 'IMS auth failed'));
  return token;
}

function extractImsStatus(detail) {
  return detail?.status || detail?.state || detail?.reservation?.status || detail?.detail?.status || '';
}

function extractImsStatusRaw(detail) {
  return detail?.status_raw || detail?.state_raw || detail?.reservation?.status_raw || detail?.reservation?.status || detail?.detail?.status_raw || detail?.detail?.status || detail?.status || detail?.state || '';
}

function buildImsApiHeaders(token, { contentType = false, auth = true } = {}) {
  return {
    Accept: 'application/json, text/plain, */*',
    Origin: 'https://imsform.com',
    Referer: 'https://imsform.com/',
    ...(contentType ? { 'Content-Type': 'application/json;charset=UTF-8' } : {}),
    ...(auth && token ? { Authorization: `JWT ${token}` } : {}),
  };
}

function buildSupabaseServiceHeaders(config) {
  return {
    apikey: config.supabaseServiceRoleKey,
    Authorization: `Bearer ${config.supabaseServiceRoleKey}`,
  };
}

function normalizeSupabaseBaseUrl(value) {
  return String(value || '').replace(/\/+$/, '');
}

async function readJsonResponse(response) {
  const text = await response.text();
  if (!text) return {};
  try { return JSON.parse(text); } catch { return { raw: text }; }
}

function resolveApiErrorMessage(json, status, fallback = 'API failed') {
  return stringify(json?.message || json?.msg || json?.error || json?.detail || json?.raw) || `${fallback} (${status})`;
}

function stringify(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}

function normalizeToken(value) {
  return stringify(value).trim().toLowerCase();
}

function normalizeText(value) {
  return stringify(value).replace(/\s+/g, '').trim();
}

function unique(values) {
  return [...new Set((values || []).map(stringify).filter(Boolean))];
}

function escapePostgrestListValue(value) {
  return `"${stringify(value).replace(/"/g, '\\"')}"`;
}

function parseArgs(argv) {
  const args = { limit: 50, includeLiveIms: true };
  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    if (item === '--limit') args.limit = Number(argv[++i] || args.limit);
    if (item === '--no-live-ims') args.includeLiveIms = false;
  }
  if (!Number.isInteger(args.limit) || args.limit < 1) args.limit = 50;
  return args;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await loadEnvFile(path.resolve(__dirname, '../.env'));
  const args = parseArgs(process.argv.slice(2));
  const report = await buildImsLinkedLifecycleReport(args);
  console.log(JSON.stringify(report, null, 2));
}
