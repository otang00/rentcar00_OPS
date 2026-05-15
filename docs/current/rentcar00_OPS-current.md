# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **현재 실행 문서**다.
현재 진행 중인 IMS 등록/삭제/가져오기 기준만 유지한다.
완료 이력은 `docs/completed/` 또는 `docs/past/`로 옮긴다.

---

## 현재 실행 작업
**IMS 등록 정보 정리 → 예약생성 시 IMS 등록 저장 → 예약취소/삭제 시 IMS 삭제 옵션 → IMS에서 가져오기**

## 핵심 기준
OPS 예약과 IMS 예약은 실시간 동기화하지 않는다.
OPS에는 IMS 예약의 `schedule_id`를 **등록 정보**로 저장한다.

`IMS등록됨`의 의미:
- OPS가 IMS `schedule_id`를 알고 있음
- IMS 예약이 현재도 IMS에 존재한다는 보장은 아님
- 관리자가 IMS에서 직접 삭제해도 OPS는 자동 감지하지 않음

따라서 화면 용어는 **IMS 등록 정보**로 쓴다.

---

## 확정 정책

### 1. 예약 상세 IMS 상태
#### 미등록
- 기능 카드: `IMS추가`
- `IMS 등록 정보` 섹션:
  - 상태: `미등록`
  - 안내: `IMS 예약을 새로 추가할 수 있습니다.`
  - 버튼: `IMS추가`

#### 등록됨
- 기능 카드: `IMS등록됨` 비활성
- `IMS 등록 정보` 섹션:
  - 상태: `IMS등록됨`
  - IMS ID: `schedule_id`
  - detail ID: export `detail_id`
  - 등록키: `OPS:{reservation_id}`
  - 마지막 등록/확인시각
  - 버튼: `등록해제`

#### 등록실패 / 등록해제 / 삭제됨
- 미등록처럼 취급한다.
- `IMS추가`만 다시 실행할 수 있다.
- 오류 메시지가 있으면 `IMS 등록 정보` 섹션에 표시한다.

### 2. `등록해제`
- IMS 예약을 삭제하지 않는다.
- OPS에 저장된 IMS 등록 정보만 `external_status='unlinked'`로 변경한다.
- 이후 사용자는 다시 `IMS추가`를 실행할 수 있다.

### 3. 수동 IMS 연결 제거
아래 기능은 만들지 않는다.
- 기존 IMS 예약을 현재 OPS 예약에 수동으로 붙이기
- 차량번호로 IMS 예약을 조회해서 현재 OPS 예약에 연결하기
- 자동 추천 매칭 / 수동 선택 연결

운영 기준:
- OPS 예약을 만들었는데 IMS에 이미 예약이 있어 `IMS추가`가 막히면, 관리자가 IMS에 직접 들어가 기존 예약을 정리한다.
- 그 다음 OPS에서 `IMS추가`를 다시 실행한다.

### 4. 예약취소/삭제 시 IMS 삭제 옵션
일반 예약 상세 화면에는 IMS 삭제 버튼을 두지 않는다.

예약취소/삭제 확인창에서만:
- IMS 등록 정보가 active일 때 `IMS 예약도 같이 삭제` 체크박스를 표시한다.
- 기본값은 체크 해제다.

체크한 경우:
1. 내부 예약취소/삭제 진행
2. IMS `schedule_id`로 IMS 예약 삭제 시도
3. IMS 삭제 성공 시 `external_status='deleted'`, `deleted_at` 기록
4. IMS 삭제 실패해도 내부 예약취소/삭제는 유지
5. 실패 메시지를 등록 정보에 기록

체크하지 않은 경우:
1. 내부 예약취소/삭제만 진행
2. IMS 예약은 그대로 둔다
3. OPS IMS 등록 정보는 `external_status='unlinked'`로 해제 처리한다.

### 5. IMS에서 가져오기
이 기능은 “기존 OPS 예약에 IMS 예약을 붙이는 기능”이 아니다.

