import crypto from 'node:crypto';

export function buildImsApiHeaders(token, { contentType = false, auth = true } = {}) {
  return {
    Accept: 'application/json, text/plain, */*',
    Origin: 'https://imsform.com',
    Referer: 'https://imsform.com/',
    ...(contentType ? { 'Content-Type': 'application/json;charset=UTF-8' } : {}),
    ...(auth && token ? { Authorization: `JWT ${token}` } : {}),
  };
}

export async function fetchImsAccessToken({ env = process.env } = {}) {
  const username = text(env.IMS_ID).trim();
  const rawPassword = text(env.IMS_PW || env.IMS_PASSWORD).trim();
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
  const token = text(json?.access_token);
  if (!response.ok || !token) throw new Error(resolveApiErrorMessage(json, response.status, 'IMS auth failed'));
  return token;
}

export async function fetchImsNormalScheduleDetail({ token, scheduleId }) {
  const id = text(scheduleId).trim();
  if (!id) throw new Error('schedule_id_required');
  const response = await fetch(
    `https://api.rencar.co.kr/v2/company-car-schedules/${encodeURIComponent(id)}`,
    { headers: buildImsApiHeaders(token) },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new Error(resolveApiErrorMessage(json, response.status, 'IMS schedule detail lookup failed'));
  }
  return json?.schedule || json;
}

export async function fetchImsInsuranceClaimDetail({ token, claimId }) {
  const id = text(claimId).trim();
  if (!id) throw new Error('claim_id_required');
  const response = await fetch(
    `https://api.rencar.co.kr/v2/rencar-claims/${encodeURIComponent(id)}`,
    { headers: buildImsApiHeaders(token) },
  );
  const json = await readJsonResponse(response);
  if (!response.ok) {
    throw new Error(resolveApiErrorMessage(json, response.status, 'IMS insurance claim detail lookup failed'));
  }
  return json?.datas || json?.data || json?.claim || json;
}

export async function fetchImsUsingCarNormalSchedules({
  token,
  startDate,
  endDate,
  page = 1,
  maxPages = 20,
} = {}) {
  const rows = [];
  const pages = [];
  const errors = [];
  let totalPage = 1;

  for (let currentPage = toPositiveInt(page, 1); currentPage <= totalPage && currentPage <= maxPages; currentPage += 1) {
    const url = new URL('https://api.rencar.co.kr/v2/company-car-schedules/reservations');
    url.searchParams.set('page', String(currentPage));
    if (startDate) url.searchParams.set('base_date', startDate);
    url.searchParams.set('rental_type', 'all');
    url.searchParams.set('status', 'using_car');
    url.searchParams.set('date_option', 'start_at');
    if (startDate) url.searchParams.set('start', startDate);
    if (endDate) url.searchParams.set('end', endDate);

    const response = await fetch(url, { headers: buildImsApiHeaders(token) });
    const json = await readJsonResponse(response);
    pages.push({ page: currentPage, ok: response.ok, status: response.status });
    if (!response.ok) {
      errors.push(resolveApiErrorMessage(json, response.status, 'IMS using-car normal schedule lookup failed'));
      break;
    }

    const schedules = Array.isArray(json?.schedules) ? json.schedules : [];
    rows.push(...schedules);
    totalPage = toPositiveInt(json?.total_page || json?.totalPage, totalPage);
    if (schedules.length === 0 || currentPage >= totalPage) break;
  }

  return {
    sourceType: 'normal_schedule',
    ok: errors.length === 0,
    rows,
    pages,
    errors,
  };
}

