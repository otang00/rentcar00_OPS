import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { PDFDocument, rgb } from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
import { buildConfig, loadEnvFile, parseReservationInput, validateConfig } from './parser-core.js';
import {
  buildConfig as buildFineNoticeConfig,
  parseFineNoticeInput,
} from '../../fine_notice_ai_parser/src/parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
await loadEnvFile(path.resolve(__dirname, '../.env'));

const config = buildConfig(process.env);
const fineNoticeConfig = buildFineNoticeConfig(process.env);

if (process.argv.includes('--check')) {
  console.log(JSON.stringify({
    hasOpenAiApiKey: Boolean(config.openAiApiKey),
    openAiModel: config.openAiModel,
    host: config.host,
    port: config.port,
    timeoutMs: config.timeoutMs,
    fineNoticeStorageRoot: config.fineNoticeStorageRoot,
    fineNoticeOpenAiModel: fineNoticeConfig.openAiModel,
    fineNoticeTimeoutMs: fineNoticeConfig.timeoutMs,
    hasOpsReservationEventSecret: Boolean(config.opsReservationEventSecret),
    hasSupabaseUrl: Boolean(config.supabaseUrl),
    hasSupabaseServiceRoleKey: Boolean(config.supabaseServiceRoleKey),
    reservationEventTimestampToleranceMs: config.reservationEventTimestampToleranceMs
  }, null, 2));
  process.exit(0);
}

validateConfig(config);

const server = http.createServer(async (req, res) => {
  try {
    const requestUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
    const pathname = requestUrl.pathname;
    if (req.url === '/health') {
      if (req.method !== 'GET') {
        return sendMethodNotAllowed(res, ['GET']);
      }
      return sendJson(res, 200, { ok: true, service: 'reservation_ai_parser' });
    }

    if (req.url === '/api/integrations/rentcar00/reservation-events') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const rawBody = await readRawBody(req);
      const result = await receiveRentcar00ReservationEvent({ req, rawBody });
      return sendJson(res, 200, result);
    }

    if (req.url === '/parse-reservation') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const result = await parseReservationInput({ text: body?.text }, config);
      return sendJson(res, 200, result);
    }

    if (req.url === '/parse-fine-notice') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req, 12 * 1024 * 1024);
      const result = await parseFineNoticeInput(body, fineNoticeConfig);
      return sendJson(res, 200, result);
    }

    if (req.url === '/ims/create-reservation') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsReservationPayload(body);
      const result = await createImsReservationDirect(payload);
      const bindingResult = await resolveImsReservationBindingAfterCreate({ payload, result });
      const ok = result?.code === 'SUCCESS' || result?.code === 'DRY_RUN';
      return sendJson(res, ok ? 200 : 422, {
        ok,
        payload,
        result: bindingResult,
      });
    }

    if (req.url === '/ims/search-reservations') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsReservationSearchPayload(body);
      const result = await searchImsReservationsForImport(payload);
      return sendJson(res, 200, { ok: true, payload, result });
    }

    if (req.url === '/ims/search-fine-notice-contracts') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeFineNoticeContractSearchPayload(body);
      const result = await searchFineNoticeContracts(payload);
      return sendJson(res, 200, { ok: true, payload, result });
    }

    if (req.url === '/ims/search-insurance-claims') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsInsuranceClaimSearchPayload(body);
      const result = await searchImsInsuranceClaimsForDispatch(payload);
      return sendJson(res, 200, { ok: true, payload, result });
    }

    if (req.url === '/fine-notices/save-contract-pdf') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeFineNoticeContractPdfPayload(body);
      const file = await saveFineNoticeContractPdf(payload);
      return sendJson(res, 200, { ok: true, file: toFineNoticeGeneratedFileResponse(file) });
    }

    if (req.url === '/fine-notices/generate-documents') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeFineNoticeDocumentPackagePayload(body);
      const result = await generateFineNoticeDocumentPackage(payload);
      return sendJson(res, 200, { ok: true, ...result });
    }

    if (pathname === '/fine-notice-file-packages') {
      if (req.method !== 'GET') {
        return sendMethodNotAllowed(res, ['GET']);
      }
      const fineNoticeId = stringifyNullable(requestUrl.searchParams.get('fineNoticeId')).trim();
      const result = await listFineNoticeFilePackage({ fineNoticeId });
      return sendJson(res, 200, { ok: true, ...result });
    }

    if (pathname === '/fine-notice-files/download') {
      if (req.method !== 'GET') {
        return sendMethodNotAllowed(res, ['GET']);
      }
      const fileId = stringifyNullable(requestUrl.searchParams.get('fileId')).trim();
      const result = await prepareFineNoticeFileDownload({ fileId });
      return sendLocalFile(res, result);
    }

    if (req.url === '/ims/change-reservation-car') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsChangeCarPayload(body);
      const result = await changeImsReservationCarDirect(payload);
      const ok = result?.code === 'SUCCESS' || result?.code === 'DRY_RUN';
      return sendJson(res, ok ? 200 : 422, { ok, payload, result });
    }

    if (req.url === '/ims/delete-reservation') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsDeleteReservationPayload(body);
      const result = await deleteImsReservationDirect(payload);
      const ok = result?.code === 'SUCCESS' || result?.code === 'DRY_RUN';
      return sendJson(res, ok ? 200 : 422, { ok, payload, result });
    }

    if (req.url === '/ims/complete-reservation-return') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsCompleteReturnPayload(body);
      const result = await completeImsReservationReturnDirect(payload);
      const ok = result?.code === 'SUCCESS' || result?.code === 'DRY_RUN';
      return sendJson(res, ok ? 200 : 422, { ok, payload, result });
    }

    return sendJson(res, 404, { ok: false, error: 'not_found' });
  } catch (error) {
    const status = resolveErrorStatus(error);
    return sendJson(res, status, {
      ok: false,
      error: resolveErrorCode(error),
      message: error?.message || 'unknown error'
    });
  }
});

server.listen(config.port, config.host, () => {
  console.log(`reservation_ai_parser listening on http://${config.host}:${config.port}`);
});

function readJsonBody(req, maxBytes = 5 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (Buffer.byteLength(data, 'utf8') > maxBytes) {
        reject(new Error('payload_too_large'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch {
        reject(new Error('invalid_json'));
      }
    });
    req.on('error', reject);
  });
}

function readRawBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      data += chunk;
      if (Buffer.byteLength(data, 'utf8') > 5 * 1024 * 1024) {
        reject(new Error('payload_too_large'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

async function receiveRentcar00ReservationEvent({ req, rawBody }) {
  ensureReservationEventReceiverConfigured();

  const eventType = getHeader(req, 'x-rentcar00-event-type');
  const eventId = getHeader(req, 'x-rentcar00-event-id');
  const timestamp = getHeader(req, 'x-rentcar00-timestamp');
  const signature = getHeader(req, 'x-rentcar00-signature');

  if (eventType !== 'reservation.created') {
    throw new ApiError(400, 'invalid_event_type', 'X-Rentcar00-Event-Type must be reservation.created');
  }
  if (!eventId) throw new ApiError(400, 'missing_event_id', 'X-Rentcar00-Event-Id is required');
  validateReservationEventTimestamp(timestamp);
  verifyReservationEventSignature({ timestamp, rawBody, signature });

  let body;
  try {
    body = rawBody ? JSON.parse(rawBody) : {};
  } catch {
    throw new ApiError(400, 'invalid_json', 'request body must be valid JSON');
  }
  const payload = normalizeReservationCreatedEventPayload({ body, eventId, eventType });

  const existing = await findStoredReservationEvent(eventId);
  if (existing?.status === 'imported') return { ok: true, deduped: true, imported: true };

  if (!existing) {
    try {
      await storeReservationEvent(payload);
    } catch (error) {
      if (!isSupabaseDuplicateError(error)) throw error;
    }
  }

  try {
    const importResult = await importReservationCreatedEvent(payload);
    await markReservationEventImported(payload.eventId, importResult);
    return { ok: true, deduped: Boolean(existing), imported: true, reservationId: importResult.reservationId };
  } catch (error) {
    await markReservationEventFailed(payload.eventId, error);
    throw error;
  }
}


function ensureReservationEventReceiverConfigured() {
  const missing = [];
  if (!config.opsReservationEventSecret) missing.push('OPS_APP_RESERVATION_EVENT_SECRET');
  if (!config.supabaseUrl) missing.push('SUPABASE_URL');
  if (!config.supabaseServiceRoleKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (missing.length > 0) {
    throw new ApiError(503, 'receiver_not_configured', `missing env: ${missing.join(', ')}`);
  }
}

function validateReservationEventTimestamp(timestamp) {
  const value = Number(timestamp);
  if (!Number.isFinite(value) || value <= 0) {
    throw new ApiError(400, 'invalid_timestamp', 'X-Rentcar00-Timestamp must be unix milliseconds');
  }
  const tolerance = Number.isFinite(config.reservationEventTimestampToleranceMs)
    ? config.reservationEventTimestampToleranceMs
    : 5 * 60 * 1000;
  if (Math.abs(Date.now() - value) > tolerance) {
    throw new ApiError(400, 'timestamp_out_of_range', 'event timestamp is outside allowed tolerance');
  }
}

function verifyReservationEventSignature({ timestamp, rawBody, signature }) {
  const actual = String(signature || '').trim();
  if (!actual.startsWith('sha256=')) {
    throw new ApiError(401, 'invalid_signature', 'X-Rentcar00-Signature is required');
  }
  const actualHex = actual.slice('sha256='.length);
  if (!/^[a-f0-9]{64}$/i.test(actualHex)) {
    throw new ApiError(401, 'invalid_signature', 'invalid signature format');
  }
  const expectedHex = crypto
    .createHmac('sha256', config.opsReservationEventSecret)
    .update(`${timestamp}.${rawBody}`)
    .digest('hex');
  const actualBuffer = Buffer.from(actualHex, 'hex');
  const expectedBuffer = Buffer.from(expectedHex, 'hex');
  if (actualBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(actualBuffer, expectedBuffer)) {
    throw new ApiError(401, 'invalid_signature', 'signature verification failed');
  }
}

function normalizeReservationCreatedEventPayload({ body, eventId, eventType }) {
  const bodyEventId = stringifyNullable(body?.eventId).trim();
  const bodyEventType = stringifyNullable(body?.eventType).trim();
  if (bodyEventId && bodyEventId !== eventId) {
    throw new ApiError(400, 'event_id_mismatch', 'header and body eventId do not match');
  }
  if (bodyEventType && bodyEventType !== eventType) {
    throw new ApiError(400, 'event_type_mismatch', 'header and body eventType do not match');
  }
  const booking = body?.booking && typeof body.booking === 'object' ? body.booking : null;
  if (!booking) throw new ApiError(400, 'invalid_payload', 'booking object is required');

  const bookingOrderId = stringifyNullable(booking.bookingOrderId).trim();
  const reservationCode = stringifyNullable(booking.reservationCode).trim();
  if (!bookingOrderId && !reservationCode) {
    throw new ApiError(400, 'invalid_payload', 'booking.bookingOrderId or booking.reservationCode is required');
  }

  return {
    eventId,
    eventType,
    bookingOrderId,
    reservationCode,
    payload: body,
    status: 'received',
  };
}

async function findStoredReservationEvent(eventId) {
  const url = new URL('/rest/v1/rc00_ops_reservation_events', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('event_id', `eq.${eventId}`);
  url.searchParams.set('select', 'event_id,status');
  url.searchParams.set('limit', '1');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'event_store_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase event lookup failed'));
  }
  return Array.isArray(json) && json.length > 0 ? json[0] : null;
}

async function storeReservationEvent(payload) {
  const url = new URL('/rest/v1/rc00_ops_reservation_events', normalizeSupabaseBaseUrl(config.supabaseUrl));
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      ...buildSupabaseServiceHeaders(),
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({
      event_id: payload.eventId,
      event_type: payload.eventType,
      booking_order_id: payload.bookingOrderId || null,
      reservation_code: payload.reservationCode || null,
      payload_json: payload.payload,
      status: payload.status,
    }),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    const error = new ApiError(502, 'event_store_insert_failed', resolveApiErrorMessage(json, response.status, 'Supabase event insert failed'));
    error.supabaseStatus = response.status;
    error.supabaseBody = json;
    throw error;
  }
}

async function importReservationCreatedEvent(payload) {
  const mapped = mapHomepageReservationPayload(payload.payload);
  if (!mapped.reservationId) {
    throw new ApiError(400, 'invalid_payload', 'reservation id could not be derived');
  }

  const existingReservation = await findReservationByReservationId(mapped.reservationId);
  if (existingReservation?.id) {
    return { reservationId: mapped.reservationId, reservationRefId: existingReservation.id, reused: true };
  }

  const reservation = await insertSupabaseRow('rc00_ops_reservations', {
    reservation_id: mapped.reservationId,
    reservation_number: mapped.reservationNumber || null,
    car_number: mapped.carNumber || null,
    car_name: mapped.carName || null,
    customer_name: mapped.customerName || null,
    customer_phone: mapped.customerPhone || null,
    customer_birth_date: mapped.customerBirthDate || null,
    referral_source: '홈페이지',
    payment_amount: mapped.paymentAmount || null,
    start_at: mapped.startAt || null,
    end_at: mapped.endAt || null,
    pickup_location: mapped.pickupLocation || null,
    dropoff_location: mapped.dropoffLocation || null,
    reservation_status: '예약중',
    note_text: mapped.noteText || null,
    meta_json: mapped.metaJson,
  }, 'id');
  const reservationRefId = reservation?.id;
  if (!reservationRefId) throw new ApiError(502, 'reservation_insert_failed', 'reservation insert did not return id');

  const checkPayload = {
    homepage_review: 'pending',
    customer_name_verified: mapped.customerName ? 'done' : 'pending',
    customer_phone_verified: mapped.customerPhone ? 'done' : 'pending',
    pickup_location_verified: mapped.pickupLocation ? 'done' : 'pending',
  };
  await insertSupabaseRow('rc00_ops_reservation_states', {
    reservation_id: mapped.reservationId,
    reservation_ref_id: reservationRefId,
    tab_key: deriveReservationTabKey(mapped.startAt, mapped.endAt),
    needs_attention: true,
    warning_level: 'warning',
    check_payload_json: checkPayload,
    memo_text: '홈페이지 예약 확인 필요',
    last_action_at: new Date().toISOString(),
  }, 'id');

  await insertSupabaseRow('rc00_ops_schedules', [
    buildHomepageScheduleRow({ mapped, type: '배차', at: mapped.startAt, location: mapped.pickupLocation }),
    buildHomepageScheduleRow({ mapped, type: '반납', at: mapped.endAt, location: mapped.dropoffLocation || mapped.pickupLocation }),
  ], 'id');

  return { reservationId: mapped.reservationId, reservationRefId, reused: false };
}

function mapHomepageReservationPayload(body = {}) {
  const booking = body?.booking && typeof body.booking === 'object' ? body.booking : {};
  const input = body?.reservationInput && typeof body.reservationInput === 'object' ? body.reservationInput : {};
  const links = body?.links && typeof body.links === 'object' ? body.links : {};
  const bookingOrderId = firstText(input.bookingOrderId, booking.bookingOrderId);
  const reservationNumber = firstText(input.reservationCode, input.reservationNumber, booking.reservationCode);
  const seed = bookingOrderId || reservationNumber || firstText(body.eventId);
  const reservationId = `WEB-${seed}`.replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 120);
  const startAt = normalizeIsoDate(firstText(input.pickupAt, input.startAt, input.rentalAt, booking.pickupAt));
  const endAt = normalizeIsoDate(firstText(input.returnAt, input.endAt, booking.returnAt));
  const pickupLocation = firstText(input.pickupLocation, input.deliveryAddress, input.deliveryAddressSummary, booking.deliveryAddressSummary);
  const dropoffLocation = firstText(input.dropoffLocation, input.returnLocation, pickupLocation);
  const customerPhone = normalizePhone(firstText(input.customerPhone, input.phone, booking.customerPhone));
  const paymentAmount = normalizeAmountText(firstText(input.quotedTotalAmount, input.totalAmount, input.paymentAmount, booking.quotedTotalAmount));

  return {
    reservationId,
    reservationNumber,
    customerName: firstText(input.customerName, input.name, booking.customerName),
    customerPhone,
    customerBirthDate: firstText(input.customerBirth, input.customerBirthDate, input.birthDate, booking.customerBirth),
    carNumber: firstText(input.carNumber, booking.carNumber),
    carName: firstText(input.carName, booking.carName),
    startAt,
    endAt,
    pickupLocation,
    dropoffLocation,
    paymentAmount,
    noteText: firstText(input.memo, input.note, `홈페이지 예약 ${reservationNumber || bookingOrderId}`),
    metaJson: {
      source: 'homepage',
      event_id: firstText(body.eventId),
      booking_order_id: bookingOrderId || null,
      reservation_code: reservationNumber || null,
      admin_booking_url: firstText(links.adminBookingUrl) || null,
      homepage_review: 'pending',
      reservation_input: input,
      booking,
    },
  };
}

