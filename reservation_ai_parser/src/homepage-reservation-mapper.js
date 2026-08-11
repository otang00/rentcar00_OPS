export function mapHomepageReservationPayload(body = {}) {
  const booking = body?.booking && typeof body.booking === 'object' ? body.booking : {};
  const input = body?.reservationInput && typeof body.reservationInput === 'object' ? body.reservationInput : {};
  const links = body?.links && typeof body.links === 'object' ? body.links : {};

  const sourceProvider = normalizeSourceProvider(firstText(
    input.sourceProvider,
    input.provider,
    booking.sourceProvider,
    booking.provider,
    body.sourceProvider,
    body.provider,
  ));
  const bookingOrderId = firstText(input.bookingOrderId, booking.bookingOrderId);
  const sourceReservationId = firstText(
    input.sourceReservationId,
    input.imsReservationId,
    input.ims_reservation_id,
    input.externalReservationId,
    input.external_reservation_id,
    input.providerReservationId,
    booking.sourceReservationId,
    booking.externalReservationId,
    booking.external_reservation_id,
    booking.providerReservationId,
  );
  const sourceReservationNo = firstText(
    input.sourceReservationNo,
    input.externalReservationNo,
    input.external_reservation_no,
    input.externalDetailId,
    input.external_detail_id,
    input.imsDetailId,
    input.ims_detail_id,
    input.providerReservationNo,
    booking.sourceReservationNo,
    booking.externalReservationNo,
    booking.external_reservation_no,
    booking.providerReservationNo,
  );
  const reservationNumber = firstText(
    sourceReservationNo,
    input.reservationCode,
    input.reservationNumber,
    booking.reservationCode,
    booking.reservationNumber,
  );
  const reservationIdSeed = buildReservationIdSeed({
    sourceProvider,
    sourceReservationId,
    bookingOrderId,
    reservationNumber,
    eventId: firstText(body.eventId),
  });
  const reservationId = sanitizeReservationId(reservationIdSeed);
  const startAt = normalizeIsoDate(firstText(input.pickupAt, input.startAt, input.rentalAt, booking.pickupAt, booking.rentalAt));
  const endAt = normalizeIsoDate(firstText(input.returnAt, input.endAt, booking.returnAt));
  const pickupLocation = firstText(input.pickupLocation, input.deliveryAddress, input.deliveryAddressSummary, booking.deliveryAddressSummary, booking.pickupLocation);
  const dropoffLocation = firstText(input.dropoffLocation, input.returnLocation, booking.dropoffLocation, pickupLocation);
  const customerPhone = normalizePhone(firstText(input.customerPhone, input.phone, booking.customerPhone));
  const paymentAmount = normalizeAmountText(firstText(input.quotedTotalAmount, input.totalAmount, input.paymentAmount, input.amount, booking.quotedTotalAmount, booking.totalAmount, booking.paymentAmount, booking.amount));
  const customerBirthDate = normalizeBirthDate(firstText(input.customerBirth, input.customerBirthDate, input.birthDate, booking.customerBirth, booking.customerBirthDate, booking.birthDate));
  const providerCheckStatus = normalizeProviderCheckStatus(firstText(
    input.providerCheckStatus,
    input.provider_check_status,
    booking.providerCheckStatus,
    booking.provider_check_status,
    body.providerCheckStatus,
    body.provider_check_status,
  ));
  const createdVia = sourceProvider === 'homepage' ? 'homepage_reservation_event' : 'sync_reservation_event';
  const providerLabel = sourceProvider === 'homepage'
    ? '홈페이지'
    : firstText(input.partnerName, input.partner_name, sourceProvider === 'ims_partner' ? 'IMS파트너' : sourceProvider);

  return {
    reservationId,
    reservationNumber,
    sourceProvider,
    sourceReservationId,
    providerCheckStatus,
    createdVia,
    referralSource: sourceProvider === 'homepage' ? '홈페이지' : providerLabel,
    customerName: firstText(input.customerName, input.name, booking.customerName),
    customerPhone,
    customerBirthDate,
    carNumber: firstText(input.carNumber, input.vehicleNumber, booking.carNumber, booking.vehicleNumber),
    carName: firstText(input.carName, input.vehicleName, booking.carName, booking.vehicleName),
    startAt,
    endAt,
    pickupLocation,
    dropoffLocation,
    paymentAmount,
    noteText: firstText(input.memo, input.note, booking.memo, booking.note, `${providerLabel} 예약 ${reservationNumber || sourceReservationId || bookingOrderId}`),
    metaJson: {
      source: sourceProvider,
      event_id: firstText(body.eventId),
      booking_order_id: bookingOrderId || null,
      reservation_code: reservationNumber || null,
      source_provider: sourceProvider,
      source_reservation_id: sourceReservationId || null,
      provider_check_status: providerCheckStatus,
      partner_name: firstText(input.partnerName, input.partner_name) || null,
      rental_type: firstText(input.rentalType, input.rental_type) || null,
      admin_booking_url: firstText(links.adminBookingUrl) || null,
      homepage_review: sourceProvider === 'homepage' ? 'pending' : null,
      reservation_input: input,
      booking,
    },
  };
}

