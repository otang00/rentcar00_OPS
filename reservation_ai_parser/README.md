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
- `POST /ims/change-reservation-car`

그 외 path/method 는 차단 방향으로 유지한다.

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