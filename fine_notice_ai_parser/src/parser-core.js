import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

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
    // Missing env files are allowed for fixture-only checks.
  }
}

export function buildConfig(env = process.env) {
  return {
    openAiApiKey: String(env.OPENAI_API_KEY || '').trim(),
    openAiModel: String(env.FINE_NOTICE_AI_MODEL || env.OPENAI_MODEL || 'gpt-4.1-mini').trim(),
    host: String(env.FINE_NOTICE_AI_PARSER_HOST || env.AI_PARSER_HOST || '127.0.0.1').trim(),
    port: Number(env.FINE_NOTICE_AI_PARSER_PORT || 43120),
    timeoutMs: Number(env.FINE_NOTICE_AI_PARSER_TIMEOUT_MS || env.AI_PARSER_TIMEOUT_MS || 45000),
    storageRoot: String(
      env.FINE_NOTICE_STORAGE_ROOT ||
      path.resolve(env.INIT_CWD || process.cwd(), 'storage/fine-notices')
    ).trim()
  };
}

export function validateConfig(config) {
  if (!config.openAiApiKey) throw new Error('missing OPENAI_API_KEY');
}

export async function parseFineNoticeInput(input = {}, config = buildConfig()) {
  const fixture = normalizeFixtureInput(input);
  if (fixture) return buildAppResponse(fixture, { source: 'fixture' });

  const imageInput = normalizeImageInput(input);
  if (!imageInput) {
    throw new Error('imageBase64 or fixture is required');
  }

  validateConfig(config);
  const file = await saveOriginalImage({ imageInput, config });
  const parsed = await requestImageParseResult({ imageDataUrl: imageInput.dataUrl, config });
  const firstPass = buildAppResponse(parsed, { source: 'openai', usedImage: true, file });
  if (!shouldRunGangnamSunhwanSecondPass(firstPass)) return firstPass;

  const secondParsed = await requestImageParseResult({
    imageDataUrl: imageInput.dataUrl,
    config,
    pass: 'gangnam_sunhwan_table'
  });
  const secondPass = buildAppResponse(secondParsed, {
    source: 'openai',
    usedImage: true,
    file
  });
  return mergeSecondPassResult(firstPass, secondPass);
}

export async function saveOriginalImage({ imageInput, config = buildConfig(), now = new Date() }) {
  if (!imageInput?.buffer?.length) throw new Error('imageBase64 or fixture is required');
  const requestId = crypto.randomUUID();
  const sha256 = crypto.createHash('sha256').update(imageInput.buffer).digest('hex');
  const dateSegment = formatDateSegment(now);
  const incomingDir = path.join(config.storageRoot, 'incoming', dateSegment);
  const filename = `${requestId}.${imageInput.extension}`;
  const localPath = path.join(incomingDir, filename);

  await fs.mkdir(incomingDir, { recursive: true });
  await fs.writeFile(localPath, imageInput.buffer);

  return {
    fileRole: 'notice_original',
    requestId,
    localPath,
    sha256,
    mimeType: imageInput.mimeType,
    sizeBytes: imageInput.buffer.length,
    backupStatus: 'pending'
  };
}

function normalizeFixtureInput(input) {
  if (isPlainObject(input.fixture)) return input.fixture;
  if (isPlainObject(input.rawCandidate)) {
    return {
      ok: true,
      noticeProfile: input.noticeProfile || 'unknown_notice',
      noticeType: input.noticeType || 'unknown_notice',
      issuer: input.issuer || null,
      documentNumber: input.documentNumber || null,
      rawCandidate: input.rawCandidate,
      fieldCrops: Array.isArray(input.fieldCrops) ? input.fieldCrops : [],
      warnings: Array.isArray(input.warnings) ? input.warnings : [],
      confidence: typeof input.confidence === 'number' ? input.confidence : null
    };
  }
  const text = normalizeValue(input.text);
  if (!text) return null;
  try {
    const parsed = JSON.parse(text);
    if (isPlainObject(parsed)) return parsed;
  } catch {
    // Plain text parsing is intentionally not supported in the fine notice parser.
  }
  return null;
}