export async function fetchImsUsingCarInsuranceClaims({
  token,
  startDate,
  endDate,
  page = 1,
  maxPages = 20,
} = {}) {
  const rows = [];
  const pages = [];
  const errors = [];
  let totalPage = 1;

  for (let currentPage = toPositiveInt(page, 1); currentPage <= totalPage && currentPage <= maxPages; currentPage += 1) {
    const url = new URL('https://api.rencar.co.kr/v2/rencar-claims');
    url.searchParams.set('page', String(currentPage));
    url.searchParams.set('periodOption', 'using_car');
    if (startDate) url.searchParams.set('startdate', startDate);
    if (endDate) url.searchParams.set('enddate', endDate);

    const response = await fetch(url, { headers: buildImsApiHeaders(token) });
    const json = await readJsonResponse(response);
    pages.push({ page: currentPage, ok: response.ok, status: response.status });
    if (!response.ok) {
      errors.push(resolveApiErrorMessage(json, response.status, 'IMS using-car insurance claim lookup failed'));
      break;
    }

    const claims = Array.isArray(json?.claimList) ? json.claimList : [];
    rows.push(...claims);
    totalPage = toPositiveInt(json?.totalPage || json?.total_page, totalPage);
    if (claims.length === 0 || currentPage >= totalPage) break;
  }

  return {
    sourceType: 'insurance_claim',
    ok: errors.length === 0,
    rows,
    pages,
    errors,
  };
}

export function normalizeImsDateTime(value) {
  const source = text(value).trim().replace('T', ' ');
  const match = source.match(/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})/);
  if (!match) return source;
  return `${match[1]} ${match[2]}`;
}

export function normalizeCarNumber(value) {
  return text(value).replace(/\s+/g, '').trim();
}

export function readImsNormalScheduleStatus(detail = {}) {
  const reservation = detail?.reservation || detail?.detail || {};
  return text(
    detail?.status
    || detail?.state
    || detail?.status_raw
    || reservation?.status
    || reservation?.state,
  ).trim();
}

export function readImsNormalScheduleCarNumber(detail = {}) {
  const reservation = detail?.reservation || detail?.detail || {};
  return text(
    detail?.car?.car_identity
    || detail?.car_identity
    || detail?.car_number
    || reservation?.car?.car_identity
    || reservation?.car_identity
    || reservation?.car_number,
  ).trim();
}

export function readImsInsuranceClaimState(claim = {}) {
  return text(claim?.claim_state || claim?.state || claim?.status).trim();
}

export function readImsInsuranceClaimCarNumber(claim = {}) {
  return text(claim?.rent_car_number || claim?.car_number || claim?.car?.car_identity).trim();
}

export function findMatchingInsuranceReturnContract({ claim = {}, carNumber = '' } = {}) {
  const targetCarNumber = normalizeCarNumber(carNumber);
  const contracts = readInsuranceContracts(claim);
  const matches = contracts.filter((contract) => {
    const contractCarNumber = normalizeCarNumber(
      contract?.rent_car_number
      || contract?.car_number
      || contract?.car?.car_identity
      || contract?.rent_car?.car_identity,
    );
    return targetCarNumber && contractCarNumber === targetCarNumber;
  });
  if (matches.length !== 1) {
    return { ok: false, reason: matches.length === 0 ? 'insurance_contract_not_found' : 'insurance_contract_ambiguous', contract: null };
  }
  const contract = matches[0];
  const returnDate = text(
    contract?.return_date
    || contract?.returned_at
    || contract?.returned_date
    || contract?.actual_return_date,
  ).trim();
  if (!returnDate) return { ok: false, reason: 'insurance_contract_return_date_missing', contract };
  return { ok: true, reason: '', contract, returnDate: normalizeImsDateTime(returnDate) };
}

function readInsuranceContracts(claim = {}) {
  const candidates = [
    claim?.contracts,
    claim?.contractList,
    claim?.details,
    claim?.datas?.contracts,
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) return candidate;
  }
  return [];
}

export async function readJsonResponse(response) {
  const body = await response.text();
  if (!body) return {};
  try {
    return JSON.parse(body);
  } catch {
    return { raw: body };
  }
}

export function resolveApiErrorMessage(json, status, fallback = 'IMS API failed') {
  const value = json?.message || json?.msg || json?.error || json?.detail || json?.raw;
  return stringifyErrorText(value) || `${fallback} (${status})`;
}

function stringifyErrorText(value) {
  if (value === null || value === undefined || value === '') return '';
  if (typeof value === 'string') return value;
  if (value instanceof Error) return value.message || '';
  if (typeof value === 'object') {
    const direct = value.message || value.msg || value.error || value.reason || value.detail || value.details || value.code;
    if (direct && direct !== value) return stringifyErrorText(direct);
    try { return JSON.stringify(value); } catch { return 'unknown_object_error'; }
  }
  return String(value);
}

function text(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}

function toPositiveInt(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}
