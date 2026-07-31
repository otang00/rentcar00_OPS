import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildSnapshotDiff,
  buildUsingCarSnapshotDiffReport,
  normalizeUsingCarSnapshotRows,
  verifyDiffCandidates,
} from '../src/ims-using-car-snapshot-diff.js';

const seenAt = new Date('2026-07-26T12:00:00.000Z');

function normalRow(id, carNumber = '101하9300', status = 'using_car') {
  return {
    id,
    status,
    start_at: '2026-07-26 09:00:00',
    end_at: '2026-07-28 09:00:00',
    car: { car_identity: carNumber },
    reservation: { id: `detail-${id}`, customer_name: '일반고객' },
  };
}

function insuranceRow(id, carNumber = '101하9300', state = 'using_car') {
  return {
    id,
    claim_state: state,
    delivered_at: '2026-07-26 09:00:00',
    expect_return_date: '2026-07-28 09:00:00',
    rent_car_number: carNumber,
    customer_name: '보험고객',
  };
}

function linkMap(rows = []) {
  return new Map(rows.map((row) => [`${row.source_type}:${row.external_reservation_id}`, row]));
}

function reservationMap(row = {}) {
  return new Map([[
    row.reservation_id || 'R-1',
    {
      id: row.id || 'reservation-row-1',
      reservation_id: row.reservation_id || 'R-1',
      car_number: row.car_number || '101하9300',
      ...row,
    },
  ]]);
}

function scheduleMap(reservationId, rows = []) {
  return new Map([[reservationId, rows]]);
}

test('normalizes normal and insurance using-car list rows without using car number as key', () => {
  const rows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-1')],
    insuranceRows: [insuranceRow('claim-1')],
    seenAt,
  });

  assert.equal(rows.length, 2);
  assert.equal(rows[0].key, 'normal_schedule:schedule-1');
  assert.equal(rows[1].key, 'insurance_claim:claim-1');
  assert.equal(rows[0].car_number, '101하9300');
  assert.equal(rows[1].car_number, '101하9300');
});

test('normalizes insurance using-car nested expected return date', () => {
  const rows = normalizeUsingCarSnapshotRows({
    insuranceRows: [{
      id: 'claim-nested',
      claim_state: 'using_car',
      delivered_at: '2026-07-26 09:00:00',
      rent_car_number: '101하9300',
      contracts: [{ rent_car_number: '101하9300', return_due_at: '2026-07-29T10:20:00+09:00' }],
    }],
    seenAt,
  });

  assert.equal(rows[0].return_at, '2026-07-29 10:20');
});

test('first valid snapshot bootstraps without lifecycle candidates', () => {
  const currentRows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-1')],
    seenAt,
  });
  const diff = buildSnapshotDiff({ previousRows: [], currentRows });

  assert.equal(diff.status, 'bootstrap');
  assert.equal(diff.bootstrap, true);
  assert.equal(diff.appeared.length, 0);
  assert.equal(diff.disappeared.length, 0);
  assert.equal(diff.bootstrapRows.length, 1);
});

test('snapshot diff classifies appeared, disappeared, and unchanged by source/external id', () => {
  const previousRows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-old'), normalRow('schedule-same')],
    insuranceRows: [insuranceRow('claim-old')],
    seenAt,
  });
  const currentRows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-new'), normalRow('schedule-same')],
    seenAt,
  });
  const diff = buildSnapshotDiff({ previousRows, currentRows, minCurrentRatio: 0.1 });

  assert.equal(diff.status, 'diff');
  assert.deepEqual(diff.appeared.map((item) => item.row.key), ['normal_schedule:schedule-new']);
  assert.deepEqual(
    diff.disappeared.map((item) => item.row.key).sort(),
    ['insurance_claim:claim-old', 'normal_schedule:schedule-old'],
  );
  assert.deepEqual(diff.unchanged.map((item) => item.row.key), ['normal_schedule:schedule-same']);
});