function buildHomepageScheduleRow({ mapped, type, at, location }) {
  return {
    schedule_id: `${mapped.reservationId}-${type}`,
    reservation_id: mapped.reservationId,
    reservation_number: mapped.reservationNumber || null,
    car_number: mapped.carNumber || null,
    car_name: mapped.carName || null,
    schedule_type: type,
    schedule_at: at || null,
    schedule_done: false,
    location_text: location || null,
    detail_text: '홈페이지 예약 자동 생성',
    payload_json: { created_via: 'homepage_reservation_event', reservation_id: mapped.reservationId, status: type },
  };
}

async function findReservationByReservationId(reservationId) {
  const url = new URL('/rest/v1/rc00_ops_reservations', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('reservation_id', `eq.${reservationId}`);
  url.searchParams.set('select', 'id,reservation_id');
  url.searchParams.set('limit', '1');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) throw new ApiError(502, 'reservation_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase reservation lookup failed'));
  return Array.isArray(json) && json.length > 0 ? json[0] : null;
}

async function insertSupabaseRow(table, body, select = '*') {
  const url = new URL(`/rest/v1/${table}`, normalizeSupabaseBaseUrl(config.supabaseUrl));
  if (select) url.searchParams.set('select', select);
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      ...buildSupabaseServiceHeaders(),
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) throw new ApiError(502, `${table}_insert_failed`, resolveApiErrorMessage(json, response.status, `Supabase ${table} insert failed`));
  return Array.isArray(json) ? json[0] : json;
}

async function markReservationEventImported(eventId, importResult) {
  await updateReservationEvent(eventId, {
    status: 'imported',
    processed_at: new Date().toISOString(),
    error_message: null,
    updated_at: new Date().toISOString(),
    payload_json: undefined,
  });
}

async function markReservationEventFailed(eventId, error) {
  await updateReservationEvent(eventId, {
    status: 'failed',
    processed_at: new Date().toISOString(),
    error_message: error?.message || 'homepage_reservation_import_failed',
    updated_at: new Date().toISOString(),
  });
}

async function updateReservationEvent(eventId, patch) {
  const url = new URL('/rest/v1/rc00_ops_reservation_events', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('event_id', `eq.${eventId}`);
  const body = Object.fromEntries(Object.entries(patch).filter(([, value]) => value !== undefined));
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      ...buildSupabaseServiceHeaders(),
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) throw new ApiError(502, 'event_store_update_failed', resolveApiErrorMessage(json, response.status, 'Supabase event update failed'));
}

function deriveReservationTabKey(startAt, endAt) {
  const now = new Date();
  const start = startAt ? new Date(startAt) : null;
  const end = endAt ? new Date(endAt) : null;
  if (end && end < now) return 'return_due';
  if (start && start <= now) return 'pickup_today';
  return 'pending';
}

function normalizeIsoDate(value) {
  const text = firstText(value);
  if (!text) return '';
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
}

function normalizePhone(value) {
  return firstText(value).replace(/[^0-9]/g, '');
}

function normalizeAmountText(value) {
  const text = firstText(value);
  if (!text) return '';
  const num = Number(String(text).replace(/[^0-9.-]/g, ''));
  return Number.isFinite(num) ? String(Math.round(num)) : text;
}

function firstText(...values) {
  for (const value of values) {
    const text = stringifyNullable(value).trim();
    if (text) return text;
  }
  return '';
}

function isSupabaseDuplicateError(error) {
  const body = error?.supabaseBody || {};
  return error?.supabaseStatus === 409 || body?.code === '23505';
}

function normalizeSupabaseBaseUrl(value) {
  return String(value || '').replace(/\/+$/, '');
}

function buildSupabaseServiceHeaders() {
  return {
    apikey: config.supabaseServiceRoleKey,
    Authorization: `Bearer ${config.supabaseServiceRoleKey}`,
    Accept: 'application/json',
  };
}

function getHeader(req, name) {
  const value = req.headers[name.toLowerCase()];
  if (Array.isArray(value)) return String(value[0] || '').trim();
  return String(value || '').trim();
}

class ApiError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
}

function sendMethodNotAllowed(res, methods) {
  res.writeHead(405, {
    'Content-Type': 'application/json; charset=utf-8',
    'Allow': methods.join(', ')
  });
  res.end(JSON.stringify({ ok: false, error: 'method_not_allowed' }));
}

async function sendLocalFile(res, { localPath, mimeType, downloadName }) {
  const bytes = await fs.readFile(localPath);
  const safeName = encodeURIComponent(downloadName || path.basename(localPath));
  res.writeHead(200, {
    'Content-Type': mimeType || 'application/octet-stream',
    'Content-Length': String(bytes.length),
    'Content-Disposition': `attachment; filename*=UTF-8''${safeName}`,
  });
  res.end(bytes);
}

function resolveErrorStatus(error) {
  if (error?.status) return error.status;
  if (error?.message === 'invalid_json') return 400;
  if (error?.message === 'payload_too_large') return 413;
  if (error?.name === 'AbortError') return 504;
  return 500;
}

function resolveErrorCode(error) {
  if (error?.code) return error.code;
  if (error?.message === 'invalid_json') return 'invalid_json';
  if (error?.message === 'payload_too_large') return 'payload_too_large';
  if (error?.message?.startsWith('missing required ims fields')) return 'invalid_ims_payload';
  if (error?.name === 'AbortError') return 'timeout';
  return 'parse_failed';
}

function normalizeImsChangeCarPayload(body = {}) {
  const payload = {
    scheduleId: String(body?.scheduleId || body?.externalReservationId || '').trim(),
    rentalAt: String(body?.rentalAt || '').trim(),
    returnAt: String(body?.returnAt || '').trim(),
    carNumber: String(body?.carNumber || '').trim(),
    reservationId: String(body?.reservationId || '').trim(),
    dryRun: body?.dryRun === true,
  };

  const required = ['scheduleId', 'rentalAt', 'returnAt', 'carNumber'];
  const missing = required.filter((key) => !payload[key]);
  if (missing.length > 0) {
    throw new Error(`missing required ims fields: ${missing.join(', ')}`);
  }

  return payload;
}

function normalizeImsReservationSearchPayload(body = {}) {
  const payload = {
    customerName: String(body?.customerName || '').trim(),
    carNumber: String(body?.carNumber || '').trim(),
    rentalDate: extractDate(body?.rentalDate || body?.startDate || body?.rentalAt || ''),
    endDate: extractDate(body?.endDate || body?.returnDate || ''),
  };

  if (!payload.rentalDate) {
    throw new Error('missing required ims fields: rentalDate');
  }
  return payload;
}

function normalizeFineNoticeContractSearchPayload(body = {}) {
  const payload = {
    carNumber: String(body?.carNumber || '').trim(),
    rentalDate: extractDate(body?.rentalDate || body?.startDate || body?.rentalAt || ''),
    endDate: extractDate(body?.endDate || body?.returnDate || ''),
  };

  const missing = ['carNumber', 'rentalDate'].filter((key) => !payload[key]);
  if (missing.length > 0) {
    throw new Error(`missing required ims fields: ${missing.join(', ')}`);
  }
  return payload;
}

function normalizeImsInsuranceClaimSearchPayload(body = {}) {
  const payload = {
    customerName: String(body?.customerName || '').trim(),
    carNumber: String(body?.carNumber || '').trim(),
    rentalDate: extractDate(body?.rentalDate || body?.startDate || body?.rentalAt || ''),
    endDate: extractDate(body?.endDate || body?.returnDate || ''),
  };

  if (!payload.rentalDate) {
    throw new Error('missing required ims fields: rentalDate');
  }
  return payload;
}

function normalizeFineNoticeContractPdfPayload(body = {}) {
  const payload = {
    fineNoticeId: String(body?.fineNoticeId || body?.fine_notice_id || '').trim(),
  };
  if (!payload.fineNoticeId) {
    throw new ApiError(400, 'missing_fine_notice_id', 'fineNoticeId is required');
  }
  return payload;
}

function normalizeFineNoticeDocumentPackagePayload(body = {}) {
  const payload = {
    fineNoticeId: String(body?.fineNoticeId || body?.fine_notice_id || '').trim(),
  };
  if (!payload.fineNoticeId) {
    throw new ApiError(400, 'missing_fine_notice_id', 'fineNoticeId is required');
  }
  return payload;
}