async function requestImageParseResult({ imageDataUrl, config, pass = 'full_notice' }) {
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
          { role: 'system', content: buildSystemPrompt({ pass }) },
          {
            role: 'user',
            content: [
              { type: 'text', text: buildUserPrompt({ pass }) },
              { type: 'image_url', image_url: { url: imageDataUrl, detail: 'high' } }
            ]
          }
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
    return normalizeModelResult(content);
  } finally {
    clearTimeout(timeout);
  }
}

function buildSystemPrompt({ pass = 'full_notice' } = {}) {
  const lines = [
    'You are a raw OCR assistant for Korean vehicle fine, parking, traffic, and toll notices.',
    'Return JSON only. No markdown.',
    'You are not allowed to correct, infer, or finalize business decisions.',
    'Read visible text as raw candidates. If unclear, return null and add warnings.',
    'The user will manually review and edit all values later.',
    'Do not force a year from current date. Preserve what is visible.',
    'For multi-row toll notices, split visible rows into items[].',
    'For Gangnam Sunhwan toll notices, use noticeProfile "toll_fee.gangnam_sunhwan" and noticeType "toll_fee".',
    'For toll notices, each table row must keep its own occurredAt, amount, surchargeAmount, and location.',
    'For row tables, preserve top-to-bottom row order. Do not merge multiple rows into one.',
    'Output schema:'
  ];
  if (pass === 'gangnam_sunhwan_table') {
    lines.push(
      'SECOND PASS MODE: Focus on the Gangnam Sunhwan toll usage table only.',
      'Read the table columns exactly as: 번호 / 통행일시 / 통행료 / 부가통행료 / 통행장소.',
      'The 통행일시 column is required per row. If a row date/time is unreadable, set that row occurredAt to null and add warning "rowDate_missing".',
      'Do not read 납부기한 as occurredAt. Do not use the 운행일시기간 summary as row occurredAt.',
      'Do not invent missing seconds, dates, years, or rows.'
    );
  }
  lines.push(JSON.stringify(emptyFineNoticeResult()));
  return lines.join('\n');
}

function buildUserPrompt({ pass = 'full_notice' } = {}) {
  if (pass === 'gangnam_sunhwan_table') {
    return [
      'Second pass: read only the Gangnam Sunhwan toll table.',
      'Return exactly the visible usage rows in rawCandidate.items[].',
      'For this profile, prioritize row occurredAt from the 통행일시 column, then amount, surchargeAmount, and location.',
      'Do not infer invisible values.'
    ].join(' ');
  }
  return 'Read this Korean fine/toll/parking notice as raw candidates only.';
}

function normalizeModelResult(content) {
  try {
    return JSON.parse(content);
  } catch {
    return {
      ...emptyFineNoticeResult(),
      warnings: ['invalid_model_json'],
      meta: { rawModelContent: content }
    };
  }
}

function buildAppResponse(parsed, options = {}) {
  const rawCandidate = normalizeRawCandidate(parsed.rawCandidate || parsed);
  const noticeProfile = normalizeNoticeProfile(parsed);
  const noticeType = normalizeNoticeType(parsed.noticeType || parsed.notice_type);
  const warnings = [
    ...normalizeStringList(parsed.warnings),
    ...collectRawWarnings(rawCandidate)
  ];

  return {
    ok: true,
    noticeProfile,
    noticeType,
    issuer: normalizeValue(parsed.issuer),
    documentNumber: normalizeValue(parsed.documentNumber || parsed.notice_number),
    rawCandidate,
    confirmedValue: null,
    fieldCrops: normalizeFieldCrops(parsed.fieldCrops),
    warnings: [...new Set(warnings)],
    confidence: normalizeConfidence(parsed.confidence),
    meta: {
      source: options.source || 'unknown',
      model: options.source === 'openai' ? undefined : null,
      usedImage: Boolean(options.usedImage),
      parser: 'fine-notice-ai-parser'
    },
    file: options.file || null
  };
}