test('snapshot quality guard skips suspicious mass disappearance', () => {
  const previousRows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-1'), normalRow('schedule-2'), normalRow('schedule-3')],
    seenAt,
  });
  const currentRows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-1')],
    seenAt,
  });
  const diff = buildSnapshotDiff({ previousRows, currentRows, minCurrentRatio: 0.5 });

  assert.equal(diff.status, 'snapshot_invalid');
  assert.equal(diff.quality.reason, 'current_snapshot_count_drop');
  assert.equal(diff.disappeared.length, 0);
});

test('normal appeared candidate fetches only diff detail and creates dispatch signal through exact link', async () => {
  const previousRows = normalizeUsingCarSnapshotRows({ normalRows: [normalRow('schedule-old')], seenAt });
  const currentRows = normalizeUsingCarSnapshotRows({
    normalRows: [normalRow('schedule-old'), normalRow('schedule-new')],
    seenAt,
  });
  const diff = buildSnapshotDiff({ previousRows, currentRows });
  let detailCalls = 0;

  const signals = await verifyDiffCandidates({
    diff,
    token: 'fake-token',
    links: linkMap([
      {
        id: 'link-1',
        source_type: 'normal_schedule',
        external_reservation_id: 'schedule-new',
        external_detail_id: 'detail-schedule-new',
        external_status: 'linked',
        reservation_id: 'R-1',
      },
    ]),
    reservations: reservationMap(),
    schedules: scheduleMap('R-1', [
      { id: 'S-dispatch-1', reservation_id: 'R-1', schedule_type: '배차', schedule_done: false },
      { id: 'S-return-1', reservation_id: 'R-1', schedule_type: '반납', schedule_done: false },
    ]),
    fetchNormalDetail: async ({ scheduleId }) => {
      detailCalls += 1;
      assert.equal(scheduleId, 'schedule-new');
      return { status: 'using_car', car_number: '101하9300' };
    },
    fetchInsuranceDetail: async () => {
      throw new Error('insurance detail should not be called');
    },
  });

  assert.equal(detailCalls, 1);
  assert.equal(signals.length, 1);
  assert.equal(signals[0].status, 'signal');
  assert.equal(signals[0].eventType, 'ims.lifecycle.dispatch_detected');
  assert.equal(signals[0].scheduleId, 'S-dispatch-1');
});

test('normal disappeared candidate becomes return signal only after returned detail confirmation', async () => {
  const previousRows = normalizeUsingCarSnapshotRows({ normalRows: [normalRow('schedule-returned')], seenAt });
  const diff = buildSnapshotDiff({ previousRows, currentRows: [], minCurrentRatio: 0, allowEmptyCurrent: true });

  const signals = await verifyDiffCandidates({
    diff,
    token: 'fake-token',
    links: linkMap([
      {
        id: 'link-return',
        source_type: 'normal_schedule',
        external_reservation_id: 'schedule-returned',
        external_status: 'linked',
        reservation_id: 'R-return',
      },
    ]),
    reservations: reservationMap({ reservation_id: 'R-return' }),
    schedules: scheduleMap('R-return', [
      { id: 'S-return-1', reservation_id: 'R-return', schedule_type: '반납', schedule_done: false },
    ]),
    fetchNormalDetail: async () => ({ status: 'returned', car_number: '101하9300' }),
    fetchInsuranceDetail: async () => {
      throw new Error('insurance detail should not be called');
    },
  });

  assert.equal(signals[0].status, 'signal');
  assert.equal(signals[0].eventType, 'ims.lifecycle.return_detected');
  assert.equal(signals[0].scheduleId, 'S-return-1');
});

