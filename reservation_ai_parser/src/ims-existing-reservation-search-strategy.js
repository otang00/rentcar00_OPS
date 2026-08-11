export function extractDateText(value) {
  const text = String(value || '').trim();
  const match = text.match(/\d{4}-\d{2}-\d{2}/);
  if (match) return match[0];
  return text.split(/\s+/)[0] || '';
}

export function addDaysToDateText(value, days) {
  const text = extractDateText(value);
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return text;
  const utc = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  utc.setUTCDate(utc.getUTCDate() + Number(days || 0));
  const y = utc.getUTCFullYear();
  const m = String(utc.getUTCMonth() + 1).padStart(2, '0');
  const d = String(utc.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function normalizeImsScheduleId(schedule = {}) {
  return String(schedule?.id || schedule?.schedule_id || schedule?.company_car_schedule_id || '').trim();
}

export function dedupeImsSchedulesById(schedules = []) {
  const seen = new Set();
  const unique = [];
  for (const schedule of schedules) {
    const id = normalizeImsScheduleId(schedule);
    const key = id || JSON.stringify({
      car: schedule?.car?.car_identity || schedule?.car_identity || schedule?.car_number || schedule?.car || '',
      start: schedule?.start_at || schedule?.start || '',
      end: schedule?.end_at || schedule?.end || '',
    });
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(schedule);
  }
  return unique;
}

export function isUnder24HourWindow(payload = {}) {
  const startMs = parseImsDateTimeMs(payload.rentalAt || payload.rentalDate || payload.startDate);
  const endMs = parseImsDateTimeMs(payload.returnAt || payload.endDate || payload.returnDate);
  if (!Number.isFinite(startMs) || !Number.isFinite(endMs)) return false;
  const durationMs = endMs - startMs;
  return durationMs > 0 && durationMs < 24 * 60 * 60 * 1000;
}

export function buildImsReservationSearchQueries(payload = {}) {
  const startDate = extractDateText(payload.rentalAt || payload.rentalDate || payload.startDate);
  const endDate = extractDateText(payload.returnAt || payload.endDate || payload.returnDate) || startDate;
  if (!startDate) return [];

  const queries = [];
  const addQuery = ({ baseDate = startDate, start = startDate, end = endDate, dateOption = 'start_at' } = {}) => {
    const key = `${baseDate}|${start}|${end}|${dateOption}`;
    if (queries.some((query) => query.key === key)) return;
    queries.push({ key, baseDate, startDate: start, endDate: end, dateOption });
  };

  for (const dateOption of ['start_at', 'end_at']) {
    addQuery({ dateOption });
  }

  const sameDay = startDate === endDate;
  if (sameDay || isUnder24HourWindow(payload)) {
    const expandedStart = addDaysToDateText(startDate, -1);
    const expandedEnd = addDaysToDateText(endDate, 1);
    for (const dateOption of ['start_at', 'end_at']) {
      addQuery({
        baseDate: startDate,
        start: expandedStart,
        end: expandedEnd,
        dateOption,
      });
    }
  }

  return queries.map(({ key, ...query }) => query);
}

function parseImsDateTimeMs(value) {
  const text = String(value || '').trim();
  if (!text) return Number.NaN;
  const normalized = text.includes('T') ? text : text.replace(/^(\d{4}-\d{2}-\d{2})\s+/, '$1T');
  const parsed = Date.parse(normalized);
  return Number.isFinite(parsed) ? parsed : Number.NaN;
}
