import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mapHomepageReservationPayload, normalizeBirthDate } from '../src/homepage-reservation-mapper.js';

test('normalizeBirthDate converts compact YYYYMMDD to YYYY-MM-DD', () => {
  assert.equal(normalizeBirthDate('19840528'), '1984-05-28');
});

test('normalizeBirthDate preserves valid YYYY-MM-DD', () => {
  assert.equal(normalizeBirthDate('1984-05-28'), '1984-05-28');
});

test('normalizeBirthDate normalizes dotted, slashed, and spaced dates', () => {
  assert.equal(normalizeBirthDate('1984.05.28'), '1984-05-28');
  assert.equal(normalizeBirthDate('1984/05/28'), '1984-05-28');
  assert.equal(normalizeBirthDate('1984 05 28'), '1984-05-28');
});

test('normalizeBirthDate rejects invalid calendar dates without throwing', () => {
  assert.equal(normalizeBirthDate('2026-02-31'), '');
});

test('mapHomepageReservationPayload normalizes customer birth date and preserves source context in metaJson', () => {
  const body = {
    eventId: 'evt-1',
    reservationInput: {
      bookingOrderId: 'BO-1',
      customerName: '홍길동',
      customerBirth: '19840528',
      customerPhone: '010-1234-5678',
    },
    booking: {
      bookingOrderId: 'BO-1',
    },
  };

  const mapped = mapHomepageReservationPayload(body);

  assert.equal(mapped.customerBirthDate, '1984-05-28');
  assert.equal(mapped.customerPhone, '01012345678');
  assert.equal(Object.hasOwn(mapped.metaJson, 'raw_payload'), false);
  assert.deepEqual(mapped.metaJson.reservation_input, body.reservationInput);
});