function normalizeImsCompleteReturnPayload(body = {}) {
  const payload = {
    contractId: String(body?.contractId || body?.externalDetailId || body?.externalReservationId || '').trim(),
    doneAt: normalizeImsReturnDoneAt(body?.doneAt || body?.done_at || ''),
    returnGasCharge: Number(body?.returnGasCharge ?? body?.return_gas_charge ?? 100),
    drivenDistanceUponReturn: String(body?.drivenDistanceUponReturn || body?.driven_distance_upon_return || '').replace(/[^0-9.]/g, ''),
    fuelCost: Number(body?.fuelCost ?? body?.fuel_cost),
    reservationId: String(body?.reservationId || '').trim(),
    dryRun: body?.dryRun === true,
  };

  const missing = ['contractId', 'doneAt', 'drivenDistanceUponReturn'].filter((key) => !payload[key]);
  if (missing.length > 0) {
    throw new Error(`missing required ims fields: ${missing.join(', ')}`);
  }
  if (!Number.isFinite(payload.returnGasCharge) || payload.returnGasCharge < 0 || payload.returnGasCharge > 100) {
    throw new Error('missing required ims fields: returnGasCharge');
  }
  if (!Number.isFinite(payload.fuelCost)) {
    throw new Error('missing required ims fields: fuelCost');
  }

  return payload;
}

function normalizeImsDeleteReservationPayload(body = {}) {
  const payload = {
    scheduleId: String(body?.scheduleId || body?.externalReservationId || '').trim(),
    reservationId: String(body?.reservationId || '').trim(),
    dryRun: body?.dryRun === true,
  };

  if (!payload.scheduleId) {
    throw new Error('missing required ims fields: scheduleId');
  }

  return payload;
}

function normalizeImsReservationPayload(body = {}) {
  const payload = {
    rentalAt: String(body?.rentalAt || '').trim(),
    returnAt: String(body?.returnAt || '').trim(),
    carNumber: String(body?.carNumber || '').trim(),
    totalFee: String(body?.totalFee || '').replace(/\D+/g, ''),
    customerName: String(body?.customerName || '').trim(),
    customerPhone: String(body?.customerPhone || '').replace(/\D+/g, ''),
    address: String(body?.address || '').trim(),
    useDelivery: body?.useDelivery !== false,
    memo: String(body?.memo || '').trim(),
    reservationId: String(body?.reservationId || '').trim(),
    dryRun: body?.dryRun === true,
  };

  if (payload.reservationId && !payload.memo.includes(`OPS:${payload.reservationId}`)) {
    payload.memo = appendMemoPart(payload.memo, `OPS:${payload.reservationId}`);
  }

  const required = ['rentalAt', 'returnAt', 'carNumber', 'totalFee', 'customerName', 'customerPhone'];
  const missing = required.filter((key) => !payload[key]);
  if (missing.length > 0) {
    throw new Error(`missing required ims fields: ${missing.join(', ')}`);
  }

  return payload;
}


async function resolveImsReservationBindingAfterCreate({ payload, result }) {
  if (result?.code !== 'SUCCESS') {
    return {
      ...result,
      externalStatus: result?.code === 'DRY_RUN' ? 'dry_run' : 'failed',
      linkKey: buildLinkKey(payload),
    };
  }

  if (result?.externalStatus === 'linked' && result?.externalReservationId) {
    return {
      ...result,
      externalStatus: 'linked',
      linkKey: result?.linkKey || buildLinkKey(payload),
    };
  }

  return {
    ...result,
    externalStatus: 'failed',
    linkKey: buildLinkKey(payload),
    errorText: 'IMS 생성 응답에 schedule_id가 없어 연결하지 못했습니다.',
  };
}

async function searchImsReservationsForImport(payload) {
  const token = await fetchImsAccessToken();
  let matches = [];

  if (payload.carNumber) {
    const searchPayload = payload.endDate
      ? payload
      : {
          ...payload,
          endDate: addDaysToDateText(payload.rentalDate, 1),
        };
    const candidates = await findImsReservationsBySearchApi({ token, payload: searchPayload });
    for (const schedule of candidates) {
      const detail = await fetchImsScheduleDetail({ token, scheduleId: schedule.id || schedule.schedule_id });
      if (!detail) continue;
      const matchesCar = !payload.carNumber || normalizeText(detail?.car?.car_identity || detail?.car_identity || schedule?.car_identity || schedule?.car) === normalizeText(payload.carNumber);
      const matchesDate = !payload.rentalDate || extractDate(detail?.start_at || schedule?.start_at || schedule?.start) === payload.rentalDate;
      if (matchesCar && matchesDate) {
        const requestDetail = await fetchImsPartnerRentRequestDetail({
          token,
          requestId: schedule?.detail?.id,
        });
        matches.push(mergeImsScheduleForImport(detail, schedule, requestDetail));
      }
    }
  }

  const items = matches.map((schedule) => toImsReservationImportItem(schedule));
  return {
    code: 'SUCCESS',
    totalCount: items.length,
    items,
  };
}

async function searchFineNoticeContracts(payload) {
  const token = await fetchImsAccessToken();
  const normalMatches = await findImsNormalContractMatchesForFineNotice({
    token,
    payload,
  });
  const normalItems = normalMatches.map(({ contract, detail }) =>
    toImsNormalContractGroupImportItem(contract, detail),
  );
  const insuranceResult = await searchImsInsuranceClaimsForDispatch(payload, token);
  const items = [
    ...normalItems,
    ...insuranceResult.items,
  ];

  return {
    code: 'SUCCESS',
    totalCount: items.length,
    items,
  };
}

async function findImsNormalContractMatchesForFineNotice({ token, payload, maxPages = 80 }) {
  const targetDate = extractDate(payload.rentalDate);
  if (!payload.carNumber || !targetDate) return [];

  const matches = [];
  let totalPage = 1;
  for (let page = 1; page <= Math.min(totalPage, maxPages); page += 1) {
    const url = new URL('https://api.rencar.co.kr/v2/normal-contracts/group');
    url.searchParams.set('page', String(page));
    const response = await fetch(url, { headers: buildImsApiHeaders(token) });
    const json = await readJsonResponse(response);
    if (!response.ok) {
      throw new Error(resolveApiErrorMessage(json, response.status, 'IMS normal contract group lookup failed'));
    }

    const contractList = Array.isArray(json?.contractList) ? json.contractList : [];
    for (const contract of contractList) {
      const details = normalizeImsNormalContractDetails(contract);
      for (const detail of details) {
        if (isImsNormalContractDetailMatch({ contract, detail, payload, targetDate })) {
          matches.push({ contract, detail });
        }
      }
    }

    totalPage = Number(json?.totalPage || json?.total_page || 1);
    if (contractList.length === 0 || page >= totalPage) break;
  }

  return matches;
}

function normalizeImsNormalContractDetails(contract) {
  if (Array.isArray(contract?.details)) return contract.details;
  if (contract?.details && typeof contract.details === 'object') return [contract.details];
  return [];
}

function isImsNormalContractDetailMatch({ contract, detail, payload, targetDate }) {
  const carNumber = stringifyNullable(
    detail?.rent_car_number ||
    detail?.car?.car_identity ||
    detail?.car_identity ||
    detail?.car_number ||
    contract?.rent_car_number ||
    contract?.car_identity,
  );
  if (normalizeText(carNumber) !== normalizeText(payload.carNumber)) return false;

  const startDate = extractDate(
    detail?.delivered_date ||
    detail?.delivered_at ||
    detail?.start_at ||
    contract?.delivered_at ||
    contract?.start_at,
  );
  const endDate = extractDate(
    detail?.returned_at ||
    detail?.expect_return_date ||
    detail?.end_at ||
    contract?.returned_at ||
    contract?.expect_return_date ||
    contract?.end_at,
  ) || startDate;

  return isDateWithinRange(targetDate, startDate, endDate);
}

function isDateWithinRange(targetDate, startDate, endDate) {
  if (!targetDate || !startDate) return false;
  if (!endDate) return targetDate === startDate;
  return startDate <= targetDate && targetDate <= endDate;
}

function toImsNormalContractGroupImportItem(contract, detail) {
  const contractId = stringifyNullable(detail?.normal_contract_id || contract?.id);
  return {
    sourceType: 'ims_normal_contract',
    scheduleId: stringifyNullable(detail?.company_car_schedule_id || detail?.schedule_id),
    detailId: stringifyNullable(detail?.id),
    contractId,
    normalContractId: contractId,
    contractDetailId: stringifyNullable(detail?.id),
    reservationNumber: stringifyNullable(contractId || detail?.id || contract?.id),
    status: stringifyNullable(contract?.state || detail?.state),
    detailStatus: stringifyNullable(detail?.state || contract?.state),
    reservationType: stringifyNullable(contract?.rent_type || detail?.rent_type),
    carNumber: stringifyNullable(detail?.rent_car_number || detail?.car_identity || contract?.rent_car_number),
    carName: stringifyNullable(detail?.rent_car_name || detail?.car_name || contract?.rent_car_name),
    customerName: stringifyNullable(detail?.customer_name || contract?.customer_name),
    customerPhone: digitsOnly(detail?.customer_contact || contract?.customer_contact),
    birthDate: stringifyNullable(detail?.customer_id_number1 || contract?.customer_id_number1),
    price: stringifyNullable(contract?.total_cost || detail?.total_cost || detail?.cost),
    rentalAt: normalizeImsDateTime(detail?.delivered_date || detail?.delivered_at || contract?.delivered_at),
    returnAt: normalizeImsDateTime(detail?.returned_at || detail?.expect_return_date || contract?.returned_at || contract?.expect_return_date),
    pickupLocation: stringifyNullable(detail?.customer_address || contract?.customer_address),
    dropoffLocation: '',
    recommenderName: stringifyNullable(contract?.recommender_name || detail?.recommender_name),
    sourceOrigin: 'normal_contracts_group',
    title: stringifyNullable(contract?.request_id ? `IMS 일반계약 ${contract.request_id}` : 'IMS 일반계약서'),
  };
}

async function searchImsInsuranceClaimsForDispatch(payload, tokenOverride = null) {
  const token = tokenOverride || await fetchImsAccessToken();
  const items = [];
  const endDate = payload.endDate || payload.rentalDate;
  let totalPage = 1;

  for (let page = 1; page <= totalPage; page += 1) {
    const url = new URL('https://api.rencar.co.kr/v2/rencar-claims');
    url.searchParams.set('page', String(page));
    url.searchParams.set('periodOption', 'using_car');
    url.searchParams.set('startdate', payload.rentalDate);
    url.searchParams.set('enddate', endDate);
    if (payload.carNumber) {
      url.searchParams.set('option', 'rent_car_number');
      url.searchParams.set('value', payload.carNumber);
    }

    const response = await fetch(url, { headers: buildImsApiHeaders(token) });
    const json = await readJsonResponse(response);
    if (!response.ok) {
      throw new Error(resolveApiErrorMessage(json, response.status, 'IMS insurance claim lookup failed'));
    }

    const claimList = Array.isArray(json?.claimList) ? json.claimList : [];
    const normalizedCar = normalizeText(payload.carNumber);
    for (const claim of claimList) {
      const matchesCar = !normalizedCar || normalizeText(claim?.rent_car_number) === normalizedCar;
      const matchesDate = extractDate(claim?.delivered_at) === payload.rentalDate;
      if (matchesCar && matchesDate) items.push(toImsInsuranceClaimImportItem(claim));
    }

    totalPage = Number(json?.totalPage || json?.total_page || 1);
    if (claimList.length === 0 || page >= totalPage) break;
  }

  return {
    code: 'SUCCESS',
    totalCount: items.length,
    items,
  };
}

async function saveFineNoticeContractPdf(payload) {
  ensureFineNoticeContractPdfConfigured();

  const notice = await findFineNoticeForContractPdf(payload.fineNoticeId);
  if (!notice) {
    throw new ApiError(404, 'fine_notice_not_found', 'fine notice not found');
  }

  const sourceType = stringifyNullable(notice.confirmed_contract_source_type).trim();
  if (sourceType !== 'ims_normal_contract' && sourceType !== 'ims_insurance_claim') {
    throw new ApiError(409, 'unsupported_contract_source_type', 'contract source type must be ims_normal_contract or ims_insurance_claim');
  }
  const sourceId = sourceType === 'ims_insurance_claim'
    ? stringifyNullable(notice.ims_claim_id).trim()
    : stringifyNullable(notice.ims_contract_id).trim();
  if (!sourceType || !sourceId) {
    throw new ApiError(409, 'contract_not_confirmed', 'contract must be confirmed before saving PDF');
  }
  const bundle = await resolveFineNoticeBundleContext(notice);

  const token = await fetchImsAccessToken();
  let pdfSourceId = sourceId;
  const pdf = sourceType === 'ims_insurance_claim'
    ? await fetchImsInsuranceClaimContractPdf({ token, claimId: sourceId })
    : await fetchImsNormalContractPdfWithResolution({ token, notice, sourceId });
  if (sourceType === 'ims_normal_contract') {
    pdfSourceId = pdf.sourceId || sourceId;
  }
  const firstPagePdf = await extractFirstPagePdf(pdf.buffer);
  const file = await writeFineNoticeContractPdf({
    fineNoticeId: payload.fineNoticeId,
    bundle,
    pdfBuffer: firstPagePdf.buffer,
    contentType: pdf.contentType,
    sourceType,
    sourceId: pdfSourceId,
    originalPageCount: firstPagePdf.originalPageCount,
    storedPageCount: firstPagePdf.storedPageCount,
  });
  await replaceFineNoticeContractOriginalMetadata(payload.fineNoticeId, file);
  return file;
}

