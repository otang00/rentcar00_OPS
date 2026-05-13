# rentcar00_OPS Current Snapshot Archive

원본 파일: `docs/rentcar00_OPS-current.md`
아카이브 시각: 2026-05-13 KST
사유: current 문서를 IMS/원장 구조 작업 기준으로 교체하기 전, 기존 AI파서 연결 계획을 보존한다.

---

# rentcar00_OPS Current

## 1. 현재 작업
예약생성 AI파서 연결.

## 2. 오늘 잠금 스냅샷 (2026-05-13 21:33 KST)
- 현재 task는 **AI파서 연결 1건만** 본다.
- 운영 도메인 후보는 **`https://parser.00rentcar.com`** 으로 잠근다.
- 목표 연결 구조는 **앱 → `parser.00rentcar.com` → Cloudflare Tunnel → `http://127.0.0.1:43110`** 이다.
- 로컬 AI파서 서버는 **실기동 및 로컬 health/parse 응답 확인 완료** 상태다.
- Cloudflare custom hostname 연결은 **origin cert/login 선행 필요** 상태다.
- 앱 `AI_PARSER_BASE_URL` 실값 반영은 **아직 안 했다.**
- 즉, 현재는 **로컬 parser 검증 완료 / custom domain 연결 대기 / 앱 실연결 미완료** 상태다.

## 3. 최종 구조
- 직원 앱은 OpenAI를 직접 호출하지 않는다.
- 맥미니가 AI파서 **중간서버** 역할을 한다.
- 맥미니 AI파서 서버가 OpenAI API를 호출한다.
- 앱은 **Cloudflare Tunnel 고정 HTTPS 도메인**만 호출한다.
- 맥미니 로컬 서버는 **`127.0.0.1:43110`** 에만 바인딩한다.
- 외부에서 `43110` 포트를 직접 열지 않는다.

## 4. 목표 화면
- 예약생성 `AlertDialog` 제목 우측에 `AI파서` 버튼을 둔다.
- 버튼 탭 시 텍스트 입력 dialog 를 연다.
- dialog 상단에 연결 체크 아이콘을 둔다.
- 예약 원문 텍스트를 AI파서로 보내고 응답 JSON 으로 폼을 자동 채운다.
- 최종 저장은 기존 예약생성 저장 흐름을 그대로 사용한다.

## 5. 운영 잠금 원칙
- 기존 텔레그램 파서봇은 건드리지 않는다.
- 앱용 AI파서는 `reservation_ai_parser/` 에서 별도 운영한다.
- 1차 목표는 **자동 저장이 아니라 폼 자동 채움**이다.
- 입력 방식은 **텍스트만**으로 잠근다.
- 사진 입력은 이번 범위에서 제외한다.
- 파싱은 OpenAI **단발 호출 1회** 기준으로 한다.
- 날짜가 흔들릴 때만 repair 1회 추가 호출을 허용한다.
- 외부 공개는 Cloudflare Tunnel 도메인만 사용한다.
- 로컬 IP / 같은 Wi‑Fi / 고정 IP 마련 전제는 금지한다.

## 6. API 최소 표면
### 허용
- `GET /health`
- `POST /parse-reservation`

### 차단
- 그 외 모든 path 는 404
- 허용 외 method 는 405
- 요청 body size 제한 유지
- timeout 유지

## 7. 입력/출력 계약
### 요청
```json
{
  "text": "예약 원문"
}
```

### 응답
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
    "repairAttempted": false
  }
}
```

## 8. Phase별 실행 계획
### Phase 1. 서버 바인딩/보안 기준 고정
- 목적: 외부에서 43110 포트를 직접 때릴 수 없는 구조로 잠근다.

### Phase 2. 파서 API 최소 완성
- 목적: 텍스트 1건을 보내면 안정적으로 폼용 JSON 을 반환한다.

### Phase 3. Cloudflare Tunnel 연결
- 목적: 고정 IP 없이 외부 고정 HTTPS 주소를 확보한다.

### Phase 4. 앱 UI/네트워크 연결
- 목적: 앱에서 AI파서 버튼 → 입력 dialog → health 체크 → parse 호출까지 닫는다.

### Phase 5. 자동채움 품질/검토 UX 보강
- 목적: 잘못 채워져도 저장 전에 바로 보이게 만든다.

### Phase 6. 실사용 검증
- 목적: 이동 환경에서도 실제로 쓰일 수 있는지 확인한다.

## 9. 이번 범위에서 하지 않는 것
- 직원 앱의 OpenAI 직접 호출
- 같은 Wi‑Fi 전제 연결
- 로컬 IP를 운영 주소로 사용
- 고정 IP 마련
- 사진 입력
- 예약 자동 저장

## 10. 우선 수정 대상 파일
- `reservation_ai_parser/src/parser-core.js`
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `lib/features/status_board/detail/data/reservation_ai_parser_client.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/shared/config/app_env.dart`

## 11. 현재 확인된 미완료 항목
- `parser.00rentcar.com` named tunnel 생성을 위해 Cloudflare login/origin cert 단계를 완료해야 한다.
- `parser.00rentcar.com` 이 실제로 `127.0.0.1:43110` 으로 연결됐는지 health 응답으로 확인해야 한다.
- 앱 protected env 의 `AI_PARSER_BASE_URL` 실값 반영이 남아 있다.
- 외부망/LTE 기준 parse 실응답 검증이 남아 있다.

## 12. 다음 세션 빠른 재개 순서
1. 이 문서 `2. 오늘 잠금 스냅샷` 과 `11. 현재 확인된 미완료 항목` 부터 읽는다.
2. `reservation_ai_parser/README.md` 로 로컬 서버 기준을 다시 확인한다.
3. `memory/2026-05-13.md` 로 오늘 팩트체크 결과를 확인한다.
4. 그 다음에만 Cloudflare login 완료 여부 → named tunnel/도메인 health → env 반영 순서로 진행한다.