정확한 의미:
- IMS 예약 목록에서 1건 선택
- 그 IMS 예약 정보를 기준으로 **새 OPS 예약을 생성**
- 저장 시 내부 예약 + 일정 + IMS 등록 정보를 함께 생성

즉, IMS 기준 예약이 이미 있으면 `IMS에서 가져오기`로 OPS 예약을 새로 만드는 게 정석이다.

---

## 현재 확인된 구조

### 앱 코드
- IMS payload builder
  `lib/features/reservations/detail/data/ims_reservation_payload.dart`
- IMS client
  `lib/features/reservations/detail/data/ims_reservation_client.dart`
- 예약 상세 IMS UI
  `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- 예약 생성 flow
  `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- Supabase repository
  `lib/data/repositories/supabase_ops_repository.dart`
- IMS 등록 정보 model
  `lib/data/models/external_reservation_link.dart`

### IMS 중간서버
- 서버 위치: `reservation_ai_parser/src/server.js`
- 현재 endpoint:
  - `GET /health`
  - `POST /parse-reservation`
  - `POST /ims/create-reservation`

### IMS Playwright / API
- 생성 스크립트: `workspace/tools/playwright/scripts/ims-reservation-draft.js`
- 삭제 스크립트: `workspace/tools/playwright/scripts/ims-reservation-cancel.js`
- 목록 export 스크립트: `workspace/tools/playwright/scripts/ims-reservations-export.js`
- 삭제 API:
  - `POST https://api.rencar.co.kr/v2/company-car-schedules/delete`
  - body: `{ ids: [scheduleId] }`
- 상세 API:
  - `GET https://api.rencar.co.kr/v2/company-car-schedules/{schedule_id}`

---

## IMS 등록 정보 저장 방식

테이블:
`rc00_ops_external_reservation_links`

주요 컬럼:
- `reservation_id`: OPS 예약 문자열 ID
- `reservation_ref_id`: OPS 예약 uuid FK
- `provider`: `ims`
- `external_reservation_id`: IMS `schedule_id`
- `external_detail_id`: IMS export `detail_id`
- `external_status`: `linked`, `failed`, `deleted`, `unlinked`
- `link_key`: `OPS:{reservation_id}`
- `last_payload_json`: IMS 생성/삭제/가져오기 요청 payload
- `last_result_json`: IMS 생성/삭제/조회 결과
- `linked_at`: IMS 등록 성공 시각
- `last_checked_at`: 마지막 등록/조회/검증 시각. 실시간 생존 보장 아님
- `deleted_at`: 예약취소/삭제 flow에서 IMS 삭제 성공 시각
- `error_text`: 마지막 실패 메시지

상태 의미:
- `linked`: IMS `schedule_id` 확보 완료. 화면에서는 `IMS등록됨`
- `failed`: IMS 생성 또는 id 확보 실패. 화면에서는 `등록실패`
- `deleted`: 예약취소/삭제 flow에서 IMS 삭제 완료
- `unlinked`: IMS 예약은 유지하고 OPS 등록 정보만 해제

원칙:
- 등록 정보 row는 이력이다.
- IMS 삭제/등록해제 후에도 가능하면 row를 삭제하지 않는다.
- 화면에서는 사용자에게 DB 내부 용어 `linked` 대신 `IMS등록됨`을 보여준다.

---

## Phase 0 테스트 기준 잠금

테스트 일시: 2026-05-15 KST

테스트 payload:
```json
{
  "rentalAt": "2026-12-01 10:00",
  "returnAt": "2026-12-02 10:00",
  "carNumber": "101허4014",
  "totalFee": "100000",
  "customerName": "IMS테스트",
  "customerPhone": "01012345678",
  "address": "IMS 테스트 주소",
  "useDelivery": true,
  "memo": "OPS:PHASE0-TEST-20260515-1631 | 테스트생성삭제 | 삭제예정"
}
```