function shouldRunGangnamSunhwanSecondPass(result) {
  if (!isGangnamSunhwanResult(result)) return false;
  const raw = result.rawCandidate || {};
  const items = Array.isArray(raw.items) ? raw.items : [];
  if (items.length < 2) return false;
  const hasMissingRowDate = items.some((item) => !normalizeValue(item.occurredAt));
  const hasProfileOrTypeDrift =
    result.noticeProfile !== 'toll_fee.gangnam_sunhwan' ||
    result.noticeType !== 'toll_fee';
  return hasMissingRowDate || hasProfileOrTypeDrift;
}

function mergeSecondPassResult(firstPass, secondPass) {
  const firstItems = firstPass.rawCandidate.items || [];
  const secondItems = secondPass.rawCandidate.items || [];
  const mergedItems = firstItems.map((item, index) => {
    const supplement = secondItems[index] || {};
    return {
      ...item,
      occurredAt: item.occurredAt || supplement.occurredAt || null,
      location: item.location || supplement.location || null,
      amount: item.amount ?? supplement.amount ?? null,
      surchargeAmount: item.surchargeAmount ?? supplement.surchargeAmount ?? null,
      reason: item.reason || supplement.reason || null,
      contractMatchRequired:
        item.contractMatchRequired !== false && supplement.contractMatchRequired !== false
    };
  });
  if (mergedItems.length === 0 && secondItems.length > 0) mergedItems.push(...secondItems);

  const rawCandidate = {
    ...firstPass.rawCandidate,
    carNumber: firstPass.rawCandidate.carNumber || secondPass.rawCandidate.carNumber,
    violationAt: firstPass.rawCandidate.violationAt || secondPass.rawCandidate.violationAt,
    passAt: firstPass.rawCandidate.passAt || secondPass.rawCandidate.passAt,
    periodStart: firstPass.rawCandidate.periodStart || secondPass.rawCandidate.periodStart,
    periodEnd: firstPass.rawCandidate.periodEnd || secondPass.rawCandidate.periodEnd,
    location: firstPass.rawCandidate.location || secondPass.rawCandidate.location,
    amount: firstPass.rawCandidate.amount ?? secondPass.rawCandidate.amount,
    totalAmount: firstPass.rawCandidate.totalAmount ?? secondPass.rawCandidate.totalAmount,
    baseAmount: firstPass.rawCandidate.baseAmount ?? secondPass.rawCandidate.baseAmount,
    discountAmount: firstPass.rawCandidate.discountAmount ?? secondPass.rawCandidate.discountAmount,
    surchargeAmount: firstPass.rawCandidate.surchargeAmount ?? secondPass.rawCandidate.surchargeAmount,
    paymentNumber: firstPass.rawCandidate.paymentNumber || secondPass.rawCandidate.paymentNumber,
    virtualAccount: firstPass.rawCandidate.virtualAccount || secondPass.rawCandidate.virtualAccount,
    items: mergedItems
  };
  const warnings = [
    ...firstPass.warnings,
    ...secondPass.warnings,
    ...collectRowWarnings(rawCandidate)
  ];
  return {
    ...firstPass,
    noticeProfile: isGangnamSunhwanResult(firstPass) || isGangnamSunhwanResult(secondPass)
      ? 'toll_fee.gangnam_sunhwan'
      : firstPass.noticeProfile,
    noticeType: firstPass.noticeType === 'toll_fee' || secondPass.noticeType === 'toll_fee'
      ? 'toll_fee'
      : firstPass.noticeType,
    issuer: firstPass.issuer || secondPass.issuer,
    documentNumber: firstPass.documentNumber || secondPass.documentNumber,
    rawCandidate,
    fieldCrops: [...firstPass.fieldCrops, ...secondPass.fieldCrops],
    warnings: [...new Set(warnings)],
    confidence: firstPass.confidence ?? secondPass.confidence,
    meta: {
      ...firstPass.meta,
      secondPass: 'gangnam_sunhwan_table'
    }
  };
}