export function normalizeBirthDate(value) {
  const text = firstText(value);
  if (!text) return '';

  const shortMatch = text.match(/^(\d{2})(\d{2})(\d{2})$/);
  if (shortMatch) {
    const yy = Number(shortMatch[1]);
    const year = yy >= 30 ? `19${shortMatch[1]}` : `20${shortMatch[1]}`;
    return formatValidDateParts(year, shortMatch[2], shortMatch[3]);
  }

  const compactMatch = text.match(/^(\d{4})(\d{2})(\d{2})$/);
  if (compactMatch) return formatValidDateParts(compactMatch[1], compactMatch[2], compactMatch[3]);

  const separatedMatch = text.match(/^(\d{4})[-./\s](\d{1,2})[-./\s](\d{1,2})$/);
  if (separatedMatch) {
    return formatValidDateParts(
      separatedMatch[1],
      separatedMatch[2].padStart(2, '0'),
      separatedMatch[3].padStart(2, '0'),
    );
  }

  return '';
}

function buildReservationIdSeed({ sourceProvider, sourceReservationId, bookingOrderId, reservationNumber, eventId }) {
  if (sourceProvider && sourceProvider !== 'homepage' && sourceReservationId) {
    return `EXT-${sourceProvider}-${sourceReservationId}`;
  }
  const seed = bookingOrderId || reservationNumber || eventId;
  return `WEB-${seed}`;
}

function sanitizeReservationId(value) {
  return firstText(value).replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 120);
}

function normalizeSourceProvider(value) {
  const text = firstText(value).toLowerCase();
  if (text === 'carmore' || text === '카모아') return 'carmore';
  if (text === 'zzimcar' || text === '찜카') return 'zzimcar';
  if (['ims_partner', 'ims-partner', 'imspartner', 'ims partner', 'ims'].includes(text)) return 'ims_partner';
  return 'homepage';
}

function normalizeProviderCheckStatus(value) {
  const text = firstText(value).toLowerCase();
  if (['found', 'not_found', 'cancelled_found', 'error', 'not_checked'].includes(text)) return text;
  return text || 'not_checked';
}

function formatValidDateParts(year, month, day) {
  const y = Number(year);
  const m = Number(month);
  const d = Number(day);
  if (!Number.isInteger(y) || !Number.isInteger(m) || !Number.isInteger(d)) return '';
  if (y < 1000 || m < 1 || m > 12 || d < 1 || d > 31) return '';

  const date = new Date(Date.UTC(y, m - 1, d));
  if (
    date.getUTCFullYear() !== y
    || date.getUTCMonth() !== m - 1
    || date.getUTCDate() !== d
  ) {
    return '';
  }

  return `${String(y).padStart(4, '0')}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

function normalizeIsoDate(value) {
  const text = firstText(value);
  if (!text) return '';
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
}

function normalizePhone(value) {
  return firstText(value).replace(/[^0-9]/g, '');
}

function normalizeAmountText(value) {
  const text = firstText(value);
  if (!text) return '';
  const num = Number(String(text).replace(/[^0-9.-]/g, ''));
  return Number.isFinite(num) ? String(Math.round(num)) : text;
}

function firstText(...values) {
  for (const value of values) {
    const text = stringifyNullable(value).trim();
    if (text) return text;
  }
  return '';
}

function stringifyNullable(value) {
  if (value === null || value === undefined) return '';
  return String(value);
}
