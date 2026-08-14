import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  OPS_RESERVATION_EVENT_SIGNAL_CODES,
  listOpsReservationEventSignalCodes,
  opsReservationEventSignalCatalog,
} from '../catalog.js';

const FORBIDDEN_SAFE_FIELDS = new Set([
  'payload',
  'payloadJson',
  'rawPayload',
  'booking',
  'reservationInput',
  'customerName',
  'customerPhone',
  'secret',
  'token',
  'env',
]);

test('OPS reservation event signal catalog has unique codes', () => {
  const codes = listOpsReservationEventSignalCodes();
  assert.equal(codes.length, new Set(codes).size);
});

test('OPS reservation event signal catalog covers required signal codes', () => {
  const codes = new Set(listOpsReservationEventSignalCodes());
  for (const code of Object.values(OPS_RESERVATION_EVENT_SIGNAL_CODES)) {
    assert.equal(codes.has(code), true, code);
  }
});

test('OPS reservation event signal catalog is metadata-only and privacy-safe', () => {
  for (const signal of opsReservationEventSignalCatalog) {
    assert.match(signal.code, /^ops_/);
    assert.ok(signal.stage);
    assert.ok(signal.severity);
    assert.ok(signal.means);
    assert.ok(signal.doesNotMean);
    assert.match(signal.sourcePath, /^reservation_ai_parser\/src\//);
    assert.equal(signal.helperPath, 'reservation_ai_parser/operational-signals/reservation-event-signals.js');
    assert.ok(Array.isArray(signal.safeFields));
    for (const field of signal.safeFields) {
      assert.equal(FORBIDDEN_SAFE_FIELDS.has(field), false, `${signal.code} exposes forbidden field ${field}`);
    }
  }

  const serialized = JSON.stringify(opsReservationEventSignalCatalog);
  assert.equal(serialized.includes('010'), false);
  assert.equal(serialized.includes('홍길동'), false);
  assert.equal(serialized.includes('SUPABASE_SERVICE_ROLE_KEY'), false);
  assert.equal(serialized.includes('service_role'), false);
});
