import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { buildConfig, loadEnvFile, parseReservationInput, validateConfig } from './parser-core.js';

const execFileAsync = promisify(execFile);

const __dirname = path.dirname(fileURLToPath(import.meta.url));
await loadEnvFile(path.resolve(__dirname, '../.env'));
await loadEnvFile(path.resolve(__dirname, '../../../../tools/playwright/.env'));

const config = buildConfig(process.env);

if (process.argv.includes('--check')) {
  console.log(JSON.stringify({
    hasOpenAiApiKey: Boolean(config.openAiApiKey),
    openAiModel: config.openAiModel,
    host: config.host,
    port: config.port,
    timeoutMs: config.timeoutMs
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
  if (error?.message === 'invalid_json') return 400;
  if (error?.message === 'payload_too_large') return 413;
  if (error?.name === 'AbortError') return 504;
  return 500;
}

function resolveErrorCode(error) {
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

  const match = await findCreatedImsReservationForBinding(payload);
  if (!match) {
    return {
      ...result,
      externalStatus: 'failed',
      linkKey: buildLinkKey(payload),
      errorText: 'IMS id 확보 실패',
    };
  }

  return {
    ...result,
    externalStatus: 'linked',
    externalReservationId: stringifyNullable(match.schedule_id || match.id),
    externalDetailId: stringifyNullable(match.detail_id || match?.reservation?.id),
    linkKey: buildLinkKey(payload),
    matchedReservation: match,
  };
}

async function searchImsReservationsForImport(payload) {
  const exportResult = await exportImsReservationsForDateRange({
    startDate: payload.rentalDate,
    endDate: payload.endDate || addDaysToDateText(payload.rentalDate, 3),
    baseDate: payload.rentalDate,
  });
  if (!exportResult?.ok || !exportResult?.flatPath) {
    return {
      code: 'ERROR',
      message: exportResult?.message || 'IMS 예약 조회 실패',
      items: [],
    };
  }

  const raw = await fs.readFile(exportResult.flatPath, 'utf8');
  const rows = JSON.parse(raw);
  if (!Array.isArray(rows)) {
    return { code: 'SUCCESS', items: [] };
  }

  const customerName = normalizeText(payload.customerName);
  const carNumber = normalizeText(payload.carNumber);
  const items = rows
    .filter((row) => {
      const matchesName = !customerName || normalizeText(row?.customer_name).includes(customerName);
      const matchesCar = !carNumber || normalizeText(row?.car_number).includes(carNumber);
      const matchesDate = extractDate(normalizeImsDateTime(row?.start_at)) === payload.rentalDate;
      return matchesName && matchesCar && matchesDate;
    })
    .map((row) => ({
      scheduleId: stringifyNullable(row?.schedule_id),
      detailId: stringifyNullable(row?.detail_id),
      reservationNumber: stringifyNullable(row?.detail_id || row?.schedule_id),
      status: stringifyNullable(row?.status),
      detailStatus: stringifyNullable(row?.detail_status),
      reservationType: stringifyNullable(row?.reservation_type),
      carNumber: stringifyNullable(row?.car_number),
      carName: stringifyNullable(row?.car_name),
      customerName: stringifyNullable(row?.customer_name),
      customerPhone: digitsOnly(row?.customer_contact),
      rentalAt: normalizeImsDateTime(row?.start_at),
      returnAt: normalizeImsDateTime(row?.end_at),
      pickupLocation: stringifyNullable(row?.pickup_address),
      dropoffLocation: stringifyNullable(row?.dropoff_address),
      recommenderName: stringifyNullable(row?.recommender_name),
      title: stringifyNullable(row?.title),
    }))
    .filter((item) => item.scheduleId && item.detailId);

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

  const scheduleId = findFirstNestedValue(json, [
    'schedule_id',
    'scheduleId',
    'company_car_schedule_id',
    'companyCarScheduleId',
    'id',
  ]);
  const detailId = findFirstNestedValue(json, [
    'detail_id',
    'detailId',
    'reservation_id',
    'reservationId',
  ]);

  return {
    code: 'SUCCESS',
    message: '',
    externalStatus: scheduleId ? 'linked' : undefined,
    externalReservationId: stringifyNullable(scheduleId),
    externalDetailId: stringifyNullable(detailId),
    linkKey: buildLinkKey(payload),
    apiResult: json,
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
  const rawPassword = String(process.env.IMS_PW || '').trim();
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

async function findCreatedImsReservationForBinding(payload) {
  const exportResult = await exportImsReservationsForBindingLookup(payload);
  if (!exportResult?.ok || !exportResult?.flatPath) return null;

  const raw = await fs.readFile(exportResult.flatPath, 'utf8');
  const rows = JSON.parse(raw);
  if (!Array.isArray(rows)) return null;

  const matches = rows.filter((row) => isSameReservationForBinding(row, payload));
  if (matches.length !== 1) return null;
  return matches[0];
}

async function exportImsReservationsForBindingLookup(payload) {
  return exportImsReservationsForDateRange({
    startDate: extractDate(payload.rentalAt),
    endDate: extractDate(payload.returnAt),
    baseDate: extractDate(payload.rentalAt),
  });
}

async function exportImsReservationsForDateRange({ startDate, endDate, baseDate }) {
  const scriptPath = await findFirstExistingPath([
    path.resolve(__dirname, '../../../../tools/playwright/scripts/ims-reservations-export.js'),
    path.resolve(process.cwd(), '../../tools/playwright/scripts/ims-reservations-export.js'),
    path.resolve(process.cwd(), '../tools/playwright/scripts/ims-reservations-export.js'),
  ]);

  const outputDir = path.join(
    process.cwd(),
    '.ims-create-lookup',
    `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
  );

  const result = await execFileAsync(
    'node',
    [scriptPath, outputDir, startDate, endDate, baseDate || startDate],
    {
      cwd: process.cwd(),
      env: process.env,
      timeout: 1000 * 60 * 3,
      maxBuffer: 1024 * 1024,
    },
  );

  const lines = `${result.stdout || ''}\n${result.stderr || ''}`
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const lastJsonLine = [...lines]
    .reverse()
    .find((line) => line.startsWith('{') && line.endsWith('}'));
  if (!lastJsonLine) return { ok: false, message: 'missing ims export result' };
  return JSON.parse(lastJsonLine);
}

function isSameReservationForBinding(row, payload) {
  return normalizeText(row?.car_number) === normalizeText(payload.carNumber) &&
    normalizeText(row?.customer_name) === normalizeText(payload.customerName) &&
    digitsOnly(row?.customer_contact) === digitsOnly(payload.customerPhone) &&
    normalizeImsDateTime(row?.start_at) === normalizeImsDateTime(payload.rentalAt) &&
    normalizeImsDateTime(row?.end_at) === normalizeImsDateTime(payload.returnAt) &&
    normalizeText(row?.pickup_address) === normalizeText(payload.address);
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
  const date = new Date(`${extractDate(value)}T00:00:00+09:00`);
  if (Number.isNaN(date.getTime())) return extractDate(value);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
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

async function runImsReservationScript(payload) {
  const scriptPath = await findFirstExistingPath([
    path.resolve(__dirname, '../../../../tools/playwright/scripts/ims-reservation-draft.js'),
    path.resolve(process.cwd(), '../../tools/playwright/scripts/ims-reservation-draft.js'),
    path.resolve(process.cwd(), '../tools/playwright/scripts/ims-reservation-draft.js'),
  ]);

  let stdout = '';
  let stderr = '';
  try {
    const result = await execFileAsync('node', [scriptPath, JSON.stringify(payload)], {
      cwd: process.cwd(),
      env: {
        ...process.env,
        IMS_SAVE: process.env.IMS_SAVE || 'false',
      },
      timeout: 1000 * 60 * 2,
      maxBuffer: 1024 * 1024,
    });
    stdout = result.stdout || '';
    stderr = result.stderr || '';
  } catch (error) {
    stdout = error.stdout || '';
    stderr = error.stderr || '';
  }

  const lines = `${stdout}\n${stderr}`
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  const lastJsonLine = [...lines]
    .reverse()
    .find((line) => line.startsWith('{') && line.endsWith('}'));
  if (!lastJsonLine) {
    return { code: 'ERROR', message: stdout || stderr || 'missing ims result' };
  }

  return JSON.parse(lastJsonLine);
}

async function findFirstExistingPath(paths) {
  for (const candidate of paths) {
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // try next path
    }
  }

  throw new Error(`IMS script not found: ${paths.join(' | ')}`);
}
