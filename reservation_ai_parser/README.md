# reservation_ai_parser

rentcar00_OPS 예약생성 화면에 연결할 앱 전용 AI파서 서비스.

## 역할
- 예약 원문 텍스트를 입력받음
- OpenAI를 단발 호출해 예약생성용 JSON으로 해석
- 앱 폼 자동 채움용 결과만 반환
- 예약 저장/승인/텔레그램 흐름은 포함하지 않음
- 맥미니에서 **중간서버**로 실행한다
- 앱은 **Cloudflare Tunnel 고정 HTTPS 도메인**으로 이 서버를 호출한다

## 운영 기준
- 서버 로컬 바인딩은 `127.0.0.1:43110`
- 외부에서 `43110` 포트를 직접 열지 않음
- 같은 Wi‑Fi 전제 금지
- 로컬 IP를 운영 주소로 쓰지 않음
- 고정 IP 마련을 전제로 하지 않음
- 외부 공개는 Cloudflare Tunnel 도메인만 사용

## 허용 엔드포인트
- `GET /health`
- `POST /parse-reservation`
- `POST /ims/create-reservation`
- `POST /ims/search-reservations`
- `POST /ims/search-insurance-claims`
- `POST /ims/change-reservation-car`
- `POST /ims/delete-reservation`
- `POST /ims/complete-reservation-return`
- `POST /api/integrations/rentcar00/reservation-events`

그 외 path/method 는 차단 방향으로 유지한다.

## 홈페이지 예약 이벤트 수신
홈페이지 예약 확정 시 `reservation.created` 이벤트를 받아 Supabase inbox에 저장한다.

Endpoint:
```txt
POST /api/integrations/rentcar00/reservation-events
```

필요 env 이름:
```txt
OPS_APP_RESERVATION_EVENT_SECRET
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
OPS_APP_RESERVATION_EVENT_TIMESTAMP_TOLERANCE_MS
```

서명 기준:
```txt
X-Rentcar00-Event-Type: reservation.created
X-Rentcar00-Event-Id: {eventId}
X-Rentcar00-Timestamp: {unixMs}
X-Rentcar00-Signature: sha256={hmacHex}

HMAC-SHA256(secret, `${timestamp}.${rawBody}`)
```

응답 기준:
```json
{ "ok": true, "deduped": false }
```

중복 eventId:
```json
{ "ok": true, "deduped": true }
```

저장 테이블:
```txt
rc00_ops_reservation_events
```

주의:
- timestamp 허용 오차 기본값은 5분이다.
- secret 값은 문서/채팅/로그에 남기지 않는다.
- DB migration 실제 반영, secret 주입, 서버 restart는 별도 운영 승인 후 진행한다.

## 실행
```bash
cp .env.example .env
node src/server.js --check
node src/server.js
```

## 시뮬레이션
```bash
node src/simulate.js "내일 오전 10시부터 모레 오전 9시까지 123허4567 김포공항 홍길동 01012345678"
```

## 엔드포인트
### POST /parse-reservation
Request:
```json
{
  "text": "예약 원문"
}
```

### POST /ims/create-reservation
Request:
```json
{
  "rentalAt": "2026-05-14 10:00",
  "returnAt": "2026-05-15 10:00",
  "carNumber": "123허4567",
  "totalFee": "80000",
  "customerName": "홍길동",
  "customerPhone": "01012345678",
  "address": "김포공항",
  "useDelivery": true,
  "memo": "예약:R-001 | 생년:1984-11-15"
}
```

Response:
```json
{
  "ok": true,
  "payload": {
    "rentalAt": "2026-05-14 10:00",
    "returnAt": "2026-05-15 10:00",
    "carNumber": "123허4567",
    "totalFee": "80000",
    "customerName": "홍길동",
    "customerPhone": "01012345678",
    "address": "김포공항",
    "useDelivery": true,
    "memo": "예약:R-001 | 생년:1984-11-15"
  },
  "result": {
    "code": "DRY_RUN",
    "message": "IMS_SAVE=true required for actual save"
  }
}
```

### POST /ims/search-reservations
기존 IMS 예약을 OPS로 가져오기 위한 조회 endpoint다.

현재 기준:
- Playwright export fallback은 서버 코드에서 제거했다.
- `GET /v2/company-car-schedules/reservations` 빠른 조회만 사용한다.
- 차량번호 필터는 `option=car_identity`를 사용한다.
- 느린 `/v2/company-car-schedules?page=N` 전체 목록 scan fallback은 사용하지 않는다.
- 앱은 OPS 차량 목록에서 선택된 전체 차량번호를 보내며, 이름은 검색 조건으로 쓰지 않는다.

Request:
```json
{
  "carNumber": "125호6498",
  "rentalDate": "2026-05-17"
}
```

