export function toImsInsuranceClaimImportItem(claim = {}) {
  return {
    sourceType: 'ims_insurance_claim',
    claimId: stringifyNullable(claim?.id),
    status: stringifyNullable(claim?.claim_state),
    carNumber: stringifyNullable(claim?.rent_car_number),
    carName: stringifyNullable(claim?.car_model),
    customerName: stringifyNullable(claim?.customer_name),
    customerPhone: digitsOnly(claim?.customer_contact),
    residentRegistrationNo: stringifyNullable(claim?.customer_id_number || claim?.registration_number),
    driverLicenseNo: stringifyNullable(claim?.driver_license_number || claim?.license_number),
    rentalAt: normalizeImsDateTime(claim?.delivered_at),
    returnAt: readImsInsuranceClaimExpectedReturnAt(claim),
    pickupLocation: stringifyNullable(claim?.customer_address),
    insuranceCompany: stringifyNullable(claim?.claim_user_company),
    claimUserName: stringifyNullable(claim?.claim_user_name),
    title: [
      stringifyNullable(claim?.business_name),
      stringifyNullable(claim?.claim_state),
    ].filter((value) => value.trim()).join(' | '),
  };
}

export function mergeImsInsuranceClaimListAndDetail(listClaim = {}, detailClaim = {}) {
  return {
    ...detailClaim,
    ...listClaim,
    expect_return_date: firstNonEmpty(detailClaim?.expect_return_date, listClaim?.expect_return_date),
    expected_return_date: firstNonEmpty(detailClaim?.expected_return_date, listClaim?.expected_return_date),
    expect_return_at: firstNonEmpty(detailClaim?.expect_return_at, listClaim?.expect_return_at),
    expected_return_at: firstNonEmpty(detailClaim?.expected_return_at, listClaim?.expected_return_at),
    contracts: firstArrayOrObject(detailClaim?.contracts, listClaim?.contracts),
    contractList: firstArrayOrObject(detailClaim?.contractList, listClaim?.contractList),
    contract_list: firstArrayOrObject(detailClaim?.contract_list, listClaim?.contract_list),
    details: firstArrayOrObject(detailClaim?.details, listClaim?.details),
    detail: firstArrayOrObject(detailClaim?.detail, listClaim?.detail),
    datas: mergeNestedObject(detailClaim?.datas, listClaim?.datas),
    data: mergeNestedObject(detailClaim?.data, listClaim?.data),
  };
}

export function readImsInsuranceClaimExpectedReturnAt(claim = {}) {
  const topLevel = firstNonEmpty(
    claim?.expect_return_date,
    claim?.expected_return_date,
    claim?.expect_return_at,
    claim?.expected_return_at,
    claim?.return_expected_date,
    claim?.return_expected_at,
    claim?.return_due_date,
    claim?.return_due_at,
    claim?.scheduled_return_date,
    claim?.scheduled_return_at,
    claim?.planned_return_date,
    claim?.planned_return_at,
    claim?.return_date,
  );
  if (topLevel) return normalizeImsDateTime(topLevel);

  const targetCarNumber = normalizeCarNumber(claim?.rent_car_number || claim?.car_number || claim?.car?.car_identity);
  const nested = readInsuranceClaimRows(claim);
  const carMatchedRows = targetCarNumber
    ? nested.filter((row) => normalizeCarNumber(
        row?.rent_car_number
        || row?.car_number
        || row?.car?.car_identity
        || row?.rent_car?.car_identity,
      ) === targetCarNumber)
    : nested;
  const rows = carMatchedRows.length > 0 ? carMatchedRows : nested;

  for (const row of rows) {
    const value = firstNonEmpty(
      row?.expect_return_date,
      row?.expected_return_date,
      row?.expect_return_at,
      row?.expected_return_at,
      row?.return_expected_date,
      row?.return_expected_at,
      row?.return_due_date,
      row?.return_due_at,
      row?.scheduled_return_date,
      row?.scheduled_return_at,
      row?.planned_return_date,
      row?.planned_return_at,
      row?.return_date,
    );
    if (value) return normalizeImsDateTime(value);
  }

  return '';
}

function firstArrayOrObject(...values) {
  for (const value of values) {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') return value;
  }
  return undefined;
}

function mergeNestedObject(primary, fallback) {
  if (primary && typeof primary === 'object' && fallback && typeof fallback === 'object') {
    return { ...fallback, ...primary };
  }
  if (primary && typeof primary === 'object') return primary;
  if (fallback && typeof fallback === 'object') return fallback;
  return undefined;
}

function readInsuranceClaimRows(claim = {}) {
  const candidates = [
    claim?.contracts,
    claim?.contractList,
    claim?.contract_list,
    claim?.details,
    claim?.detail,
    claim?.datas?.contracts,
    claim?.datas?.contractList,
    claim?.datas?.contract_list,
    claim?.data?.contracts,
    claim?.data?.contractList,
    claim?.data?.contract_list,
  ];
  const rows = [];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) rows.push(...candidate);
    else if (candidate && typeof candidate === 'object') rows.push(candidate);
  }
  return rows;
}

function normalizeImsDateTime(value) {
  const text = stringifyNullable(value).trim().replace('T', ' ');
  const match = text.match(/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})/);
  if (!match) return text;
  return `${match[1]} ${match[2]}`;
}

function normalizeCarNumber(value) {
  return stringifyNullable(value).replace(/\s+/g, '').toUpperCase();
}

function digitsOnly(value) {
  return stringifyNullable(value).replace(/\D+/g, '');
}

function firstNonEmpty(...values) {
  for (const value of values) {
    const text = stringifyNullable(value).trim();
    if (text) return text;
  }
  return '';
}

function stringifyNullable(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'object') return '';
  return String(value);
}