function ensureFineNoticeContractPdfConfigured() {
  const missing = [];
  if (!config.supabaseUrl) missing.push('SUPABASE_URL');
  if (!config.supabaseServiceRoleKey) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!config.fineNoticeStorageRoot) missing.push('FINE_NOTICE_STORAGE_ROOT');
  if (missing.length > 0) {
    throw new ApiError(503, 'fine_notice_contract_pdf_not_configured', `missing env: ${missing.join(', ')}`);
  }
}

async function findFineNoticeForContractPdf(fineNoticeId) {
  const url = new URL('/rest/v1/rc00_ops_fine_notices', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('id', `eq.${fineNoticeId}`);
  url.searchParams.set(
    'select',
    'id,created_at,notice_profile,document_number,car_number,occurred_at_text,occurred_at,confirmed_contract_source_type,ims_contract_id,ims_claim_id,renter_snapshot_json,document_list_group_key,source_batch_id',
  );
  url.searchParams.set('limit', '1');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice lookup failed'));
  }
  return Array.isArray(json) && json.length > 0 ? json[0] : null;
}

async function fetchImsNormalContractPdfWithResolution({ token, notice, sourceId }) {
  try {
    const pdf = await fetchImsNormalContractPdf({ token, contractId: sourceId });
    return { ...pdf, sourceId };
  } catch (error) {
    if (!isNormalContractPdfIdResolutionError(error)) throw error;
    const resolvedId = await resolveImsNormalContractPdfId({ token, notice, sourceId });
    if (!resolvedId || resolvedId === sourceId) throw error;
    const pdf = await fetchImsNormalContractPdf({ token, contractId: resolvedId });
    return { ...pdf, sourceId: resolvedId };
  }
}

function isNormalContractPdfIdResolutionError(error) {
  return [
    'ims_contract_pdf_download_failed',
    'ims_contract_pdf_empty',
    'ims_contract_pdf_invalid',
  ].includes(error?.code);
}

async function resolveImsNormalContractPdfId({ token, notice, sourceId }) {
  const snapshotId = resolveImsNormalContractPdfIdFromSnapshot(notice);
  if (snapshotId && snapshotId !== sourceId) return snapshotId;

  const matches = await findImsNormalContractMatchesForFineNotice({
    token,
    payload: {
      carNumber: stringifyNullable(notice?.car_number),
      rentalDate: extractDate(notice?.occurred_at_text || notice?.occurred_at),
    },
  });
  if (matches.length === 0) return '';

  const byDetailId = matches.find(({ detail }) =>
    stringifyNullable(detail?.id) === sourceId ||
    stringifyNullable(detail?.normal_contract_id) === sourceId,
  );
  const match = byDetailId || (matches.length === 1 ? matches[0] : null);
  return stringifyNullable(match?.detail?.normal_contract_id || match?.contract?.id);
}

function resolveImsNormalContractPdfIdFromSnapshot(notice) {
  const snapshot = notice?.renter_snapshot_json && typeof notice.renter_snapshot_json === 'object'
    ? notice.renter_snapshot_json
    : {};
  const raw = snapshot?.raw && typeof snapshot.raw === 'object' ? snapshot.raw : {};
  return stringifyNullable(
    raw?.contractId ||
    raw?.normalContractId ||
    snapshot?.contractId ||
    snapshot?.normalContractId,
  );
}

async function fetchImsNormalContractPdf({ token, contractId }) {
  const response = await fetch(
    `https://api.rencar.co.kr/normal_contract/get_contract_pdf_from_list/${encodeURIComponent(contractId)}`,
    { headers: buildImsApiHeaders(token) },
  );
  return readPdfResponse(response, 'IMS normal contract PDF download failed');
}

async function fetchImsInsuranceClaimContractPdf({ token, claimId }) {
  const response = await fetch(
    `https://api.rencar.co.kr/v2/rencar-claims/${encodeURIComponent(claimId)}/contracts/pdf`,
    { headers: buildImsApiHeaders(token) },
  );
  return readPdfResponse(response, 'IMS insurance contract PDF download failed');
}

async function readPdfResponse(response, fallbackMessage) {
  const contentType = response.headers.get('content-type') || 'application/pdf';
  const buffer = Buffer.from(await response.arrayBuffer());
  if (!response.ok) {
    const preview = buffer.toString('utf8', 0, Math.min(buffer.length, 500));
    throw new ApiError(502, 'ims_contract_pdf_download_failed', preview || `${fallbackMessage} (${response.status})`);
  }
  if (buffer.length === 0) {
    throw new ApiError(502, 'ims_contract_pdf_empty', 'IMS contract PDF response was empty');
  }
  if (!contentType.toLowerCase().includes('pdf') && buffer.subarray(0, 4).toString('utf8') !== '%PDF') {
    throw new ApiError(502, 'ims_contract_pdf_invalid', 'IMS contract response was not a PDF');
  }
  return { buffer, contentType };
}

async function extractFirstPagePdf(pdfBuffer) {
  const sourcePdf = await PDFDocument.load(pdfBuffer);
  const originalPageCount = sourcePdf.getPageCount();
  if (originalPageCount < 1) {
    throw new ApiError(502, 'ims_contract_pdf_invalid', 'IMS contract PDF had no pages');
  }

  const outputPdf = await PDFDocument.create();
  const [firstPage] = await outputPdf.copyPages(sourcePdf, [0]);
  outputPdf.addPage(firstPage);
  const outputBytes = await outputPdf.save();
  return {
    buffer: Buffer.from(outputBytes),
    originalPageCount,
    storedPageCount: 1,
  };
}

async function writeFineNoticeContractPdf({
  fineNoticeId,
  bundle,
  pdfBuffer,
  contentType,
  sourceType,
  sourceId,
  originalPageCount = null,
  storedPageCount = null,
}) {
  const storageRoot = path.resolve(config.fineNoticeStorageRoot);
  const contractDir = path.join(storageRoot, bundle?.baseRelativeDir || path.join('cases', fineNoticeId), 'contract');
  const localPath = path.join(contractDir, 'contract_original.pdf');
  const resolvedPath = path.resolve(localPath);
  if (!resolvedPath.startsWith(`${storageRoot}${path.sep}`)) {
    throw new ApiError(400, 'invalid_storage_path', 'resolved contract path escaped storage root');
  }

  await fs.mkdir(contractDir, { recursive: true });
  await fs.writeFile(resolvedPath, pdfBuffer);

  return {
    fileRole: 'contract_original',
    localPath: resolvedPath,
    sha256: crypto.createHash('sha256').update(pdfBuffer).digest('hex'),
    mimeType: contentType || 'application/pdf',
    sizeBytes: pdfBuffer.length,
    sourceType,
    backupStatus: 'pending',
    metadataJson: {
      imsSourceType: sourceType,
      imsSourceId: sourceId,
      savedAt: new Date().toISOString(),
      pagePolicy: 'first_page_only',
      originalPageCount,
      storedPageCount,
      bundleId: bundle?.bundleId || null,
      noticeDate: bundle?.noticeDate || null,
    },
  };
}

