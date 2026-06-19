import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const endpoint = process.env.FINE_NOTICE_PUBLIC_PARSE_URL || 'https://parser.00rentcar.com/parse-fine-notice';
const runCount = Number(process.env.GANGNAM_MULTI_SMOKE_RUNS || 5);
const imagePath = process.env.GANGNAM_MULTI_FIXTURE_IMAGE
  ? path.resolve(process.env.GANGNAM_MULTI_FIXTURE_IMAGE)
  : '';
if (!imagePath) {
  console.error('GANGNAM_MULTI_FIXTURE_IMAGE is required for real-image smoke.');
  process.exit(2);
}
const imageBase64 = await fs.readFile(imagePath, 'base64');
const expectedDates = [
  '2026-05-06 09:45:25',
  '2026-05-06 15:49:59',
  '2026-05-06 15:59:50',
  '2026-05-12 13:09:43',
];
const expectedLocations = ['금천', '금천', '선암', '선암'];

const results = [];
for (let index = 0; index < runCount; index += 1) {
  const startedAt = new Date().toISOString();
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ imageBase64, mimeType: 'image/jpeg' }),
  });
  const text = await response.text();
  if (!response.ok) {
    results.push({
      run: index + 1,
      ok: false,
      startedAt,
      httpStatus: response.status,
      error: text.slice(0, 500),
    });
    continue;
  }
  const json = JSON.parse(text);
  results.push(validateRun(index + 1, startedAt, json));
}

const passed = results.filter((item) => item.ok).length;
const summary = {
  ok: passed === runCount,
  endpoint,
  runCount,
  passed,
  failed: runCount - passed,
  results,
};

console.log(JSON.stringify(summary, null, 2));
if (!summary.ok) process.exit(1);

function validateRun(run, startedAt, json) {
  const raw = json.rawCandidate || {};
  const items = Array.isArray(raw.items) ? raw.items : [];
  const reasons = [];
  if (json.noticeProfile !== 'toll_fee.gangnam_sunhwan') {
    reasons.push(`noticeProfile:${json.noticeProfile}`);
  }
  if (json.noticeType !== 'toll_fee') reasons.push(`noticeType:${json.noticeType}`);
  if (raw.carNumber !== '142호2673') reasons.push(`carNumber:${raw.carNumber}`);
  if (raw.totalAmount !== 7600) reasons.push(`totalAmount:${raw.totalAmount}`);
  if (items.length !== 4) reasons.push(`items.length:${items.length}`);
  for (const [index, expectedDate] of expectedDates.entries()) {
    const item = items[index] || {};
    if (item.occurredAt !== expectedDate) {
      reasons.push(`items[${index}].occurredAt:${item.occurredAt}`);
    }
    if (item.location !== expectedLocations[index]) {
      reasons.push(`items[${index}].location:${item.location}`);
    }
    if (item.amount !== 1900) {
      reasons.push(`items[${index}].amount:${item.amount}`);
    }
  }
  if ((json.warnings || []).includes('invalid_model_json')) reasons.push('invalid_model_json');
  if ((json.warnings || []).includes('rowDate_missing')) reasons.push('rowDate_missing');
  if ((json.warnings || []).includes('occurredAt_missing')) reasons.push('occurredAt_missing');
  return {
    run,
    ok: reasons.length === 0,
    startedAt,
    reasons,
    noticeProfile: json.noticeProfile,
    noticeType: json.noticeType,
    issuer: json.issuer,
    carNumber: raw.carNumber,
    totalAmount: raw.totalAmount,
    itemCount: items.length,
    occurredAts: items.map((item) => item.occurredAt),
    locations: items.map((item) => item.location),
    amounts: items.map((item) => item.amount),
    warnings: json.warnings || [],
    secondPass: json.meta?.secondPass || null,
  };
}
