import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildConfig, parseFineNoticeInput } from './parser-core.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const fixturePath = path.resolve(__dirname, 'fixtures/gangnam_toll_multi.json');
const fixture = JSON.parse(await fs.readFile(fixturePath, 'utf8'));
const result = await parseFineNoticeInput({ fixture }, buildConfig({}));

assertEqual(result.noticeProfile, 'toll_fee.gangnam_sunhwan', 'noticeProfile');
assertEqual(result.noticeType, 'toll_fee', 'noticeType');
assertEqual(result.issuer, '강남순환도로(주)', 'issuer');
assertEqual(result.documentNumber, '6418191', 'documentNumber');
assertEqual(result.rawCandidate.carNumber, '142호2673', 'carNumber');
assertEqual(result.rawCandidate.totalAmount, 7600, 'totalAmount');
assertEqual(result.rawCandidate.items.length, 4, 'items.length');
assertEqual(result.warnings.includes('dueDate_missing'), false, 'dueDate_missing warning');

const expectedItems = [
  ['2026-05-06 09:45:25', '금천', 1900],
  ['2026-05-06 15:49:59', '금천', 1900],
  ['2026-05-06 15:59:50', '선암', 1900],
  ['2026-05-12 13:09:43', '선암', 1900]
];

for (const [index, [occurredAt, location, amount]] of expectedItems.entries()) {
  const item = result.rawCandidate.items[index];
  assertEqual(item.itemIndex, index + 1, `items[${index}].itemIndex`);
  assertEqual(item.occurredAt, occurredAt, `items[${index}].occurredAt`);
  assertEqual(item.location, location, `items[${index}].location`);
  assertEqual(item.amount, amount, `items[${index}].amount`);
  assertEqual(item.contractMatchRequired, true, `items[${index}].contractMatchRequired`);
}

console.log(JSON.stringify({
  ok: true,
  fixture: path.basename(fixturePath),
  imageFixture: 'images/gangnam_sunhwan_4rows_20260506_20260512.jpg',
  splitLedgerCandidates: result.rawCandidate.items.length
}, null, 2));

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    console.error(JSON.stringify({ ok: false, label, expected, actual }, null, 2));
    process.exit(1);
  }
}
