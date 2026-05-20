import fs from 'node:fs/promises';
import path from 'node:path';

const EMPTY_KR_FIELDS = {
  '예약번호': null,
  '차량번호': null,
  '차종': null,
  '대여일': null,
  '반납일': null,
  '배반차위치': null,
  '임차인': null,
  '고객번호': null,
  '생년월일': null,
  '소개처': null,
  '결제금액': null,
  '예약상태': '예약중'
};

export async function loadEnvFile(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    for (const rawLine of content.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line || line.startsWith('#')) continue;
      const idx = line.indexOf('=');
      if (idx === -1) continue;
      const key = line.slice(0, idx).trim();
      const value = line.slice(idx + 1).trim();
      if (!(key in process.env)) process.env[key] = value;
    }
  } catch {
    // ignore missing env file
  }
}

export function buildConfig(env = process.env) {
  return {
    openAiApiKey: String(env.OPENAI_API_KEY || '').trim(),
    openAiModel: String(env.OPENAI_MODEL || 'gpt-4.1-mini').trim(),
    host: String(env.AI_PARSER_HOST || '127.0.0.1').trim(),
    port: Number(env.AI_PARSER_PORT || 43110),
    timeoutMs: Number(env.AI_PARSER_TIMEOUT_MS || 30000),
    opsReservationEventSecret: String(env.OPS_APP_RESERVATION_EVENT_SECRET || '').trim(),
    supabaseUrl: String(env.SUPABASE_URL || '').trim(),
    supabaseServiceRoleKey: String(env.SUPABASE_SERVICE_ROLE_KEY || '').trim(),
    reservationEventTimestampToleranceMs: Number(env.OPS_APP_RESERVATION_EVENT_TIMESTAMP_TOLERANCE_MS || 5 * 60 * 1000)
  };
}

export function validateConfig(config) {
  if (!config.openAiApiKey) throw new Error('missing OPENAI_API_KEY');
}

export async function parseReservationInput({ text = null, imageBase64 = null, mimeType = null } = {}, config = buildConfig()) {
  validateConfig(config);

  const normalizedText = normalizeValue(text);
  const imageDataUrl = normalizeImageDataUrl({ imageBase64, mimeType });
  if (!normalizedText && !imageDataUrl) {
    throw new Error('text or imageBase64 is required');
  }

  const first = await requestParseResult({ text: normalizedText, imageDataUrl, config });
  const firstValidation = validateParsedDateMeta(first);
  if (firstValidation.ok) {
    return buildAppResponse(first, { usedImage: Boolean(imageDataUrl), repairAttempted: false });
  }

  const repaired = await requestParseResult({
    text: normalizedText,
    imageDataUrl,
    config,
    extraInstructions: buildDateRepairPrompt(first, firstValidation)
  });
  const merged = mergeParsedRepairResult(first, repaired);
  const repairedValidation = validateParsedDateMeta(merged);
  const finalParsed = repairedValidation.ok ? merged : first;

  return buildAppResponse(finalParsed, {
    usedImage: Boolean(imageDataUrl),
    repairAttempted: true,
    repairApplied: repairedValidation.ok
  });
}

