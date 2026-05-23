import http from 'node:http';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile, parseReservationInput, validateConfig } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
await loadEnvFile(path.resolve(__dirname, '../.env'));

const config = buildConfig(process.env);

if (process.argv.includes('--check')) {
  console.log(JSON.stringify({
    hasOpenAiApiKey: Boolean(config.openAiApiKey),
    openAiModel: config.openAiModel,
    host: config.host,
    port: config.port,
    timeoutMs: config.timeoutMs,
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

    if (req.url === '/ims/search-insurance-claims') {
      if (req.method !== 'POST') {
        return sendMethodNotAllowed(res, ['POST']);
      }
      const body = await readJsonBody(req);
      const payload = normalizeImsInsuranceClaimSearchPayload(body);
      const result = await searchImsInsuranceClaimsForDispatch(payload);
      return sendJson(res, 200, { ok: true, payload, result });
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

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 5 * 1024 * 1024) {
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

  return {
    code: 'SUCCESS',
    totalCount: matches.length,
    items: matches.map((schedule) => toImsReservationImportItem(schedule)),
  };
}

async function searchImsInsuranceClaimsForDispatch(payload) {
  const token = await fetchImsAccessToken();
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
