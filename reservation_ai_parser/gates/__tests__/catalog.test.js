import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  RESERVATION_EVENT_GATE_IDS,
  listReservationEventGateIds,
  reservationEventGateCatalog,
} from '../catalog.js';

test('reservation event gate catalog has unique ids', () => {
  const ids = listReservationEventGateIds();
  assert.equal(ids.length, new Set(ids).size);
});

test('reservation event gate catalog covers required gate ids', () => {
  const ids = new Set(listReservationEventGateIds());
  for (const id of Object.values(RESERVATION_EVENT_GATE_IDS)) {
    assert.equal(ids.has(id), true, id);
  }
});

test('reservation event gate catalog stays metadata-only and privacy-safe', () => {
  for (const gate of reservationEventGateCatalog) {
    assert.equal(gate.owner, 'ops');
    assert.equal(gate.runtimeBehavior, 'preserve');
    assert.equal(Array.isArray(gate.protectedTargets), true);
    assert.equal(gate.protectedTargets.length, 0);
    assert.match(gate.sourcePath, /^reservation_ai_parser\/src\//);
    assert.equal(gate.helperPath, 'reservation_ai_parser/gates/reservation-event-gates.js');
    assert.equal(JSON.stringify(gate).includes('010'), false);
  }
});
