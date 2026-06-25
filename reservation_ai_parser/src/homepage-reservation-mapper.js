export function mapHomepageReservationPayload(body = {}) {
  const booking = body?.booking && typeof body.booking === 'object' ? body.booking : {};
  const input = body?.reservationInput && typeof body.reservationInput === 'object' ? body.reservationInput : {};
  const links = body?.links && typeof body.links === 'object' ? body.links : {};
  const bookingOrderId = firstText(input.bookingOrderId, booking.bookingOrderId);
  const reservationNumber = firstText(input.reservationCode, input.reservationNumber, booking.reservationCode);
  const seed = bookingOrderId || reservationNumber || firstText(body.eventId);
  const reservationId = `WEB-${seed}`.replace(/[^A-Za-z0-9_-]/g, '-').slice(0, 120);
  const startAt = normalizeIsoDate(firstText(input.pickupAt, input.startAt, input.rentalAt, booking.pickupAt));
  const endAt = normalizeIsoDate(firstText(input.returnAt, input.endAt, booking.returnAt));
  const pickupLocation = firstText(input.pickupLocation, input.deliveryAddress, input.deliveryAddressSummary, booking.deliveryAddressSummary);
  const dropoffLocation = firstText(input.dropoffLocation, input.returnLocation, pickupLocation);
  const customerPhone = normalizePhone(firstText(input.customerPhone, input.phone, booking.customerPhone));
  const paymentAmount = normalizeAmountText(firstText(input.quotedTotalAmount, input.totalAmount, input.paymentAmount, booking.quotedTotalAmount));
  const customerBirthDate = normalizeBirthDate(firstText(input.customerBirth, input.customerBirthDate, input.birthDate, booking.customerBirth));

  return {
    reservationId,
    reservationNumber,
    customerName: firstText(input.customerName, input.name, booking.customerName),
    customerPhone,
    customerBirthDate,
    carNumber: firstText(input.carNumber, booking.carNumber),
    carName: firstText(input.carName, booking.carName),
    startAt,
    endAt,
    pickupLocation,
    dropoffLocation,
    paymentAmount,
    noteText: firstText(input.memo, input.note, `홈페이지 예약 ${reservationNumber || bookingOrderId}`),
    metaJson: {
      source: 'homepage',
      event_id: firstText(body.eventId),
      booking_order_id: bookingOrderId || null,
      reservation_code: reservationNumber || null,
      admin_booking_url: firstText(links.adminBookingUrl) || null,
      homepage_review: 'pending',
      reservation_input: input,
      booking,
    },
  };
}

export function normalizeBirthDate(value) {
  const text = firstText(value);
  if (!text) return '';

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