function normalizeRawCandidate(value) {
  const source = isPlainObject(value) ? value : {};
  const items = Array.isArray(source.items) ? source.items : [];
  return {
    carNumber: normalizeValue(source.carNumber || source.vehicle_number),
    violationAt: normalizeValue(source.violationAt || source.occurred_at),
    passAt: normalizeValue(source.passAt),
    periodStart: normalizeValue(source.periodStart || source.period_start),
    periodEnd: normalizeValue(source.periodEnd || source.period_end),
    location: normalizeValue(source.location),
    amount: normalizeNumber(source.amount || source.total_amount),
    totalAmount: normalizeNumber(source.totalAmount || source.total_amount || source.amount),
    baseAmount: normalizeNumber(source.baseAmount || source.base_amount),
    discountAmount: normalizeNumber(source.discountAmount || source.discount_amount),
    surchargeAmount: normalizeNumber(source.surchargeAmount || source.surcharge_amount),
    dueDate: normalizeValue(source.dueDate || source.due_date),
    paymentNumber: normalizeValue(source.paymentNumber || source.electronic_payment_number || source.giro_number),
    virtualAccount: normalizeValue(source.virtualAccount || source.virtual_account),
    items: items.map(normalizeItem)
  };
}

function normalizeItem(item, index) {
  const source = isPlainObject(item) ? item : {};
  return {
    itemIndex: normalizeNumber(source.itemIndex || source.item_no) || index + 1,
    occurredAt: normalizeValue(source.occurredAt || source.occurred_at),
    location: normalizeValue(source.location),
    amount: normalizeNumber(source.amount),
    surchargeAmount: normalizeNumber(source.surchargeAmount || source.surcharge_amount),
    reason: normalizeValue(source.reason || source.violation_detail),
    contractMatchRequired: source.contractMatchRequired !== false
  };
}

function normalizeFieldCrops(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter(isPlainObject)
    .map((item) => ({
      field: normalizeValue(item.field),
      profile: normalizeValue(item.profile),
      hint: normalizeValue(item.hint),
      confidence: normalizeConfidence(item.confidence)
    }));
}

function collectRawWarnings(rawCandidate) {
  const warnings = [];
  if (!rawCandidate.carNumber) warnings.push('carNumber_missing');
  if (!rawCandidate.totalAmount) warnings.push('totalAmount_missing');
  if (!rawCandidate.violationAt && !rawCandidate.passAt && rawCandidate.items.length === 0) {
    warnings.push('occurredAt_missing');
  }
  warnings.push(...collectRowWarnings(rawCandidate));
  return warnings;
}

function collectRowWarnings(rawCandidate) {
  const warnings = [];
  const items = Array.isArray(rawCandidate.items) ? rawCandidate.items : [];
  if (items.length < 2) return warnings;
  if (items.some((item) => !item.occurredAt)) warnings.push('rowDate_missing');
  return warnings;
}

function normalizeNoticeProfile(parsed) {
  const explicit = normalizeValue(parsed.noticeProfile || parsed.profile);
  if (explicit === 'toll_fee.gangnam_sunhwan') return explicit;
  if (explicit === 'toll_fee.woomyeonsan') return explicit;
  if (explicit === 'parking.namdong') return explicit;
  if (explicit === 'parking.seoul_cartax') return explicit;
  if (explicit === 'traffic.police_efine') return explicit;
  if (isGangnamSunhwanParsed(parsed)) return 'toll_fee.gangnam_sunhwan';
  return inferNoticeProfile(parsed);
}