생성 결과:
- IMS 생성: `SUCCESS`
- 생성 직후 목록 조회로 1건 매칭
- `schedule_id`: `4186133`
- `detail_id`: `204161`
- 차량번호: `101허4014`
- 고객명: `IMS테스트`
- 연락처: `01012345678`
- 배차: `2026-12-01 10:00:00`
- 반납: `2026-12-02 10:00:00`

삭제 결과:
- 삭제 API 기준 ID는 `schedule_id`
- `IMS_CANCEL_DELETE=true`
- 삭제 결과: `SUCCESS`
- 삭제 후 동일 기간 목록 재조회 결과 0건

중요 결론:
- IMS 생성 응답만으로는 `schedule_id`를 직접 받지 못한다.
- 생성 성공 후 목록 재조회/검색으로 `schedule_id`를 확보해야 한다.
- `memo`/`OPS:`만으로 재조회하는 전략은 위험하다.
- 생성 직후 id 확보는 복합키 기준으로 한다.
  - 차량번호
  - 고객명
  - 고객 연락처
  - 배차일시
  - 반납일시
  - 가능하면 배차지

---

## 구현 Phase

### Phase 3-B. 상세 UI 용어 보정 / 수동 연결 제거
현재 진행 중.

작업:
- 예약 상세 기능 카드에서 기존 수동 연결 버튼 제거
- 등록 상태 버튼 문구를 `IMS등록됨`으로 정리
- 정보 섹션 제목을 `IMS 등록 정보`로 정리
- 해제 버튼 문구를 `등록해제`로 정리
- 안내 문구에서 수동 연동 설명 제거
- current 문서 재정리

종료 조건:
- 화면에 수동 IMS 연결 버튼 없음
- 미등록 상태에서 IMS 액션은 `IMS추가` 하나뿐임
- 등록 상태에서 `IMS등록됨` + `등록해제`만 보임
- `flutter analyze` 통과
- 커밋 완료

### Phase 4. 예약 생성 시 IMS 등록 정보 저장
작업:
- 차량상세 예약생성 + `IMS에도 예약생성`
- 상단 `+` 예약추가 + `IMS에도 예약생성`
- IMS 성공 시 IMS 등록 정보 row 저장
- IMS 실패/id 확보 실패 시 등록 정보 `failed` 또는 action log 기록

종료 조건:
- 신규 OPS 예약도 IMS 등록 상태가 예약 상세에 바로 반영
- IMS 생성 실패 시 사용자가 실패 사유를 볼 수 있음

### Phase 5. 예약취소/삭제 + IMS 삭제 옵션
작업:
- 예약 상세 `예약취소` 또는 삭제 기능 추가
- 확인창에 `IMS 예약도 같이 삭제` 체크 추가
- 예약취소/삭제 flow 전용 중간서버 `/ims/delete-reservation` 추가
- IMS 등록 정보의 `schedule_id`로 IMS 삭제
- IMS 삭제 성공 시 `external_status='deleted'`
- IMS 삭제 실패 시 내부 예약취소/삭제 유지 + 실패 기록
- 체크하지 않으면 IMS 예약은 유지하고 등록 정보만 `unlinked`

종료 조건:
- 예약취소/삭제와 IMS 삭제 동시 실행 가능
- 실패 시 사용자가 상태를 알 수 있음
- 일반 상세 화면에서는 IMS 삭제 불가

### Phase 6. IMS에서 가져오기
작업:
- 중간서버 `/ims/list-reservations` 추가
- 앱 UI: 예약생성 다이얼로그에서 `IMS에서 가져오기`
- IMS 예약 선택 → 예약생성 폼 프리필
- 사용자 확인 후 내부 예약 + 일정 + IMS 등록 정보 생성

종료 조건:
- IMS 예약 1건을 기준으로 새 OPS 예약 생성 가능
- 이미 IMS 등록 정보가 있는 IMS 예약은 중복 생성 방지

### Phase 7. 검증/릴리즈
작업:
- unit test: IMS payload / IMS 등록 정보 mapper
- parser server check
- IMS dry-run
- `flutter analyze`
- APK build/upload

종료 조건:
- 다음 build 업로드
