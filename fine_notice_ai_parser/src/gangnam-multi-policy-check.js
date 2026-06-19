import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, parseFineNoticeInput } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const fixturePath = path.resolve(__dirname, 'fixtures/gangnam_toll_multi.json');
const fixture = JSON.parse(await fs.readFile(fixturePath, 'utf8'));
const fullResult = await parseFineNoticeInput({ fixture }, buildConfig({}));
const missingDateResult = await parseFineNoticeInput({
  fixture: {
    ...fixture,
    noticeProfile: 'toll_notice',
    noticeType: 'unknown_notice',
    rawCandidate: {
      ...fixture.rawCandidate,
      items: fixture.rawCandidate.items.map((item) => ({
        ...item,
        occurredAt: null,
      })),
    },
  },
}, buildConfig({}));

const fullDecision = decideGangnamMultiRowFlow(fullResult);
const missingDateDecision = decideGangnamMultiRowFlow(missingDateResult);

assertEqual(fullDecision.nextAction, 'auto_split_ready', 'fullDecision.nextAction');
assertEqual(missingDateDecision.nextAction, 'second_pass_required', 'missingDateDecision.nextAction');
assertIncludes(missingDateDecision.reasons, 'row_date_missing', 'missingDateDecision.reasons');

console.log(JSON.stringify({
  ok: true,
  decisions: {
    completeFixture: fullDecision,
    firstPassMissingDates: missingDateDecision,
  },
}, null, 2));

function decideGangnamMultiRowFlow(result) {
  const raw = result.rawCandidate || {};
  const items = Array.isArray(raw.items) ? raw.items : [];
  const reasons = [];
  const isGangnam =
    result.noticeProfile === 'toll_fee.gangnam_sunhwan' ||
    String(result.issuer || '').includes('강남순환');
  const typeOk = result.noticeType === 'toll_fee';

  if (!isGangnam) reasons.push('profile_unconfirmed');
  if (!typeOk) reasons.push('notice_type_unconfirmed');
  if (raw.carNumber !== '142호2673') reasons.push('car_number_mismatch');
  if (raw.totalAmount !== 7600) reasons.push('total_amount_mismatch');
  if (items.length !== 4) reasons.push('row_count_mismatch');

  for (const [index, item] of items.entries()) {
    if (!item.occurredAt) reasons.push('row_date_missing');
    if (!item.location) reasons.push(`row_${index + 1}_location_missing`);
    if (item.amount !== 1900) reasons.push(`row_${index + 1}_amount_mismatch`);
  }

  if (reasons.length === 0) {
    return { nextAction: 'auto_split_ready', reasons };
  }
  if (
    isGangnam &&
    raw.carNumber === '142호2673' &&
    raw.totalAmount === 7600 &&
    items.length === 4 &&
    reasons.includes('row_date_missing')
  ) {
    return { nextAction: 'second_pass_required', reasons: unique(reasons) };
  }
  return { nextAction: 'manual_row_review_required', reasons: unique(reasons) };
}

function unique(values) {
  return [...new Set(values)];
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    console.error(JSON.stringify({ ok: false, label, expected, actual }, null, 2));
    process.exit(1);
  }
}

function assertIncludes(values, expected, label) {
  if (!values.includes(expected)) {
    console.error(JSON.stringify({ ok: false, label, expected, actual: values }, null, 2));
    process.exit(1);
  }
}