test('normal disappeared overdue_return is not treated as returned', async () => {
  const previousRows = normalizeUsingCarSnapshotRows({ normalRows: [normalRow('schedule-overdue')], seenAt });
  const diff = buildSnapshotDiff({ previousRows, currentRows: [], minCurrentRatio: 0, allowEmptyCurrent: true });

  const signals = await verifyDiffCandidates({
    diff,
    token: 'fake-token',
    links: linkMap([
      {
        id: 'link-overdue',
        source_type: 'normal_schedule',
        external_reservation_id: 'schedule-overdue',
        external_status: 'linked',
        reservation_id: 'R-overdue',
      },
    ]),
    reservations: reservationMap({ reservation_id: 'R-overdue' }),
    schedules: scheduleMap('R-overdue', [
      { id: 'S-return-1', reservation_id: 'R-overdue', schedule_type: '반납', schedule_done: false },
    ]),
    fetchNormalDetail: async () => ({ status: 'overdue_return', car_number: '101하9300' }),
    fetchInsuranceDetail: async () => {
      throw new Error('insurance detail should not be called');
    },
  });

  assert.equal(signals[0].status, 'no_signal');
  assert.equal(signals[0].reason, 'snapshot_disappeared_overdue_return');
});

test('insurance disappeared candidate requires returned claim contract before return signal', async () => {
  const previousRows = normalizeUsingCarSnapshotRows({ insuranceRows: [insuranceRow('claim-returned')], seenAt });
  const diff = buildSnapshotDiff({ previousRows, currentRows: [], minCurrentRatio: 0, allowEmptyCurrent: true });

  const signals = await verifyDiffCandidates({
    diff,
    token: 'fake-token',
    links: linkMap([
      {
        id: 'link-claim',
        source_type: 'insurance_claim',
        external_reservation_id: 'claim-returned',
        external_detail_id: 'claim-returned',
        external_status: 'linked',
        reservation_id: 'R-claim',
      },
    ]),
    reservations: reservationMap({ reservation_id: 'R-claim' }),
    schedules: scheduleMap('R-claim', [
      { id: 'S-return-claim', reservation_id: 'R-claim', schedule_type: '반납', schedule_done: false },
    ]),
    fetchNormalDetail: async () => {
      throw new Error('normal detail should not be called');
    },
    fetchInsuranceDetail: async () => ({
      claim_state: 'send_claim',
      contracts: [{ rent_car_number: '101하9300', return_date: '2026-07-26 12:30:00' }],
    }),
  });

  assert.equal(signals[0].status, 'signal');
  assert.equal(signals[0].eventType, 'ims.lifecycle.return_detected');
  assert.equal(signals[0].event.ims.returnAt, '2026-07-26 12:30');
});

test('diff candidate without exact OPS IMS link stays manual_review and skips detail lookup', async () => {
  const previousRows = normalizeUsingCarSnapshotRows({ normalRows: [normalRow('schedule-orphan')], seenAt });
  const diff = buildSnapshotDiff({ previousRows, currentRows: [], minCurrentRatio: 0, allowEmptyCurrent: true });
  let detailCalls = 0;

  const signals = await verifyDiffCandidates({
    diff,
    token: 'fake-token',
    links: new Map(),
    reservations: new Map(),
    schedules: new Map(),
    fetchNormalDetail: async () => {
      detailCalls += 1;
      return {};
    },
    fetchInsuranceDetail: async () => ({}),
  });

  assert.equal(detailCalls, 0);
  assert.equal(signals[0].status, 'manual_review');
  assert.equal(signals[0].reason, 'exact_link_not_found');
});

test('write modes are blocked without explicit allowDbWrite', async () => {
  await assert.rejects(
    () => buildUsingCarSnapshotDiffReport({
      mode: 'save-snapshot',
      currentSnapshot: { rows: [], errors: [] },
      previousRows: [],
    }),
    /allow_db_write_required/,
  );
});

test('ops handoff send is disabled for IMS lifecycle automation', async () => {
  await assert.rejects(
    () => buildUsingCarSnapshotDiffReport({
      mode: 'report',
      allowOpsHandoffSend: true,
      currentSnapshot: { rows: [], errors: [] },
      previousRows: [],
    }),
    /ops_handoff_send_disabled/,
  );

  await assert.rejects(
    () => buildUsingCarSnapshotDiffReport({
      mode: 'send-events',
      currentSnapshot: { rows: [], errors: [] },
      previousRows: [],
    }),
    /send_events_disabled/,
  );
});
