import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  buildImsReservationSearchQueries,
  dedupeImsSchedulesById,
  extractDateText,
  isUnder24HourWindow,
} from '../src/ims-existing-reservation-search-strategy.js';

test('extractDateText reads the date part from space and ISO timestamps', () => {
  assert.equal(extractDateText('2026-08-08 10:00:00+09:00'), '2026-08-08');
  assert.equal(extractDateText('2026-08-08T10:00:00+00:00'), '2026-08-08');
});

test('same-day reservation search includes exact and widened start/end date options', () => {
  const queries = buildImsReservationSearchQueries({
    rentalAt: '2026-08-08 10:00',
    returnAt: '2026-08-08 20:00',
    carNumber: '142호5773',
  });

  assert.deepEqual(queries, [
    { baseDate: '2026-08-08', startDate: '2026-08-08', endDate: '2026-08-08', dateOption: 'start_at' },
    { baseDate: '2026-08-08', startDate: '2026-08-08', endDate: '2026-08-08', dateOption: 'end_at' },
    { baseDate: '2026-08-08', startDate: '2026-08-07', endDate: '2026-08-09', dateOption: 'start_at' },
    { baseDate: '2026-08-08', startDate: '2026-08-07', endDate: '2026-08-09', dateOption: 'end_at' },
  ]);
});

test('cross-day under-24h reservation also widens the search range', () => {
  assert.equal(isUnder24HourWindow({
    rentalAt: '2026-08-08 20:00',
    returnAt: '2026-08-09 02:00',
  }), true);

  const queries = buildImsReservationSearchQueries({
    rentalAt: '2026-08-08 20:00',
    returnAt: '2026-08-09 02:00',
  });

  assert.equal(queries.length, 4);
  assert.deepEqual(queries.at(-1), {
    baseDate: '2026-08-08',
    startDate: '2026-08-07',
    endDate: '2026-08-10',
    dateOption: 'end_at',
  });
});

test('multi-day reservation keeps the bounded exact start/end search options', () => {
  const queries = buildImsReservationSearchQueries({
    rentalAt: '2026-08-08 10:00',
    returnAt: '2026-08-11 10:00',
  });

  assert.deepEqual(queries, [
    { baseDate: '2026-08-08', startDate: '2026-08-08', endDate: '2026-08-11', dateOption: 'start_at' },
    { baseDate: '2026-08-08', startDate: '2026-08-08', endDate: '2026-08-11', dateOption: 'end_at' },
  ]);
});

test('dedupeImsSchedulesById removes duplicate candidates across search attempts', () => {
  const schedules = dedupeImsSchedulesById([
    { id: 4431253, car_identity: '142호5773' },
    { schedule_id: '4431253', car_identity: '142호5773' },
    { id: 4431254, car_identity: '142호5773' },
  ]);

  assert.deepEqual(schedules.map((schedule) => String(schedule.id || schedule.schedule_id)), ['4431253', '4431254']);
});