async function requestParseResult({ text, imageDataUrl = null, config, extraInstructions = null }) {
  const userContent = [];
  if (text) userContent.push({ type: 'text', text });
  if (imageDataUrl) userContent.push({ type: 'image_url', image_url: { url: imageDataUrl } });
  if (extraInstructions) userContent.push({ type: 'text', text: extraInstructions });
  if (!userContent.length) throw new Error('empty input for parse');

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeoutMs);

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.openAiApiKey}`
      },
      body: JSON.stringify({
        model: config.openAiModel,
        temperature: 0,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: buildSystemPrompt() },
          { role: 'user', content: (imageDataUrl || extraInstructions) ? userContent : text }
        ]
      })
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`openai error: ${response.status} ${body}`);
    }

    const data = await response.json();
    const content = String(data?.choices?.[0]?.message?.content || '').trim();
    if (!content) throw new Error('empty model response');
    return normalizeParseResult(content, text || '');
  } finally {
    clearTimeout(timeout);
  }
}

function buildSystemPrompt() {
  const seoulNow = getSeoulNowDateTimeString();

  return [
    'You convert Korean car rental reservation messages into fixed JSON only.',
    'The input may be plain text, a screenshot, or a photographed document.',
    'If an image is provided, read the visible reservation content from the image.',
    'Scope: support new reservation creation parsing only.',
    'Do not support cancellation, dispatch, return completion, admin actions, or unrelated chat.',
    'Do not create reservations yourself.',
    'Return JSON only.',
    'No markdown. No code fences. No explanations.',
    'Use only explicit information visible in the current input.',
    'Never guess missing facts. Use null for unknown or unclear values.',
    'If the image or text is too unclear to read confidently, leave that field null.',
    'If the message is not related to reservation creation, return intent "ignore".',
    'If the message is about unsupported operations, return intent "unsupported".',
    'If the message asks to create a reservation, return intent "reservation_create".',
    'Vehicle rules:',
    '- The primary vehicle key is 차량번호, not 차종.',
    '- 차량번호 means the Korean license plate / registration number.',
    '- If the input contains both a plate number and a model, put the plate in 차량번호 and the model in 차종.',
    '- If no full plate number exists or the image is unclear, set 차량번호 to null.',
    '- Do not output only the last 4 digits as 차량번호.',
    'Request number rules:',
    '- If the input contains 요청번호 or 예약번호, map it to 예약번호.',
    '- Keep the exact visible identifier text when possible.',
    'Customer phone rules:',
    '- 고객번호 should capture the visible reservation/contact phone number from labels such as 예약자 연락처, 연락처, 운전자 연락처, or 고객번호.',
    'Payment rules:',
    '- 결제금액 must come from 총요금 only when 총요금 is explicitly present.',
    '- Ignore other money-like values unless they are clearly labeled 총요금.',
    '- Preserve the visible amount text when possible, for example "198,000원".',
    '- If 총요금 is not present, set 결제금액 to null.',
    `Current Seoul time: ${seoulNow}`,
    'Datetime rules:',
    '- 대여일 and 반납일 must be returned only in this exact format: YYYY-MM-DD HH:mm:ss.',
    '- Convert natural language date/time in the user input into that exact format before returning JSON when possible.',
    '- If the date is clear but the time is missing, use 00:00:00.',
    '- If either datetime cannot be determined confidently in that exact format, set it to null.',
    '- Never return Korean natural-language date strings such as "4월 17일 오후 5시".',
    '- Never return partial datetime strings such as date-only or minute-missing values.',
    '- When the source date omits the year, infer the year using current Seoul time.',
    '- If the pickup date/time without a year would already be in the past this year, use next year.',
    '- Do not take a year from phone numbers, reservation numbers, customer numbers, or unrelated numeric text.',
    '- Treat the year as explicit only when the year is visibly attached to the rental date expression itself.',
    'Reservation status rules:',
    '- 예약상태 must be one of: 예약중, 배차중, 반납완료, 예약취소.',
    '- For reservation_create, set 예약상태 to "예약중".',
    'Output schema:',
    JSON.stringify({
      intent: 'reservation_create',
      fields: EMPTY_KR_FIELDS,
      meta: {
        date: {
          yearInSource: null,
          yearBasis: null,
          pickupRaw: null,
          returnRaw: null
        }
      },
      message: null
    })
  ].join('\n');
}

function normalizeParseResult(content, sourceText = '') {
  const fallback = emptyParseResult('ignore');

  try {
    const parsed = JSON.parse(content);
    const tableShape = isPlainObject(parsed) && !('fields' in parsed) ? parsed : null;
    const incomingFields = tableShape || (parsed?.fields && typeof parsed.fields === 'object' ? parsed.fields : {});
    const result = emptyParseResult(normalizeIntent(parsed?.intent));

    for (const key of Object.keys(result.fields)) {
      result.fields[key] = normalizeFieldValue(key, incomingFields[key], result.intent);
    }

    result.fields['차량번호'] = normalizeVehicleNumber(result.fields['차량번호']);
    result.fields['예약상태'] = normalizeReservationStatus(result.fields['예약상태']) || (result.intent === 'reservation_create' ? '예약중' : null);
    applyParsedFieldFallbacks(result, sourceText);
    result.meta = normalizeParseMeta(parsed?.meta, incomingFields);

    const hasMeaningfulValue = Object.entries(result.fields).some(([key, value]) => key === '예약상태' ? false : value !== null);
    if ((result.intent === 'reservation_create') && !hasMeaningfulValue) {
      result.intent = 'ignore';
    }
    result.message = normalizeValue(parsed?.message);
    return result;
  } catch {
    return fallback;
  }
}

function buildAppResponse(parsed, options = {}) {
  const fields = mapToAppFields(parsed?.fields || {});
  const missing = collectMissingFields(fields);
  const warnings = collectWarnings(parsed, fields);

  return {
    ok: parsed?.intent === 'reservation_create',
    fields,
    missing,
    warnings,
    meta: {
      intent: parsed?.intent || 'ignore',
      usedImage: Boolean(options.usedImage),
      repairAttempted: Boolean(options.repairAttempted),
      repairApplied: Boolean(options.repairApplied),
      source: 'openai',
      date: parsed?.meta?.date || null,
      message: parsed?.message || null
    }
  };
}

function mapToAppFields(fields) {
  const sharedLocation = normalizeValue(fields['배반차위치']);
  return {
    reservationNumber: normalizeValue(fields['예약번호']),
    customerName: normalizeValue(fields['임차인']),
    customerPhone: digitsOnly(fields['고객번호']) || null,
    birthDate: normalizeBirthDate(fields['생년월일']),
    referrer: normalizeValue(fields['소개처']),
    price: normalizeMoney(fields['결제금액']),
    carNumber: normalizeVehicleNumber(fields['차량번호']),
    carName: normalizeValue(fields['차종']),
    pickupAt: normalizeStandardDateTime(fields['대여일']),
    returnAt: normalizeStandardDateTime(fields['반납일']),
    pickupLocation: sharedLocation,
    returnLocation: sharedLocation,
    note: null
  };
}

function collectMissingFields(fields) {
  const result = [];
  if (!fields.customerName) result.push('customerName');
  if (!fields.pickupAt) result.push('pickupAt');
  if (!fields.returnAt) result.push('returnAt');
  if (!fields.pickupLocation) result.push('pickupLocation');
  if (!fields.returnLocation) result.push('returnLocation');
  return result;
}

function collectWarnings(parsed, fields) {
  const warnings = [];
  if (!fields.carNumber) warnings.push('carNumber_missing');
  if (!fields.customerPhone) warnings.push('customerPhone_missing');
  if (!fields.price) warnings.push('price_missing');
  if (fields.pickupAt && fields.returnAt) {
    const pickup = parseStandardDateTime(fields.pickupAt);
    const dropoff = parseStandardDateTime(fields.returnAt);
    if (!pickup || !dropoff || dropoff <= pickup) warnings.push('invalid_datetime_window');
  }
  if (parsed?.intent !== 'reservation_create') warnings.push(`intent_${parsed?.intent || 'unknown'}`);
  return warnings;
}

function emptyParseResult(intent = 'ignore') {
  return {
    intent,
    fields: { ...EMPTY_KR_FIELDS },
    meta: {
      date: {
        yearInSource: null,
        yearBasis: null,
        pickupRaw: null,
        returnRaw: null
      }
    },
    message: null
  };
}

function isPlainObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value);
}

function normalizeIntent(value) {
  const normalized = normalizeValue(value);
  if (normalized === 'unsupported') return 'unsupported';
  if (normalized === 'reservation_create') return 'reservation_create';
  return 'ignore';
}

function normalizeParseMeta(meta, fields = {}) {
  const dateMeta = isPlainObject(meta?.date) ? meta.date : {};
  return {
    date: {
      yearInSource: normalizeBoolean(dateMeta.yearInSource),
      yearBasis: normalizeDateYearBasis(dateMeta.yearBasis),
      pickupRaw: normalizeValue(dateMeta.pickupRaw) || normalizeValue(fields['대여일']),
      returnRaw: normalizeValue(dateMeta.returnRaw) || normalizeValue(fields['반납일'])
    }
  };
}

function normalizeFieldValue(key, value, intent = 'ignore') {
  const normalized = normalizeValue(value);
  if (!normalized) return key === '예약상태' ? (intent === 'reservation_create' ? '예약중' : null) : null;
  if (key === '예약상태') return normalizeReservationStatus(normalized) || (intent === 'reservation_create' ? '예약중' : null);
  if (key === '대여일' || key === '반납일') return normalizeStandardDateTime(normalized);
  return normalized;
}

function normalizeValue(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text ? text : null;
}

function normalizeBoolean(value) {
  if (value === true || value === false) return value;
  const normalized = normalizeValue(value)?.toLowerCase();
  if (normalized === 'true') return true;
  if (normalized === 'false') return false;
  return null;
}

function normalizeDateYearBasis(value) {
  const normalized = normalizeValue(value);
  const allowed = new Set(['explicit_year', 'current_year', 'next_year', 'unknown']);
  return allowed.has(normalized) ? normalized : null;
}

function normalizeVehicleNumber(value) {
  const text = normalizeValue(value);
  if (!text) return null;
  const compact = text.replace(/\s+/g, '');
  const match = compact.match(/(\d{2,3}[가-힣]\d{4})/);
  return match ? match[1] : null;
}

function normalizeReservationStatus(value) {
  const normalized = normalizeValue(value);
  if (!normalized) return null;
  const allowed = new Set(['예약중', '배차중', '반납완료', '예약취소']);
  return allowed.has(normalized) ? normalized : null;
}

function applyParsedFieldFallbacks(parsed, sourceText = '') {
  if (!parsed || !parsed.fields || parsed.intent !== 'reservation_create') return;
  if (!digitsOnly(parsed.fields['고객번호'])) {
    const fallbackPhone = digitsOnly(extractCustomerPhoneFromSourceText(sourceText));
    parsed.fields['고객번호'] = fallbackPhone || null;
  }
}

function extractCustomerPhoneFromSourceText(sourceText) {
  const text = String(sourceText || '');
  return extractLabeledValue(text, '연락처')
    || extractLabeledValue(text, '예약자 연락처')
    || extractLabeledValue(text, '운전자 연락처')
    || extractLabeledValue(text, '고객번호')
    || '';
}

function extractLabeledValue(text, label) {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = String(text || '').match(new RegExp(`${escaped}\\s*:\\s*([^\\n\\r]+)`));
  return normalizeValue(match?.[1]) || '';
}

function digitsOnly(value) {
  return String(value || '').replace(/\D+/g, '');
}

function normalizeStandardDateTime(value) {
  const text = normalizeValue(value);
  if (!text) return null;
  return /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(text) ? text : null;
}

function normalizeBirthDate(value) {
  const text = normalizeValue(value);
  if (!text) return null;
  const compact = text.replace(/[./]/g, '-').replace(/\s+/g, '');
  const ymd = compact.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (ymd) {
    return isValidYmd(ymd[1], ymd[2], ymd[3]) ? `${ymd[1]}-${ymd[2]}-${ymd[3]}` : text;
  }

  const digits = text.replace(/\D+/g, '');
  if (digits.length === 8) {
    const year = digits.slice(0, 4);
    const month = digits.slice(4, 6);
    const day = digits.slice(6, 8);
    return isValidYmd(year, month, day) ? `${year}-${month}-${day}` : text;
  }

  if (digits.length === 6) {
    const currentYearTwoDigits = Number(String(getSeoulNowDate()?.getFullYear() || '').slice(-2) || '0');
    const yy = Number(digits.slice(0, 2));
    const year = yy <= currentYearTwoDigits ? `20${digits.slice(0, 2)}` : `19${digits.slice(0, 2)}`;
    const month = digits.slice(2, 4);
    const day = digits.slice(4, 6);
    return isValidYmd(year, month, day) ? `${year}-${month}-${day}` : text;
  }

  return text;
}

function isValidYmd(year, month, day) {
  const y = Number(year);
  const m = Number(month);
  const d = Number(day);
  if (!Number.isInteger(y) || !Number.isInteger(m) || !Number.isInteger(d)) return false;
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  const candidate = new Date(y, m - 1, d);
  return candidate.getFullYear() === y && candidate.getMonth() === m - 1 && candidate.getDate() === d;
}

function normalizeMoney(value) {
  const text = normalizeValue(value);
  if (!text) return null;
  const digits = text.replace(/[^\d]/g, '');
  return digits || text;
}

function mergeParsedRepairResult(first, repaired) {
  if (!first?.fields) return repaired;
  if (!repaired?.fields) return first;

  const merged = {
    ...first,
    intent: first.intent || repaired.intent,
    fields: { ...first.fields },
    meta: repaired.meta || first.meta,
    message: first.message || repaired.message || null
  };

  for (const fieldName of Object.keys(merged.fields)) {
    if (fieldName === '대여일' || fieldName === '반납일') {
      merged.fields[fieldName] = repaired.fields[fieldName] || first.fields[fieldName] || null;
      continue;
    }
    merged.fields[fieldName] = first.fields[fieldName] || repaired.fields[fieldName] || null;
  }

  return merged;
}

function validateParsedDateMeta(parsed) {
  if (parsed?.intent !== 'reservation_create') return { ok: true, reason: null };

  const pickup = normalizeStandardDateTime(parsed?.fields?.['대여일']);
  const dropoff = normalizeStandardDateTime(parsed?.fields?.['반납일']);
  if (!pickup || !dropoff) return { ok: true, reason: null };

  const pickupDate = parseStandardDateTime(pickup);
  const dropoffDate = parseStandardDateTime(dropoff);
  if (!pickupDate || !dropoffDate) return { ok: false, reason: 'invalid_datetime_format' };
  if (dropoffDate <= pickupDate) return { ok: false, reason: 'return_not_after_pickup' };

  const yearInSource = parsed?.meta?.date?.yearInSource;
  const yearBasis = parsed?.meta?.date?.yearBasis;
  const seoulNow = getSeoulNowDate();
  if (!seoulNow) return { ok: true, reason: null };

  const currentYear = seoulNow.getFullYear();
  const pickupYear = pickupDate.getFullYear();

  if (yearInSource === false && pickupYear < currentYear) {
    return { ok: false, reason: 'implicit_year_in_past' };
  }
  if (yearInSource === false && yearBasis === 'current_year' && pickupYear !== currentYear) {
    return { ok: false, reason: 'year_basis_current_mismatch' };
  }
  if (yearInSource === false && yearBasis === 'next_year' && pickupYear !== currentYear + 1) {
    return { ok: false, reason: 'year_basis_next_mismatch' };
  }
  if (yearInSource === true && yearBasis && yearBasis !== 'explicit_year') {
    return { ok: false, reason: 'explicit_year_basis_mismatch' };
  }

  return { ok: true, reason: null };
}

function buildDateRepairPrompt(parsed, validation) {
  return [
    'Repair the JSON date fields and meta.date only.',
    `Previous validation failed: ${validation?.reason || 'unknown'}`,
    'Keep the same schema.',
    'Do not explain.',
    'Return JSON only.',
    'Ensure 반납일 is after 대여일.',
    'If year is not explicit in source, choose current year or next year based on current Seoul time.',
    `Previous parsed JSON: ${JSON.stringify(parsed)}`
  ].join('\n');
}

function parseStandardDateTime(value) {
  const text = normalizeStandardDateTime(value);
  if (!text) return null;
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/);
  if (!match) return null;
  const [, y, m, d, hh, mm, ss] = match;
  return new Date(Number(y), Number(m) - 1, Number(d), Number(hh), Number(mm), Number(ss));
}

function getSeoulNowDate() {
  return parseStandardDateTime(getSeoulNowDateTimeString());
}

function getSeoulNowDateTimeString() {
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(new Date());
}

function normalizeImageDataUrl({ imageBase64, mimeType }) {
  const image = normalizeValue(imageBase64);
  if (!image) return null;
  if (image.startsWith('data:')) return image;
  const safeMimeType = normalizeValue(mimeType) || 'image/jpeg';
  return `data:${safeMimeType};base64,${image}`;
}

export const __test = {
  buildSystemPrompt,
  buildConfig,
  normalizeParseResult,
  validateParsedDateMeta,
  buildDateRepairPrompt,
  mapToAppFields,
  collectMissingFields,
  collectWarnings,
  normalizeVehicleNumber,
  normalizeStandardDateTime,
  normalizeBirthDate,
  normalizeMoney
};
