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

test('mapHomepageReservationPayload maps carmore sync reservation with provider dedupe id and badge metadata', () => {
  const body = {
    eventId: 'reservation.created:external-provider:carmore:2172_2026072501001',
    provider: 'carmore',
    reservationInput: {
      sourceProvider: 'carmore',
      sourceReservationId: '2172_2026072501001',
      sourceReservationNo: '2172_2026072501001',
      customerName: '테스트고객',
      customerPhone: '010-1111-9561',
      carNumber: '101하9300',
      carName: '더 뉴 코나 (2023)',
      pickupAt: '2026-07-30 09:00:00+09:00',
      returnAt: '2026-08-01 15:30:00+09:00',
      paymentAmount: 192000,
      pickupLocation: '서울 양천구 신월동 494-12',
      dropoffLocation: '서울 양천구 신월동 494-12',
      memo: '카모아 계약 참고\n고객명: 테스트고객\n배차지: 서울 양천구 신월동 494-12',
      providerCheckStatus: 'found',
    },
    booking: {
      bookingOrderId: 'external-provider:carmore:2172_2026072501001',
    },
  };

  const mapped = mapHomepageReservationPayload(body);

  assert.equal(mapped.reservationId, 'EXT-carmore-2172_2026072501001');
  assert.equal(mapped.reservationNumber, '2172_2026072501001');
  assert.equal(mapped.sourceProvider, 'carmore');
  assert.equal(mapped.sourceReservationId, '2172_2026072501001');
  assert.equal(mapped.providerCheckStatus, 'found');
  assert.equal(mapped.createdVia, 'sync_reservation_event');
  assert.equal(mapped.referralSource, 'carmore');
  assert.equal(mapped.carNumber, '101하9300');
  assert.equal(mapped.paymentAmount, '192000');
  assert.equal(mapped.pickupLocation, '서울 양천구 신월동 494-12');
  assert.equal(mapped.dropoffLocation, '서울 양천구 신월동 494-12');
  assert.match(mapped.noteText, /카모아 계약 참고/);
  assert.match(mapped.noteText, /배차지: 서울 양천구 신월동 494-12/);
  assert.equal(mapped.metaJson.source_provider, 'carmore');
  assert.equal(mapped.metaJson.source_reservation_id, '2172_2026072501001');
  assert.equal(mapped.metaJson.provider_check_status, 'found');
});

test('mapHomepageReservationPayload keeps homepage reservation id compatibility', () => {
  const mapped = mapHomepageReservationPayload({
    eventId: 'evt-homepage-1',
    reservationInput: { bookingOrderId: 'BO-1' },
    booking: { bookingOrderId: 'BO-1' },
  });

  assert.equal(mapped.reservationId, 'WEB-BO-1');
  assert.equal(mapped.sourceProvider, 'homepage');
  assert.equal(mapped.createdVia, 'homepage_reservation_event');
  assert.equal(mapped.referralSource, '홈페이지');
  assert.equal(mapped.metaJson.homepage_review, 'pending');
});

test('mapHomepageReservationPayload maps IMS partner source without falling back to homepage', () => {
  const mapped = mapHomepageReservationPayload({
    eventId: 'reservation.created:ims-partner:IMS-5684',
    provider: 'ims_partner',
    reservationInput: {
      sourceProvider: 'ims_partner',
      imsReservationId: 'IMS-5684',
      externalDetailId: 'DETAIL-5684',
      partnerName: '카카오',
      rentalType: 'daily',
      customerName: '홍길동',
      customerPhone: '010-1234-5684',
      carNumber: '12가5684',
      pickupAt: '2026-08-10 18:00:00+09:00',
      returnAt: '2026-08-10 21:00:00+09:00',
    },
    booking: {
      bookingOrderId: 'ims-partner:IMS-5684',
    },
  });

  assert.equal(mapped.reservationId, 'EXT-ims_partner-IMS-5684');
  assert.equal(mapped.sourceProvider, 'ims_partner');
  assert.equal(mapped.sourceReservationId, 'IMS-5684');
  assert.equal(mapped.reservationNumber, 'DETAIL-5684');
  assert.equal(mapped.createdVia, 'sync_reservation_event');
  assert.equal(mapped.referralSource, '카카오');
  assert.equal(mapped.metaJson.homepage_review, null);
  assert.equal(mapped.metaJson.partner_name, '카카오');
  assert.equal(mapped.metaJson.rental_type, 'daily');
});