function inferNoticeProfile(parsed) {
  const issuer = normalizeValue(parsed.issuer) || '';
  if (issuer.includes('우면산')) return 'toll_fee.woomyeonsan';
  if (issuer.includes('강남순환')) return 'toll_fee.gangnam_sunhwan';
  if (issuer.includes('남동구')) return 'parking.namdong';
  if (issuer.includes('용산') || issuer.includes('서울특별시')) return 'parking.seoul_cartax';
  if (issuer.includes('경찰')) return 'traffic.police_efine';
  return 'unknown_notice';
}

function normalizeNoticeType(value) {
  const text = normalizeValue(value);
  if (text === 'traffic_fine' || text === 'parking_violation' || text === 'toll_fee') return text;
  if (text === 'toll_notice' || text === 'toll' || text === 'toll_fee_notice') return 'toll_fee';
  return 'unknown_notice';
}

function isGangnamSunhwanResult(result) {
  return (
    result.noticeProfile === 'toll_fee.gangnam_sunhwan' ||
    String(result.issuer || '').includes('강남순환') ||
    String(result.rawCandidate?.virtualAccount || '').includes('317-0010-9021')
  );
}

function isGangnamSunhwanParsed(parsed) {
  const issuer = normalizeValue(parsed.issuer) || '';
  const profile = normalizeValue(parsed.noticeProfile || parsed.profile) || '';
  const raw = isPlainObject(parsed.rawCandidate) ? parsed.rawCandidate : parsed;
  return (
    issuer.includes('강남순환') ||
    profile === 'toll_fee.gangnam_sunhwan' ||
    profile.includes('gangnam') ||
    normalizeValue(raw?.virtualAccount)?.includes('317-0010-9021')
  );
}

function normalizeImageInput({ imageBase64, mimeType }) {
  const base64 = normalizeValue(imageBase64);
  if (!base64) return null;
  if (base64.startsWith('data:image/')) {
    const match = base64.match(/^data:([^;]+);base64,(.+)$/);
    if (!match) return null;
    const mime = normalizeMimeType(match[1]);
    const payload = match[2];
    return {
      dataUrl: base64,
      buffer: Buffer.from(payload, 'base64'),
      mimeType: mime,
      extension: extensionForMimeType(mime)
    };
  }
  const mime = normalizeMimeType(mimeType);
  return {
    dataUrl: `data:${mime};base64,${base64}`,
    buffer: Buffer.from(base64, 'base64'),
    mimeType: mime,
    extension: extensionForMimeType(mime)
  };
}

function normalizeValue(value) {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function normalizeNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const text = normalizeValue(value);
  if (!text) return null;
  const number = Number(text.replace(/[^0-9.-]/g, ''));
  return Number.isFinite(number) ? number : null;
}

function normalizeConfidence(value) {
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return Math.max(0, Math.min(1, value));
}

function normalizeStringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map(normalizeValue).filter(Boolean);
}

function isPlainObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value);
}

function normalizeMimeType(value) {
  const mime = normalizeValue(value) || 'image/jpeg';
  if (mime === 'image/png' || mime === 'image/webp' || mime === 'image/heic') return mime;
  return 'image/jpeg';
}

function extensionForMimeType(mimeType) {
  if (mimeType === 'image/png') return 'png';
  if (mimeType === 'image/webp') return 'webp';
  if (mimeType === 'image/heic') return 'heic';
  return 'jpg';
}

function formatDateSegment(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}${month}${day}`;
}

function emptyFineNoticeResult() {
  return {
    noticeProfile: 'unknown_notice',
    noticeType: 'unknown_notice',
    issuer: null,
    documentNumber: null,
    rawCandidate: {
      carNumber: null,
      violationAt: null,
      passAt: null,
      periodStart: null,
      periodEnd: null,
      location: null,
      amount: null,
      totalAmount: null,
      baseAmount: null,
      discountAmount: null,
      surchargeAmount: null,
      dueDate: null,
      paymentNumber: null,
      virtualAccount: null,
      items: []
    },
    fieldCrops: [],
    warnings: [],
    confidence: null
  };
}