Response:
```json
{
  "ok": true,
  "result": {
    "code": "SUCCESS",
    "totalCount": 1,
    "items": [
      {
        "scheduleId": "4189193",
        "detailId": "1209496",
        "reservationNumber": "1209496",
        "carNumber": "125호6498",
        "customerName": "홍길동",
        "customerPhone": "01000000000",
        "rentalAt": "2026-05-17 10:00",
        "returnAt": "2026-05-18 10:00"
      }
    ]
  }
}
```

주의:
- 조회 전용이다. IMS 상태를 변경하지 않는다.
- Playwright 경로는 운영 코드에서 쓰지 않고, 과거 조사 참고로만 둔다.
- OPS 앱은 선택된 항목의 `scheduleId/detailId`를 external link로 저장하고, IMS 새 생성은 호출하지 않는다.

### POST /ims/search-insurance-claims
보험계약서 목록에서 대여일 기준 보험배차를 조회하는 endpoint다.
차량 상세의 `배차 > 보험` IMS 보험배차 가져오기 창에서 사용한다.

서버 내부 조회 기준:
```txt
GET /v2/rencar-claims
periodOption=using_car
startdate=YYYY-MM-DD
enddate=YYYY-MM-DD
option=rent_car_number
value=<차량번호>
```

Request:
```json
{
  "carNumber": "125하1717",
  "rentalDate": "2026-05-19"
}
```

Response:
```json
{
  "ok": true,
  "result": {
    "code": "SUCCESS",
    "totalCount": 1,
    "items": [
      {
        "claimId": "3011022",
        "status": "using_car",
        "carNumber": "125하1717",
        "carName": "그랜저",
        "customerName": "강영욱",
        "customerPhone": "01000000000",
        "rentalAt": "2026-05-19 13:04",
        "returnAt": ""
      }
    ]
  }
}
```

주의:
- 조회 전용이다. IMS 상태를 변경하지 않는다.
- 날짜 query key는 `startDate/endDate`가 아니라 `startdate/enddate` 소문자를 사용해야 필터가 적용된다.

### POST /ims/change-reservation-car
IMS에 이미 생성된 예약의 차량을 변경한다.

Request:
```json
{
  "scheduleId": "4189163",
  "rentalAt": "2026-12-15 10:00",
  "returnAt": "2026-12-15 12:00",
  "carNumber": "101허4014",
  "reservationId": "R-001"
}
```

Response:
```json
{
  "ok": true,
  "result": {
    "code": "SUCCESS",
    "externalStatus": "linked",
    "externalReservationId": "4189163"
  }
}
```

주의:
- 실제 IMS 상태를 변경한다.
- `scheduleId`는 IMS `company-car-schedules` id다.
- `carNumber`는 대상 차량번호이며 서버가 available API로 IMS 내부 `company_car_id`를 조회한다.


### POST /ims/delete-reservation
IMS에 이미 생성된 예약을 삭제한다.

Request:
```json
{
  "scheduleId": "4189163",
  "reservationId": "R-001"
}
```

Response:
```json
{
  "ok": true,
  "result": {
    "code": "SUCCESS",
    "externalStatus": "deleted",
    "externalReservationId": "4189163"
  }
}
```

주의:
- 실제 IMS 상태를 변경한다.
- 예약취소 확인 흐름에서만 호출한다.
- 내부 호출 대상은 `POST /v2/company-car-schedules/delete`이며 body는 `{ "ids": [scheduleId] }`다.


### POST /ims/complete-reservation-return
IMS에 이미 배차중인 계약을 반납완료 처리한다.

Request:
```json
{
  "contractId": "1209357",
  "doneAt": "2026-05-17-12-30",
  "returnGasCharge": 70,
  "drivenDistanceUponReturn": "70483",
  "fuelCost": -7010,
  "reservationId": "R-001"
}
```

Response:
```json
{
  "ok": true,
  "result": {
    "code": "SUCCESS",
    "externalStatus": "linked",
    "externalReservationId": "204340"
  }
}
```

주의:
- 실제 IMS 상태를 변경한다.
- `contractId`는 IMS `normal-contracts` detail id이며, 앱은 저장된 `externalDetailId`를 우선 사용하고 없으면 `externalReservationId`를 fallback으로 사용한다.
- 내부 호출 대상은 `POST /v2/normal-contracts/{contractId}/set-done`이다.
- `returnGasCharge`, `drivenDistanceUponReturn`, `fuelCost`는 필수다. OPS 앱은 IMS 연결 반납 시 입력창에서 세 값을 받은 뒤 호출한다.

Response:
```json
{
  "ok": true,
  "fields": {
    "reservationNumber": null,
    "customerName": null,
    "customerPhone": null,
    "birthDate": null,
    "referrer": null,
    "price": null,
    "carNumber": null,
    "carName": null,
    "pickupAt": null,
    "returnAt": null,
    "pickupLocation": null,
    "returnLocation": null,
    "note": null
  },
  "missing": [],
  "warnings": [],
  "meta": {
    "intent": "reservation_create",
    "repairAttempted": false,
    "source": "openai"
  }
}
```