async function replaceFineNoticeContractOriginalMetadata(fineNoticeId, file) {
  await deleteFineNoticeFileMetadata(fineNoticeId, file.fileRole);
  await insertSupabaseRow('rc00_ops_fine_notice_files', {
    fine_notice_id: fineNoticeId,
    file_role: file.fileRole,
    local_path: file.localPath,
    sha256: file.sha256,
    mime_type: file.mimeType,
    size_bytes: file.sizeBytes,
    source_type: file.sourceType,
    parser_request_id: null,
    backup_status: file.backupStatus,
    metadata_json: file.metadataJson,
  }, 'id');
  await updateFineNoticeRow(fineNoticeId, {
    contract_pdf_saved_at: file.metadataJson?.savedAt || new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
}

async function generateFineNoticeDocumentPackage(payload) {
  ensureFineNoticeContractPdfConfigured();
  const notice = await findFineNoticeForDocumentPackage(payload.fineNoticeId);
  if (!notice) {
    throw new ApiError(404, 'fine_notice_not_found', 'fine notice not found');
  }
  if (notice.status !== 'contract_confirmed' && notice.status !== 'document_ready') {
    throw new ApiError(409, 'contract_not_confirmed', 'contract must be confirmed before document generation');
  }

  const contractOriginal = await findFineNoticeFileByRole(payload.fineNoticeId, 'contract_original');
  if (!contractOriginal?.local_path) {
    throw new ApiError(409, 'contract_original_missing', 'contract_original PDF must be saved first');
  }
  const noticeOriginal = await findFineNoticeFileByRole(payload.fineNoticeId, 'notice_original');
  if (!noticeOriginal?.local_path) {
    throw new ApiError(409, 'notice_original_missing', 'notice original file must exist before document generation');
  }

  const siblings = await findFineNoticeDocumentListRows(notice);
  const bundle = await resolveFineNoticeBundleContext(notice, siblings);
  const renter = await resolveFineNoticeRenterSnapshot(notice);
  const generatedAt = new Date().toISOString();
  const packageFiles = [];

  const bundledNoticeOriginal = await copyNoticeOriginalIntoBundle({
    fineNoticeId: payload.fineNoticeId,
    noticeOriginal,
    bundle,
    generatedAt,
  });
  await replaceFineNoticeFileMetadata(payload.fineNoticeId, bundledNoticeOriginal);
  packageFiles.push(bundledNoticeOriginal);

  const bundledContractOriginal = await copyContractOriginalIntoBundle({
    fineNoticeId: payload.fineNoticeId,
    contractOriginal,
    bundle,
    generatedAt,
  });
  await replaceFineNoticeFileMetadata(payload.fineNoticeId, bundledContractOriginal);
  packageFiles.push(bundledContractOriginal);

  const stampedContract = await generateStampedContractPdf({
    fineNoticeId: payload.fineNoticeId,
    bundle,
    contractOriginalPath: bundledContractOriginal.localPath,
    generatedAt,
  });
  await replaceFineNoticeFileMetadata(payload.fineNoticeId, stampedContract);
  packageFiles.push(stampedContract);

  const application = await generateRenterChangeApplicationPdf({
    fineNoticeId: payload.fineNoticeId,
    bundle,
    notice,
    renter,
    generatedAt,
  });
  await replaceFineNoticeFileMetadata(payload.fineNoticeId, application);
  packageFiles.push(application);

  if (siblings.length > 1) {
    const vehicleList = await generateVehicleApplicationListPdf({
      fineNoticeId: payload.fineNoticeId,
      bundle,
      notice,
      rows: siblings,
      renter,
      generatedAt,
    });
    await replaceFineNoticeFileMetadata(payload.fineNoticeId, vehicleList);
    packageFiles.push(vehicleList);
  } else {
    await deleteFineNoticeFileMetadata(payload.fineNoticeId, 'vehicle_application_list');
  }

  await updateFineNoticeRow(payload.fineNoticeId, {
    status: 'document_ready',
    renter_name: renter.name || null,
    renter_phone: renter.phone || null,
    renter_address: renter.address || null,
    renter_identity_type: renter.identityType || 'unknown',
    renter_identity_no: renter.identityNo || null,
    renter_driver_license_no: renter.driverLicenseNo || null,
    renter_birth_date: renter.birthDate || null,
    renter_snapshot_source: renter.source || 'ims_contract_candidate',
    renter_snapshot_confirmed_at: generatedAt,
    document_package_generated_at: generatedAt,
    updated_at: generatedAt,
  });

	  return {
	    fineNoticeId: payload.fineNoticeId,
	    bundle,
	    generatedAt,
	    files: packageFiles.map(toFineNoticeGeneratedFileResponse),
	    warnings: buildDocumentGenerationWarnings(renter),
	  };
	}

async function findFineNoticeForDocumentPackage(fineNoticeId) {
  const url = new URL('/rest/v1/rc00_ops_fine_notices', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('id', `eq.${fineNoticeId}`);
  url.searchParams.set(
    'select',
    [
	      'id',
	      'created_at',
	      'status',
      'notice_profile',
      'notice_type',
      'issuer',
      'document_number',
      'car_number',
      'occurred_at_text',
      'occurred_at',
      'location',
      'total_amount_text',
      'total_amount',
      'due_date_text',
      'memo',
      'raw_candidate_json',
      'confirmed_contract_source_type',
      'ims_contract_id',
      'ims_claim_id',
      'renter_snapshot_json',
      'renter_name',
      'renter_phone',
      'renter_address',
      'renter_identity_type',
      'renter_identity_no',
	      'renter_driver_license_no',
	      'renter_birth_date',
	      'document_list_group_key',
	      'source_batch_id',
	    ].join(','),
  );
  url.searchParams.set('limit', '1');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice lookup failed'));
  }
  return Array.isArray(json) && json.length > 0 ? json[0] : null;
}

async function findFineNoticeFileByRole(fineNoticeId, fileRole) {
  const url = new URL('/rest/v1/rc00_ops_fine_notice_files', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('fine_notice_id', `eq.${fineNoticeId}`);
  url.searchParams.set('file_role', `eq.${fileRole}`);
  url.searchParams.set('select', 'id,fine_notice_id,file_role,local_path,sha256,mime_type,size_bytes,source_type,metadata_json');
  url.searchParams.set('limit', '1');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_file_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice file lookup failed'));
  }
  return Array.isArray(json) && json.length > 0 ? json[0] : null;
}

async function findFineNoticeDocumentListRows(notice) {
  const raw = notice?.raw_candidate_json && typeof notice.raw_candidate_json === 'object'
    ? notice.raw_candidate_json
    : {};
  const selected = raw?.selectedItem && typeof raw.selectedItem === 'object' ? raw.selectedItem : {};
  const rowCount = Number(selected?.rowCount || raw?.rawCandidate?.items?.length || 0);
  const url = new URL('/rest/v1/rc00_ops_fine_notices', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('select', 'id,created_at,document_number,car_number,occurred_at_text,location,total_amount_text,total_amount,notice_profile,document_list_group_key,source_batch_id');
  url.searchParams.set('car_number', `eq.${notice.car_number}`);
  url.searchParams.set('notice_profile', `eq.${notice.notice_profile}`);
  if (notice.document_number) url.searchParams.set('document_number', `eq.${notice.document_number}`);
  url.searchParams.set('order', 'occurred_at_text.asc');
  url.searchParams.set('limit', rowCount > 0 ? String(Math.max(rowCount, 10)) : '20');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_document_rows_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice rows lookup failed'));
  }
  return Array.isArray(json) && json.length > 0 ? json : [notice];
}

async function resolveFineNoticeBundleContext(notice, rows = null) {
  const relatedRows = Array.isArray(rows) && rows.length > 0 ? rows : [notice];
  const existingGroupKey = relatedRows
    .map((row) => stringifyNullable(row.document_list_group_key || row.source_batch_id).trim())
    .find(Boolean);
  const bundleId = sanitizePathSegment(
    existingGroupKey,
  ) || buildFineNoticeBundleId(notice);
  const noticeDate = resolveFineNoticeBundleDate(notice);
  const baseRelativeDir = path.join('notices', noticeDate, bundleId);
  const missingGroupRows = relatedRows.filter((row) =>
    stringifyNullable(row.document_list_group_key).trim() !== bundleId,
  );
  if (missingGroupRows.length > 0) {
    await updateFineNoticeRows(
      missingGroupRows.map((row) => stringifyNullable(row.id)).filter(Boolean),
      {
        document_list_group_key: bundleId,
        updated_at: new Date().toISOString(),
      },
    );
  }
  return { bundleId, noticeDate, baseRelativeDir };
}

function buildFineNoticeBundleId(notice) {
  const seed = [
    stringifyNullable(notice.notice_profile),
    stringifyNullable(notice.document_number),
    stringifyNullable(notice.car_number),
    resolveFineNoticeBundleDate(notice),
  ].join('|');
  const digest = crypto.createHash('sha256').update(seed).digest('hex').slice(0, 16);
  return `bundle-${digest}`;
}

function resolveFineNoticeBundleDate(notice) {
  const candidates = [
    stringifyNullable(notice.created_at),
    stringifyNullable(notice.occurred_at_text),
    stringifyNullable(notice.occurred_at),
    new Date().toISOString(),
  ];
  for (const candidate of candidates) {
    const normalized = normalizeBundleDate(candidate);
    if (normalized) return normalized;
  }
  return formatKstDate(new Date().toISOString());
}

function normalizeBundleDate(value) {
  const text = stringifyNullable(value).trim();
  if (!text) return '';
  const match = text.match(/(\d{4})[-./년\s]*(\d{1,2})[-./월\s]*(\d{1,2})/);
  if (match) {
    return `${match[1]}-${String(Number(match[2])).padStart(2, '0')}-${String(Number(match[3])).padStart(2, '0')}`;
  }
  const date = new Date(text);
  if (!Number.isNaN(date.getTime())) return formatKstDate(date.toISOString());
  return '';
}

function sanitizePathSegment(value) {
  return stringifyNullable(value)
    .trim()
    .replace(/[^0-9A-Za-z._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

async function listFineNoticeFilePackage({ fineNoticeId }) {
  ensureFineNoticeContractPdfConfigured();
  if (!fineNoticeId) {
    throw new ApiError(400, 'fine_notice_id_required', 'fineNoticeId is required');
  }
  const notice = await findFineNoticeForDocumentPackage(fineNoticeId);
  if (!notice) {
    throw new ApiError(404, 'fine_notice_not_found', 'fine notice not found');
  }
  const siblings = await findFineNoticeDocumentListRows(notice);
  const bundle = await resolveFineNoticeBundleContext(notice, siblings);
  const files = await findFineNoticeFilesInsideBundle(bundle);
  return {
    fineNoticeId,
    bundle,
    files: files.map(toFineNoticeFileResponse),
  };
}

async function prepareFineNoticeFileDownload({ fileId }) {
  ensureFineNoticeContractPdfConfigured();
  if (!fileId) {
    throw new ApiError(400, 'file_id_required', 'fileId is required');
  }
  const file = await findFineNoticeFileById(fileId);
  if (!file) {
    throw new ApiError(404, 'fine_notice_file_not_found', 'fine notice file not found');
  }
  const localPath = assertPathInsideStorage(file.local_path);
  await fs.access(localPath);
  const mimeType = stringifyNullable(file.mime_type) || guessMimeTypeFromExtension(path.extname(localPath));
  if (!isAllowedFineNoticeDownloadMime(mimeType)) {
    throw new ApiError(415, 'unsupported_fine_notice_file_type', 'file type is not downloadable');
  }
  const notice = await findFineNoticeForDocumentPackage(file.fine_notice_id);
  if (!notice) {
    throw new ApiError(404, 'fine_notice_not_found', 'fine notice not found');
  }
  const bundle = await resolveFineNoticeBundleContext(notice);
  const bundleRoot = assertPathInsideStorage(path.join(config.fineNoticeStorageRoot, bundle.baseRelativeDir));
  if (!localPath.startsWith(`${bundleRoot}${path.sep}`)) {
    throw new ApiError(403, 'file_outside_bundle', 'file is outside the approved fine notice bundle');
  }
  return {
    localPath,
    mimeType,
    downloadName: `${toFineNoticeFileLabel(file)}${normalizeFileExtension(path.extname(localPath), mimeType)}`,
  };
}

async function findFineNoticeFilesInsideBundle(bundle) {
  const bundleRoot = assertPathInsideStorage(path.join(config.fineNoticeStorageRoot, bundle.baseRelativeDir));
  const url = new URL('/rest/v1/rc00_ops_fine_notice_files', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('select', 'id,fine_notice_id,file_role,local_path,sha256,mime_type,size_bytes,source_type,metadata_json,created_at');
  url.searchParams.set('order', 'created_at.asc');
  url.searchParams.set('limit', '100');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_files_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice files lookup failed'));
  }
  return (Array.isArray(json) ? json : []).filter((file) => {
    const localPath = stringifyNullable(file.local_path);
    if (!localPath) return false;
    const resolved = path.resolve(localPath);
    return resolved.startsWith(`${bundleRoot}${path.sep}`);
  });
}

async function findFineNoticeFileById(fileId) {
  const url = new URL('/rest/v1/rc00_ops_fine_notice_files', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('id', `eq.${fileId}`);
  url.searchParams.set('select', 'id,fine_notice_id,file_role,local_path,sha256,mime_type,size_bytes,source_type,metadata_json');
  url.searchParams.set('limit', '1');
  const response = await fetch(url, { headers: buildSupabaseServiceHeaders() });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_file_lookup_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice file lookup failed'));
  }
  return Array.isArray(json) && json.length > 0 ? json[0] : null;
}

function toFineNoticeFileResponse(file) {
  const metadataJson = sanitizeFineNoticeFileMetadataForResponse(file.metadata_json);
  return {
    id: stringifyNullable(file.id),
    fineNoticeId: stringifyNullable(file.fine_notice_id),
    fileRole: stringifyNullable(file.file_role),
    localPath: '',
    sha256: stringifyNullable(file.sha256) || null,
    mimeType: stringifyNullable(file.mime_type) || guessMimeTypeFromExtension(path.extname(stringifyNullable(file.local_path))),
    sizeBytes: Number(file.size_bytes || 0) || null,
    sourceType: stringifyNullable(file.source_type) || null,
    backupStatus: 'pending',
    metadataJson: {
      ...metadataJson,
      displayName: toFineNoticeFileLabel(file),
    },
  };
}

function toFineNoticeGeneratedFileResponse(file) {
  return {
    id: stringifyNullable(file.id) || null,
    fineNoticeId: stringifyNullable(file.fineNoticeId) || null,
    fileRole: stringifyNullable(file.fileRole),
    localPath: '',
    sha256: stringifyNullable(file.sha256) || null,
    mimeType: stringifyNullable(file.mimeType) || null,
    sizeBytes: Number(file.sizeBytes || 0) || null,
    sourceType: stringifyNullable(file.sourceType) || null,
    backupStatus: stringifyNullable(file.backupStatus) || 'pending',
    metadataJson: sanitizeFineNoticeFileMetadataForResponse(file.metadataJson),
  };
}

function sanitizeFineNoticeFileMetadataForResponse(metadata) {
  const source = metadata && typeof metadata === 'object' ? metadata : {};
  const blocked = new Set(['sourcePath', 'localPath', 'absolutePath', 'resolvedPath']);
  return Object.fromEntries(Object.entries(source).filter(([key]) => !blocked.has(key)));
}

function toFineNoticeFileLabel(file) {
  const role = stringifyNullable(file.file_role);
  const meta = file.metadata_json && typeof file.metadata_json === 'object' ? file.metadata_json : {};
  return stringifyNullable(meta.displayName || meta.label) || ({
    notice_original: '고지서 원본',
    contract_original: '계약서 원본',
    contract_with_stamps: '계약서 사본',
    renter_change_application: '임차인 변경 신청서',
    vehicle_application_list: '통행 목록',
    submission_receipt: '발송 확인',
  }[role] || role || 'fine_notice_file');
}

async function resolveFineNoticeRenterSnapshot(notice) {
  const snapshot = notice?.renter_snapshot_json && typeof notice.renter_snapshot_json === 'object'
    ? notice.renter_snapshot_json
    : {};
  const renter = {
    name: stringifyNullable(notice.renter_name || snapshot.customerName),
    phone: stringifyNullable(notice.renter_phone || snapshot.customerPhone),
    address: stringifyNullable(notice.renter_address || findFirstNestedValue(snapshot, ['address', 'customerAddress', 'renterAddress'])),
    identityType: stringifyNullable(notice.renter_identity_type),
    identityNo: stringifyNullable(notice.renter_identity_no),
    driverLicenseNo: stringifyNullable(notice.renter_driver_license_no),
    birthDate: stringifyNullable(notice.renter_birth_date || findFirstNestedValue(snapshot, ['birthDate', 'birthday'])),
    source: 'stored_snapshot',
  };

  if (renter.name && renter.phone) return renter;

  const result = await searchFineNoticeContracts({
    carNumber: stringifyNullable(notice.car_number),
    rentalDate: extractDate(notice.occurred_at_text || notice.occurred_at),
    endDate: '',
  });
  const sourceId = notice.confirmed_contract_source_type === 'ims_insurance_claim'
    ? stringifyNullable(notice.ims_claim_id)
    : stringifyNullable(notice.ims_contract_id);
  const match = (result.items || []).find((item) =>
    stringifyNullable(item.sourceId || item.contractId || item.claimId || item.normalContractId) === sourceId,
  );

  if (match) {
    renter.name = renter.name || stringifyNullable(match.customerName);
    renter.phone = renter.phone || stringifyNullable(match.customerPhone);
    renter.address = renter.address || stringifyNullable(match.customerAddress || match.address || match.pickupLocation);
    renter.birthDate = renter.birthDate || stringifyNullable(match.birthDate);
    renter.source = 'ims_contract_candidate';
  }
  return renter;
}

function buildDocumentGenerationWarnings(renter) {
  return [
    ...(!renter.name ? ['renter_name_missing'] : []),
    ...(!renter.phone ? ['renter_phone_missing'] : []),
    ...(!renter.address ? ['renter_address_missing'] : []),
    ...(!renter.identityNo && !renter.driverLicenseNo && !renter.birthDate ? ['renter_identity_missing'] : []),
  ];
}

async function copyNoticeOriginalIntoBundle({ fineNoticeId, noticeOriginal, bundle, generatedAt }) {
  const sourcePath = assertPathInsideStorage(noticeOriginal.local_path);
  const bytes = await fs.readFile(sourcePath);
  const ext = normalizeFileExtension(path.extname(sourcePath), noticeOriginal.mime_type || noticeOriginal.mimeType);
  return writeFineNoticeGeneratedFile({
    fineNoticeId,
    bundle,
    relativePath: `notice/notice_original${ext}`,
    fileRole: 'notice_original',
    bytes,
    mimeType: noticeOriginal.mime_type || noticeOriginal.mimeType || guessMimeTypeFromExtension(ext),
    sourceType: 'document_generator',
    metadataJson: {
	      generatedAt,
	      sourceRole: 'notice_original',
	      bundleId: bundle?.bundleId || null,
      noticeDate: bundle?.noticeDate || null,
      displayName: '고지서 원본',
    },
  });
}

async function copyContractOriginalIntoBundle({ fineNoticeId, contractOriginal, bundle, generatedAt }) {
  const sourcePath = assertPathInsideStorage(contractOriginal.local_path);
  const bytes = await fs.readFile(sourcePath);
  const sourceMetadata = contractOriginal.metadata_json && typeof contractOriginal.metadata_json === 'object'
    ? contractOriginal.metadata_json
    : {};
  return writeFineNoticeGeneratedFile({
    fineNoticeId,
    bundle,
    relativePath: 'contract/contract_original.pdf',
    fileRole: 'contract_original',
    bytes,
    mimeType: contractOriginal.mime_type || contractOriginal.mimeType || 'application/pdf',
    sourceType: contractOriginal.source_type || contractOriginal.sourceType || 'ims_contract_pdf',
    metadataJson: {
      ...sourceMetadata,
      generatedAt,
      copiedIntoBundleAt: generatedAt,
      bundleId: bundle?.bundleId || null,
      noticeDate: bundle?.noticeDate || null,
      displayName: '계약서 원본',
    },
  });
}

async function generateStampedContractPdf({ fineNoticeId, bundle, contractOriginalPath, generatedAt }) {
  const inputPath = assertPathInsideStorage(contractOriginalPath);
  const pdfBytes = await fs.readFile(inputPath);
  const sourcePdf = await PDFDocument.load(pdfBytes);
  const originalPageCount = sourcePdf.getPageCount();
  if (originalPageCount < 1) {
    throw new ApiError(502, 'contract_original_invalid', 'contract_original PDF had no pages');
  }

  const pdfDoc = await PDFDocument.create();
  const [copiedFirstPage] = await pdfDoc.copyPages(sourcePdf, [0]);
  pdfDoc.addPage(copiedFirstPage);
  const stampRoot = resolveStampAssetRoot();
  const originalTruePng = await fs.readFile(path.join(stampRoot, 'stamp_original_true.png'));
  const companySealPng = await fs.readFile(path.join(stampRoot, 'stamp_company_seal.png'));
  const originalTrueImage = await pdfDoc.embedPng(originalTruePng);
  const companySealImage = await pdfDoc.embedPng(companySealPng);
  const firstPage = pdfDoc.getPage(0);
  const { width, height } = firstPage.getSize();
  firstPage.drawImage(originalTrueImage, {
    x: width - 210,
    y: height - 95,
    width: 130,
    height: 28,
  });
  firstPage.drawImage(companySealImage, {
    x: width - 92,
    y: height - 118,
    width: 58,
    height: 58,
  });
  const outputBytes = await pdfDoc.save();
	  return writeFineNoticeGeneratedFile({
	    fineNoticeId,
	    bundle,
	    relativePath: 'contract/contract_with_stamps.pdf',
    fileRole: 'contract_with_stamps',
    bytes: Buffer.from(outputBytes),
    mimeType: 'application/pdf',
    sourceType: 'document_generator',
    metadataJson: {
      generatedAt,
      sourceRole: 'contract_original',
      pagePolicy: 'first_page_only',
      sourcePageCount: originalPageCount,
      generatedPageCount: 1,
      stampOriginalTrue: 'assets/stamps/stamp_original_true.png',
      stampCompanySeal: 'assets/stamps/stamp_company_seal.png',
      reviewRequired: true,
    },
  });
}

async function generateRenterChangeApplicationPdf({ fineNoticeId, bundle, notice, renter, generatedAt }) {
  const pdfDoc = await PDFDocument.create();
  pdfDoc.registerFontkit(fontkit);
  const font = await embedKoreanFont(pdfDoc);
  const page = pdfDoc.addPage([595.28, 841.89]);
  const lines = buildRenterChangeApplicationLines({ notice, renter, generatedAt });
  drawTextLines(page, lines, { font, x: 48, y: 790, size: 10, lineHeight: 16 });

  const stampRoot = resolveStampAssetRoot();
  const companySealPng = await fs.readFile(path.join(stampRoot, 'stamp_company_seal.png'));
  const companySealImage = await pdfDoc.embedPng(companySealPng);
  page.drawImage(companySealImage, {
    x: 142,
    y: 744,
    width: 52,
    height: 52,
  });

  const outputBytes = await pdfDoc.save();
	  return writeFineNoticeGeneratedFile({
	    fineNoticeId,
	    bundle,
	    relativePath: 'documents/renter_change_application.pdf',
    fileRole: 'renter_change_application',
    bytes: Buffer.from(outputBytes),
    mimeType: 'application/pdf',
    sourceType: 'document_generator',
    metadataJson: {
      generatedAt,
      templateKey: 'generic_toll_fee_renter_change_application',
      reviewRequired: true,
      missingFields: buildDocumentGenerationWarnings(renter),
    },
  });
}

async function generateVehicleApplicationListPdf({ fineNoticeId, bundle, notice, rows, renter, generatedAt }) {
  const pdfDoc = await PDFDocument.create();
  pdfDoc.registerFontkit(fontkit);
  const font = await embedKoreanFont(pdfDoc);
  const page = pdfDoc.addPage([595.28, 841.89]);
  const safeRows = Array.isArray(rows) && rows.length > 0 ? rows : [notice];
  const lines = [
    '임차인 변경 신청 차량/통행 목록',
    '',
    `발행처: ${stringifyNullable(notice.issuer) || '확인 필요'}`,
    `차량번호: ${stringifyNullable(notice.car_number) || '확인 필요'}`,
    `계약자: ${renter.name || '확인 필요'}`,
    `연락처: ${maskPhoneForDocument(renter.phone) || '확인 필요'}`,
    '',
    '번호 | 통행일시 | 통행장소 | 금액',
    '---------------------------------------------',
    ...safeRows.map((row, index) =>
      `${index + 1} | ${stringifyNullable(row.occurred_at_text) || '확인 필요'} | ${stringifyNullable(row.location) || '확인 필요'} | ${stringifyNullable(row.total_amount_text || row.total_amount) || '확인 필요'}`,
    ),
    '',
    `생성일시: ${formatKstDateTime(generatedAt)}`,
    '주의: 제출 전 계약자 정보와 첨부서류를 사람이 확인해야 합니다.',
  ];
  drawTextLines(page, lines, { font, x: 48, y: 790, size: 10, lineHeight: 16 });
  const outputBytes = await pdfDoc.save();
	  return writeFineNoticeGeneratedFile({
	    fineNoticeId,
	    bundle,
	    relativePath: 'documents/vehicle_application_list.pdf',
    fileRole: 'vehicle_application_list',
    bytes: Buffer.from(outputBytes),
    mimeType: 'application/pdf',
    sourceType: 'document_generator',
    metadataJson: {
      generatedAt,
      rowCount: safeRows.length,
      reviewRequired: true,
    },
  });
}

function buildRenterChangeApplicationLines({ notice, renter, generatedAt }) {
  const documentNumber = `FN-${formatCompactDate(generatedAt)}-${String(stringifyNullable(notice.id).slice(0, 8)).toUpperCase()}`;
  return [
    '빵빵카(주)   (rentcar00.com)',
    '"(우) 06510 서울특별시 서초구 신반포로23길 78-9, 빵빵카(주)"',
    'Tel : (02)592-0079  Fax : (02)592-7900  mail : rentcar00@daum.net',
    '',
    `문 서 번 호  : ${documentNumber}`,
    `시 행 일 자  : ${formatKstDate(generatedAt)}`,
    '발신 - 담당  : 빵빵카(주)',
    `수신 - 참조  : ${stringifyNullable(notice.issuer) || '확인 필요'}`,
    '제      목  : 유료도로 미납통행료 임차인 변경 신청.',
    '',
    '1. 귀 기관의 무궁한 발전을 기원합니다.',
    '',
    `2. 귀 기관에서 발행한 미납통행료 안내문(지로번호/문서번호: ${stringifyNullable(notice.document_number) || '확인 필요'})`,
    `   차량 ${stringifyNullable(notice.car_number) || '확인 필요'}의 미납통행료 건에 대하여,`,
    '   당사는 자동차대여 사업체로서 해당 통행시점의 임차인을 아래와 같이 통보하오니',
    '   납부의무자/임차인 변경 처리를 검토하여 주시기 바랍니다.',
    '',
    '------   다           음  ------',
    '',
    `1 위 반 차 량 : ${stringifyNullable(notice.car_number) || '확인 필요'}`,
    `2 통 행 일 시 : ${stringifyNullable(notice.occurred_at_text) || '확인 필요'}`,
    `3 통 행 장 소 : ${stringifyNullable(notice.location) || '확인 필요'}`,
    `4 통 행 금 액 : ${stringifyNullable(notice.total_amount_text || notice.total_amount) || '확인 필요'}`,
    `5 임  차  인 : ${renter.name || '확인 필요'}`,
    `6 식 별 정 보 : ${formatRenterIdentityForDocument(renter)}`,
    `7 연  락  처 : ${maskPhoneForDocument(renter.phone) || '확인 필요'}`,
    `8 주      소 : ${renter.address || '확인 필요'}`,
    '',
    '*별 첨 :',
    '1. 차량임대차 계약서 사본 1부',
    '2. 미납통행료 안내문 사본 1부',
    '3. 통행 목록 1부',
    '',
    '※ 본 문서는 MVP 자동생성 초안입니다. 제출 전 담당자가 값, 도장 위치, 첨부서류를 확인해야 합니다.',
  ];
}

function drawTextLines(page, lines, { font, x, y, size, lineHeight }) {
  let cursorY = y;
  for (const rawLine of lines) {
    const wrapped = wrapText(String(rawLine), 72);
    for (const line of wrapped) {
      page.drawText(line, { x, y: cursorY, size, font, color: rgb(0, 0, 0) });
      cursorY -= lineHeight;
    }
  }
}

function wrapText(text, maxChars) {
  if (!text) return [''];
  const lines = [];
  let current = '';
  for (const token of text.split(/(\s+)/)) {
    if ((current + token).length > maxChars && current.trim()) {
      lines.push(current.trimEnd());
      current = token.trimStart();
    } else {
      current += token;
    }
  }
  lines.push(current.trimEnd());
  return lines;
}

async function embedKoreanFont(pdfDoc) {
  const candidates = [
    '/System/Library/Fonts/Supplemental/AppleGothic.ttf',
    '/Library/Fonts/AppleGothic.ttf',
  ];
  for (const candidate of candidates) {
    try {
      const bytes = await fs.readFile(candidate);
      return pdfDoc.embedFont(bytes);
    } catch {
      // Try next candidate.
    }
  }
  throw new ApiError(503, 'korean_font_missing', 'Korean font file not found');
}

function resolveStampAssetRoot() {
  const storageRoot = path.resolve(config.fineNoticeStorageRoot);
  const candidates = [
    process.env.FINE_NOTICE_STAMP_ASSET_ROOT,
    path.join(storageRoot, 'assets', 'stamps'),
    '/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices/assets/stamps',
  ].filter(Boolean);
  for (const candidate of candidates) {
    const resolved = path.resolve(candidate);
    try {
      if (resolved.startsWith(`${storageRoot}${path.sep}`) || resolved.startsWith('/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices/assets/stamps')) {
        return resolved;
      }
    } catch {
      // Continue to next candidate.
    }
  }
  throw new ApiError(503, 'stamp_assets_missing', 'stamp asset root is not configured');
}

async function writeFineNoticeGeneratedFile({ fineNoticeId, bundle, relativePath, fileRole, bytes, mimeType, sourceType, metadataJson }) {
  const storageRoot = path.resolve(config.fineNoticeStorageRoot);
  const baseRelativeDir = bundle?.baseRelativeDir || path.join('cases', fineNoticeId);
  const outputPath = assertPathInsideStorage(path.join(storageRoot, baseRelativeDir, relativePath));
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, bytes);
  return {
    fileRole,
    localPath: outputPath,
    sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
    mimeType,
    sizeBytes: bytes.length,
    sourceType,
    backupStatus: 'pending',
    metadataJson: {
      ...metadataJson,
      bundleId: bundle?.bundleId || metadataJson?.bundleId || null,
      noticeDate: bundle?.noticeDate || metadataJson?.noticeDate || null,
    },
  };
}

function assertPathInsideStorage(candidatePath) {
  const storageRoot = path.resolve(config.fineNoticeStorageRoot);
  const resolvedPath = path.resolve(candidatePath);
  if (resolvedPath !== storageRoot && !resolvedPath.startsWith(`${storageRoot}${path.sep}`)) {
    throw new ApiError(400, 'invalid_storage_path', 'resolved path escaped storage root');
  }
  return resolvedPath;
}

async function replaceFineNoticeFileMetadata(fineNoticeId, file) {
  await deleteFineNoticeFileMetadata(fineNoticeId, file.fileRole);
  await insertSupabaseRow('rc00_ops_fine_notice_files', {
    fine_notice_id: fineNoticeId,
    file_role: file.fileRole,
    local_path: file.localPath,
    sha256: file.sha256,
    mime_type: file.mimeType,
    size_bytes: file.sizeBytes,
    source_type: file.sourceType,
    parser_request_id: null,
    backup_status: file.backupStatus,
    metadata_json: file.metadataJson,
  }, 'id');
}

async function updateFineNoticeRow(fineNoticeId, patch) {
  const url = new URL('/rest/v1/rc00_ops_fine_notices', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('id', `eq.${fineNoticeId}`);
  const body = Object.fromEntries(Object.entries(patch).filter(([, value]) => value !== undefined));
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      ...buildSupabaseServiceHeaders(),
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_update_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice update failed'));
  }
}

async function updateFineNoticeRows(fineNoticeIds, patch) {
  const ids = [...new Set((fineNoticeIds || []).map(stringifyNullable).filter(Boolean))];
  if (ids.length === 0) return;
  const url = new URL('/rest/v1/rc00_ops_fine_notices', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('id', `in.(${ids.join(',')})`);
  const body = Object.fromEntries(Object.entries(patch).filter(([, value]) => value !== undefined));
  const response = await fetch(url, {
    method: 'PATCH',
    headers: {
      ...buildSupabaseServiceHeaders(),
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_bulk_update_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice bulk update failed'));
  }
}

function normalizeFileExtension(ext, mimeType = '') {
  const clean = stringifyNullable(ext).toLowerCase();
  if (clean && clean.length <= 6 && /^\.[a-z0-9]+$/.test(clean)) return clean;
  const mime = stringifyNullable(mimeType).toLowerCase();
  if (mime.includes('jpeg') || mime.includes('jpg')) return '.jpg';
  if (mime.includes('png')) return '.png';
  return '.pdf';
}

function guessMimeTypeFromExtension(ext) {
  const clean = stringifyNullable(ext).toLowerCase();
  if (clean === '.jpg' || clean === '.jpeg') return 'image/jpeg';
  if (clean === '.png') return 'image/png';
  return 'application/pdf';
}

function isAllowedFineNoticeDownloadMime(mimeType) {
  const mime = stringifyNullable(mimeType).toLowerCase();
  return mime.includes('pdf') || mime.includes('jpeg') || mime.includes('jpg') || mime.includes('png');
}

function formatRenterIdentityForDocument(renter) {
  if (renter.identityNo) return maskSensitiveId(renter.identityNo);
  if (renter.driverLicenseNo) return `면허번호 ${maskSensitiveId(renter.driverLicenseNo)}`;
  if (renter.birthDate) return `생년월일 ${renter.birthDate}`;
  return '확인 필요';
}

function maskSensitiveId(value) {
  const text = stringifyNullable(value);
  if (!text) return '';
  if (text.length <= 6) return text;
  return `${text.slice(0, 6)}-${'*'.repeat(Math.max(4, text.length - 7))}`;
}

function maskPhoneForDocument(value) {
  const text = stringifyNullable(value);
  if (!text) return '';
  const digits = text.replace(/\D/g, '');
  if (digits.length < 7) return text;
  return `${digits.slice(0, 3)}-${'*'.repeat(Math.max(3, digits.length - 7))}-${digits.slice(-4)}`;
}

function formatCompactDate(value) {
  const date = new Date(value);
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  return `${kst.getUTCFullYear()}${String(kst.getUTCMonth() + 1).padStart(2, '0')}${String(kst.getUTCDate()).padStart(2, '0')}`;
}

function formatKstDate(value) {
  const date = new Date(value);
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  return `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}`;
}

function formatKstDateTime(value) {
  const date = new Date(value);
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  return `${formatKstDate(value)} ${String(kst.getUTCHours()).padStart(2, '0')}:${String(kst.getUTCMinutes()).padStart(2, '0')}`;
}

async function deleteFineNoticeFileMetadata(fineNoticeId, fileRole) {
  const url = new URL('/rest/v1/rc00_ops_fine_notice_files', normalizeSupabaseBaseUrl(config.supabaseUrl));
  url.searchParams.set('fine_notice_id', `eq.${fineNoticeId}`);
  url.searchParams.set('file_role', `eq.${fileRole}`);
  const response = await fetch(url, {
    method: 'DELETE',
    headers: {
      ...buildSupabaseServiceHeaders(),
      Prefer: 'return=minimal',
    },
  });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new ApiError(502, 'fine_notice_file_metadata_delete_failed', resolveApiErrorMessage(json, response.status, 'Supabase fine notice file metadata delete failed'));
  }
}


async function createImsReservationDirect(payload) {
  if (payload.dryRun) {
    return {
      code: 'DRY_RUN',
      message: 'dryRun=true; IMS direct API save skipped',
    };
  }

  const token = await fetchImsAccessToken();
  const car = await findAvailableImsCar({ token, payload });
  if (!car) {
    return {
      code: 'DUPLICATE_OR_NOT_FOUND',
      message: `available car not found: ${payload.carNumber}`,
    };
  }

  const body = buildImsCreateScheduleBody({ payload, carId: stringifyNullable(car.id) });
  const response = await fetch('https://api.rencar.co.kr/v2/company-car-schedules', {
    method: 'POST',
    headers: buildImsApiHeaders(token, { contentType: true }),
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    return {
      code: 'ERROR',
      message: resolveApiErrorMessage(json, response.status),
      apiStatus: response.status,
      apiResult: json,
    };
  }

  let scheduleId = findFirstNestedValue(json, [
    'schedule_id',
    'scheduleId',
    'company_car_schedule_id',
    'companyCarScheduleId',
    'id',
  ]);
  let detailId = findFirstNestedValue(json, [
    'detail_id',
    'detailId',
    'reservation_id',
    'reservationId',
  ]);
  let matchedSchedule = null;

  if (!scheduleId) {
    matchedSchedule = await findCreatedImsReservationByApi({ token, payload });
    scheduleId = matchedSchedule?.id;
    detailId = matchedSchedule?.reservation?.id;
  }

  return {
    code: 'SUCCESS',
    message: '',
    externalStatus: scheduleId ? 'linked' : undefined,
    externalReservationId: stringifyNullable(scheduleId),
    externalDetailId: stringifyNullable(detailId),
    linkKey: buildLinkKey(payload),
    apiResult: json,
    matchedSchedule,
    requestBody: body,
  };
}

async function changeImsReservationCarDirect(payload) {
  if (payload.dryRun) {
    return {
      code: 'DRY_RUN',
      message: 'dryRun=true; IMS direct API change skipped',
      externalReservationId: payload.scheduleId,
      externalStatus: 'linked',
      linkKey: buildLinkKey(payload),
    };
  }

  const token = await fetchImsAccessToken();
  const car = await findAvailableImsCar({ token, payload });
  if (!car) {
    return {
      code: 'DUPLICATE_OR_NOT_FOUND',
      message: `available car not found: ${payload.carNumber}`,
    };
  }

  const response = await fetch(
    `https://api.rencar.co.kr/v2/company-car-schedules/${encodeURIComponent(payload.scheduleId)}`,
    {
      method: 'POST',
      headers: buildImsApiHeaders(token, { contentType: true }),
      body: JSON.stringify({ company_car_id: stringifyNullable(car.id) }),
    },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) {
    return {
      code: 'ERROR',
      message: resolveApiErrorMessage(json, response.status),
      apiStatus: response.status,
      apiResult: json,
    };
  }

  const scheduleId = findFirstNestedValue(json, [
    'schedule_id',
    'scheduleId',
    'company_car_schedule_id',
    'companyCarScheduleId',
    'id',
  ]) || payload.scheduleId;

  return {
    code: 'SUCCESS',
    message: '',
    externalStatus: 'linked',
    externalReservationId: stringifyNullable(scheduleId),
    externalDetailId: '',
    linkKey: buildLinkKey(payload),
    apiResult: json,
    targetCarId: stringifyNullable(car.id),
  };
}

async function deleteImsReservationDirect(payload) {
  if (payload.dryRun) {
    return {
      code: 'DRY_RUN',
      message: 'dryRun=true; IMS direct delete skipped',
      externalReservationId: payload.scheduleId,
      externalStatus: 'deleted',
      linkKey: payload.reservationId ? `OPS:${payload.reservationId}` : '',
    };
  }

  const token = await fetchImsAccessToken();
  const body = { ids: [payload.scheduleId] };
  const response = await fetch('https://api.rencar.co.kr/v2/company-car-schedules/delete', {
    method: 'POST',
    headers: buildImsApiHeaders(token, { contentType: true }),
    body: JSON.stringify(body),
  });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    return {
      code: 'ERROR',
      message: resolveApiErrorMessage(json, response.status),
      apiStatus: response.status,
      apiResult: json,
    };
  }

  return {
    code: 'SUCCESS',
    message: '',
    externalStatus: 'deleted',
    externalReservationId: payload.scheduleId,
    linkKey: payload.reservationId ? `OPS:${payload.reservationId}` : '',
    apiResult: json,
    requestBody: body,
  };
}

async function completeImsReservationReturnDirect(payload) {
  if (payload.dryRun) {
    return {
      code: 'DRY_RUN',
      message: 'dryRun=true; IMS direct return skipped',
      externalReservationId: payload.contractId,
      externalStatus: 'linked',
      linkKey: buildLinkKey(payload),
    };
  }

  const token = await fetchImsAccessToken();
  const data = {
    done_at: payload.doneAt,
    return_gas_charge: String(payload.returnGasCharge),
    driven_distance_upon_return: String(payload.drivenDistanceUponReturn),
    fuel_cost: payload.fuelCost,
  };
  const response = await fetch(
    `https://api.rencar.co.kr/v2/normal-contracts/${encodeURIComponent(payload.contractId)}/set-done`,
    {
      method: 'POST',
      headers: buildImsApiHeaders(token, { contentType: true }),
      body: JSON.stringify(data),
    },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) {
    return {
      code: 'ERROR',
      message: resolveApiErrorMessage(json, response.status),
      apiStatus: response.status,
      apiResult: json,
    };
  }

  return {
    code: 'SUCCESS',
    message: '',
    externalStatus: 'linked',
    externalReservationId: payload.contractId,
    linkKey: buildLinkKey(payload),
    apiResult: json,
    requestBody: data,
  };
}

async function fetchImsAccessToken() {
  const username = String(process.env.IMS_ID || '').trim();
  const rawPassword = String(process.env.IMS_PW || process.env.IMS_PASSWORD || '').trim();
  if (!username || !rawPassword) {
    throw new Error('missing IMS_ID or IMS_PW');
  }

  const password = /^[a-f0-9]{64}$/i.test(rawPassword)
    ? rawPassword
    : crypto.createHash('sha256').update(rawPassword).digest('hex');

  const response = await fetch('https://api.rencar.co.kr/auth', {
    method: 'POST',
    headers: buildImsApiHeaders('', { contentType: true, auth: false }),
    body: JSON.stringify({ username, password }),
  });
  const json = await readJsonResponse(response);
  const token = stringifyNullable(json?.access_token);
  if (!response.ok || !token) {
    throw new Error(resolveApiErrorMessage(json, response.status, 'IMS auth failed'));
  }
  return token;
}

async function findAvailableImsCar({ token, payload }) {
  const url = new URL('https://api.rencar.co.kr/v2/rent-company-cars/available');
  url.searchParams.set('page', '1');
  url.searchParams.set('start_at', toImsLocalApiDateTime(payload.rentalAt));
  url.searchParams.set('end_at', toImsLocalApiDateTime(payload.returnAt));
  url.searchParams.set('search', payload.carNumber);
  url.searchParams.set('overseas', 'all');
  url.searchParams.set('body_style', 'all');
  url.searchParams.set('car_size', 'all');
  url.searchParams.set('insurance_age', 'all');

  const response = await fetch(url, { headers: buildImsApiHeaders(token) });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new Error(resolveApiErrorMessage(json, response.status, 'IMS available car lookup failed'));
  }

  const cars = Array.isArray(json?.cars) ? json.cars : [];
  const normalizedTarget = normalizeText(payload.carNumber);
  const exactMatches = cars.filter((car) => normalizeText(car?.car_identity || car?.car_number || car?.number) === normalizedTarget);
  if (exactMatches.length === 1) return exactMatches[0];
  if (cars.length === 1) return cars[0];
  return null;
}

async function findCreatedImsReservationByApi({ token, payload }) {
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    const fastMatches = [];
    const candidates = await findImsReservationsBySearchApi({ token, payload });
    for (const schedule of candidates) {
      const sameCar = normalizeText(schedule?.car_identity || schedule?.car_number || schedule?.car) === normalizeText(payload.carNumber);
      const sameStart = normalizeImsDateTime(schedule?.start_at || schedule?.start) === normalizeImsDateTime(payload.rentalAt);
      const sameEnd = normalizeImsDateTime(schedule?.end_at || schedule?.end) === normalizeImsDateTime(payload.returnAt);
      if (!sameCar || !sameStart || !sameEnd) continue;

      const detail = await fetchImsScheduleDetail({ token, scheduleId: schedule.id || schedule.schedule_id });
      if (isCreatedImsReservationDetailMatch({ detail, schedule, payload })) fastMatches.push(detail);
    }

    if (fastMatches.length === 1) return fastMatches[0];
    if (fastMatches.length > 1) {
      return fastMatches.sort((a, b) => Number(b.id || 0) - Number(a.id || 0))[0];
    }

    const matches = await findImsReservationsByListApi({
      token,
      predicate: async (schedule) => {
        const sameCar = normalizeText(schedule?.car_identity || schedule?.car_number) === normalizeText(payload.carNumber);
        const sameStart = normalizeImsDateTime(schedule?.start_at) === normalizeImsDateTime(payload.rentalAt);
        const sameEnd = normalizeImsDateTime(schedule?.end_at) === normalizeImsDateTime(payload.returnAt);
        if (!sameCar || !sameStart || !sameEnd) return null;

        const detail = await fetchImsScheduleDetail({ token, scheduleId: schedule.id });
        return isCreatedImsReservationDetailMatch({ detail, schedule, payload }) ? detail : null;
      },
    });

    if (matches.length === 1) return matches[0];
    if (matches.length > 1) {
      return matches.sort((a, b) => Number(b.id || 0) - Number(a.id || 0))[0];
    }
    await delay(1200 * attempt);
  }
  return null;
}

function isCreatedImsReservationDetailMatch({ detail, schedule, payload }) {
  if (!detail) return false;
  const reservation = detail?.reservation || {};
  const detailCar = detail?.car?.car_identity || detail?.car_identity || schedule?.car_identity || schedule?.car;
  const sameDetailCar = normalizeText(detailCar) === normalizeText(payload.carNumber);
  const sameCustomer = normalizeText(reservation.customer_name) === normalizeText(payload.customerName);
  const samePhone = digitsOnly(reservation.customer_contact) === digitsOnly(payload.customerPhone);
  const sameAddress = !payload.address || normalizeText(reservation.pickup_address) === normalizeText(payload.address);
  const sameWindow =
    normalizeImsDateTime(detail?.start_at || schedule?.start_at || schedule?.start) === normalizeImsDateTime(payload.rentalAt) &&
    normalizeImsDateTime(detail?.end_at || schedule?.end_at || schedule?.end) === normalizeImsDateTime(payload.returnAt);

  return sameDetailCar && sameCustomer && samePhone && sameAddress && sameWindow;
}

async function findImsReservationsBySearchApi({ token, payload, page = 1 }) {
  const startDate = extractDate(payload.rentalAt || payload.rentalDate || payload.startDate);
  const endDate = extractDate(payload.returnAt || payload.endDate || payload.returnDate) || startDate;
  const url = new URL('https://api.rencar.co.kr/v2/company-car-schedules/reservations');
  url.searchParams.set('page', String(page));
  url.searchParams.set('base_date', startDate);
  url.searchParams.set('rental_type', 'all');
  url.searchParams.set('status', 'all');
  url.searchParams.set('date_option', 'start_at');
  url.searchParams.set('start', startDate);
  url.searchParams.set('end', endDate);
  if (payload.carNumber) {
    url.searchParams.set('option', 'car_identity');
    url.searchParams.set('search', payload.carNumber);
  }

  const response = await fetch(url, { headers: buildImsApiHeaders(token) });
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new Error(resolveApiErrorMessage(json, response.status, 'IMS reservation search lookup failed'));
  }
  return Array.isArray(json?.schedules) ? json.schedules : [];
}

async function findImsReservationsByListApi({ token, predicate, maxPages = 120 }) {
  const matches = [];
  for (let page = 1; page <= maxPages; page += 1) {
    const url = new URL('https://api.rencar.co.kr/v2/company-car-schedules');
    url.searchParams.set('page', String(page));
    const response = await fetch(url, { headers: buildImsApiHeaders(token) });
    const json = await readJsonResponse(response);
    if (!response.ok) {
      throw new Error(resolveApiErrorMessage(json, response.status, 'IMS schedule list lookup failed'));
    }

    const schedules = Array.isArray(json?.schedules) ? json.schedules : [];
    for (const schedule of schedules) {
      const match = await predicate(schedule);
      if (match) matches.push(match);
    }

    const totalPage = Number(json?.total_page || 0);
    if (schedules.length === 0 || (totalPage > 0 && page >= totalPage)) break;
  }
  return matches;
}

async function fetchImsScheduleDetail({ token, scheduleId }) {
  const response = await fetch(
    `https://api.rencar.co.kr/v2/company-car-schedules/${encodeURIComponent(scheduleId)}`,
    { headers: buildImsApiHeaders(token) },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) return null;
  return json?.schedule || json;
}

async function fetchImsPartnerRentRequestDetail({ token, requestId }) {
  const id = stringifyNullable(requestId);
  if (!id) return null;
  const response = await fetch(
    `https://api.rencar.co.kr/v2/rent-requests/${encodeURIComponent(id)}`,
    { headers: buildImsApiHeaders(token) },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) return null;
  return json?.data || json;
}

function mergeImsScheduleForImport(detail, listSchedule, requestDetail = null) {
  const reservation = detail?.reservation || listSchedule?.reservation || listSchedule?.detail || null;
  const detailInfo = detail?.detail || listSchedule?.detail || null;
  return {
    ...listSchedule,
    ...detail,
    reservation,
    detail: detailInfo,
    requestDetail,
  };
}

function toImsReservationImportItem(schedule) {
  const reservation = schedule?.reservation || schedule?.detail || {};
  const detail = schedule?.detail || schedule?.reservation || {};
  const request = schedule?.requestDetail || {};
  return {
    scheduleId: stringifyNullable(schedule?.id || schedule?.schedule_id),
    detailId: stringifyNullable(reservation?.id || detail?.id || schedule?.detail_id),
    reservationNumber: stringifyNullable(reservation?.id || detail?.id || schedule?.id || schedule?.schedule_id),
    status: stringifyNullable(schedule?.status),
    detailStatus: stringifyNullable(reservation?.status || detail?.status || request?.state),
    reservationType: stringifyNullable(reservation?.rental_type || detail?.rental_type || request?.period_type),
    carNumber: stringifyNullable(schedule?.car?.car_identity || request?.response_car?.car_identity || schedule?.car_identity || schedule?.car_number),
    carName: stringifyNullable(schedule?.car?.model || schedule?.car?.car_model || schedule?.car?.car_name || request?.response_car?.car_name || schedule?.car_name),
    customerName: stringifyNullable(reservation?.customer_name || detail?.customer_name || request?.self_contract_name || request?.driver_name || schedule?.customer_name),
    customerPhone: digitsOnly(reservation?.customer_contact || detail?.customer_contact || request?.self_contract_contact || request?.original_customer_contact || schedule?.customer_contact),
    birthDate: stringifyNullable(reservation?.customer_birth_date || reservation?.customer_birth || detail?.customer_birth_date || detail?.customer_birth || request?.driver_date_of_birth),
    price: stringifyNullable(reservation?.price || reservation?.total_price || reservation?.payment_amount || detail?.price || detail?.total_price || detail?.payment_amount || request?.paid_cost || request?.response_car?.price),
    rentalAt: normalizeImsDateTime(schedule?.start_at || request?.pickup_at),
    returnAt: normalizeImsDateTime(schedule?.end_at || request?.dropoff_at),
    pickupLocation: stringifyNullable(reservation?.pickup_address || detail?.pickup_address || request?.pickup_address),
    dropoffLocation: stringifyNullable(reservation?.dropoff_address || detail?.dropoff_address || request?.dropoff_address),
    recommenderName: stringifyNullable(reservation?.recommender?.name || reservation?.recommender_name || detail?.recommender_name || request?.orderer),
    title: stringifyNullable(schedule?.title || schedule?.memo || reservation?.reservation_memo),
  };
}

function toImsInsuranceClaimImportItem(claim) {
  return {
    sourceType: 'ims_insurance_claim',
    claimId: stringifyNullable(claim?.id),
    status: stringifyNullable(claim?.claim_state),
    carNumber: stringifyNullable(claim?.rent_car_number),
    carName: stringifyNullable(claim?.car_model),
    customerName: stringifyNullable(claim?.customer_name),
    customerPhone: digitsOnly(claim?.customer_contact),
    rentalAt: normalizeImsDateTime(claim?.delivered_at),
    returnAt: normalizeImsDateTime(claim?.expect_return_date || claim?.return_date),
    pickupLocation: stringifyNullable(claim?.customer_address),
    insuranceCompany: stringifyNullable(claim?.claim_user_company),
    claimUserName: stringifyNullable(claim?.claim_user_name),
    title: [
      stringifyNullable(claim?.business_name),
      stringifyNullable(claim?.claim_state),
    ].filter((value) => value.trim()).join(' | '),
  };
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildImsCreateScheduleBody({ payload, carId }) {
  return {
    car_ids: [carId],
    start_at: toUtcIsoFromKstText(payload.rentalAt),
    end_at: toUtcIsoFromKstText(payload.returnAt),
    reservation: {
      rental_type: 'daily',
      cost: payload.totalFee,
      is_delivery: payload.useDelivery === true,
      pickup_address: payload.address,
      dropoff_address: '',
      insurance_company_id: null,
      registration_num: '',
      customer_name: payload.customerName,
      customer_contact: payload.customerPhone,
      driver_name: payload.customerName,
      driver_contact: payload.customerPhone,
      recommender_id: null,
      reservation_memo: payload.memo,
      customer_car_number: '',
      delivery_user_id: null,
    },
    is_send_customer_message: false,
  };
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

async function readJsonResponse(response) {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

function resolveApiErrorMessage(json, status, fallback = 'IMS API failed') {
  return stringifyNullable(json?.message || json?.msg || json?.error || json?.detail || json?.raw) || `${fallback} (${status})`;
}

function normalizeImsReturnDoneAt(value) {
  const text = String(value || '').trim();
  let match = text.match(/^(\d{4})-(\d{2})-(\d{2})[ T-](\d{2})[:\-](\d{2})/);
  if (!match) return text;
  return `${match[1]}-${match[2]}-${match[3]}-${match[4]}-${match[5]}`;
}

function toImsLocalApiDateTime(value) {
  return normalizeImsDateTime(value).replace(' ', 'T') + ':00';
}

function toUtcIsoFromKstText(value) {
  const text = normalizeImsDateTime(value);
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$/);
  if (!match) throw new Error(`invalid ims datetime: ${value}`);
  const [, year, month, day, hour, minute] = match;
  return new Date(Date.UTC(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hour) - 9,
    Number(minute),
    0,
    0,
  )).toISOString();
}

function findFirstNestedValue(value, keys) {
  if (!value || typeof value !== 'object') return null;
  const stack = [value];
  const seen = new Set();
  while (stack.length > 0) {
    const current = stack.pop();
    if (!current || typeof current !== 'object' || seen.has(current)) continue;
    seen.add(current);
    for (const key of keys) {
      if (current[key] !== undefined && current[key] !== null && current[key] !== '') return current[key];
    }
    for (const child of Object.values(current)) {
      if (child && typeof child === 'object') stack.push(child);
    }
  }
  return null;
}

function appendMemoPart(memo, part) {
  const cleanMemo = String(memo || '').trim();
  if (!cleanMemo) return part;
  return `${cleanMemo} | ${part}`;
}

function buildLinkKey(payload) {
  return payload?.reservationId ? `OPS:${payload.reservationId}` : '';
}

function extractDate(value) {
  return String(value || '').trim().split(/\s+/)[0] || '';
}

function addDaysToDateText(value, days) {
  const text = extractDate(value);
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return text;
  const utc = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  utc.setUTCDate(utc.getUTCDate() + Number(days || 0));
  const y = utc.getUTCFullYear();
  const m = String(utc.getUTCMonth() + 1).padStart(2, '0');
  const d = String(utc.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function normalizeImsDateTime(value) {
  const text = String(value || '').trim().replace('T', ' ');
  const match = text.match(/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})/);
  if (!match) return text;
  return `${match[1]} ${match[2]}`;
}

function normalizeText(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function digitsOnly(value) {
  return String(value || '').replace(/\D+/g, '');
}

function stringifyNullable(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}
