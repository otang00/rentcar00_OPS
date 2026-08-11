import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  mergeImsInsuranceClaimListAndDetail,
  readImsInsuranceClaimExpectedReturnAt,
  toImsInsuranceClaimImportItem,
} from '../src/ims-insurance-claim-import-item.js';

test('insurance claim import reads top-level expected return date', () => {
  const item = toImsInsuranceClaimImportItem({
    id: '3011022',
    claim_state: 'using_car',
    rent_car_number: '125하1717',
    customer_contact: '010-1234-5678',
    delivered_at: '2026-07-31 13:04:00',
    expected_return_date: '2026-08-02 10:30:00',
  });

  assert.equal(item.returnAt, '2026-08-02 10:30');
  assert.equal(item.customerPhone, '01012345678');
});

test('insurance claim import falls back to matching nested contract return date', () => {
  const returnAt = readImsInsuranceClaimExpectedReturnAt({
    id: '3011023',
    rent_car_number: '125하1717',
    contracts: [
      { rent_car_number: '999허9999', return_date: '2026-08-05 09:00:00' },
      { rent_car_number: '125하1717', return_date: '2026-08-03 11:00:00' },
    ],
  });

  assert.equal(returnAt, '2026-08-03 11:00');
});

test('insurance claim import supports return due aliases before blank result', () => {
  const returnAt = readImsInsuranceClaimExpectedReturnAt({
    rent_car_number: '125하1717',
    details: {
      rent_car_number: '125하1717',
      return_due_at: '2026-08-04T12:10:00+09:00',
    },
  });

  assert.equal(returnAt, '2026-08-04 12:10');
});

test('insurance claim import preserves list fields while using detail expected return date', () => {
  const listClaim = {
    id: '3136931',
    claim_state: 'using_car',
    rent_car_number: '20하3779',
    delivered_at: '2026-07-31 15:42:00',
    return_date: '',
  };
  const detailClaim = {
    claim_state: 'using_car',
    expect_return_date: '2026-08-07 15:42',
    details: [{ delivered_date: '2026-07-31 15:42:00', return_date: '' }],
  };

  const item = toImsInsuranceClaimImportItem(
    mergeImsInsuranceClaimListAndDetail(listClaim, detailClaim),
  );

  assert.equal(item.carNumber, '20하3779');
  assert.equal(item.rentalAt, '2026-07-31 15:42');
  assert.equal(item.returnAt, '2026-08-07 15:42');
});
