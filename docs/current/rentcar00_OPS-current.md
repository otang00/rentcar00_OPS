# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **현재 실행 문서**다.
현재 실제로 실행 중인 작업 1건만 남긴다.
완료 이력은 `docs/completed/rentcar00_OPS-completed.md` 또는 `docs/past/`에서만 본다.

## 현재 실행 작업
- **IMS 예약 연동 / 예약취소 연계 / IMS 예약 가져오기 구현 준비**

## 목적
예약 원장과 IMS 예약을 서로 식별 가능한 값으로 연결한다.
이 연결을 기준으로 아래 기능을 추가한다.

1. 내부 예약 → IMS 예약추가 시 연동 식별자 저장
2. 내부 예약 취소 시 확인창에서 IMS 삭제 여부를 함께 선택 가능하게 함
3. 예약 상세의 미연동 상태에서는 `IMS추가`와 `IMS연동`을 제공하고, 연동 상태에서는 `IMS연동됨`과 `연동해제`만 제공
4. IMS 예약 목록을 불러와 내부 예약판 예약으로 넣을 수 있게 함

---

## 현재 확인된 구조

### 앱 코드
- IMS payload builder:
  - `lib/features/reservations/detail/data/ims_reservation_payload.dart`
- IMS client:
  - `lib/features/reservations/detail/data/ims_reservation_client.dart`
- 예약 상세 IMS 액션:
  - `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- 예약 생성/전역 예약추가 flow:
  - `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- 예약 저장 repository:
  - `lib/data/repositories/supabase_ops_repository.dart`

### IMS 중간서버
- 서버 위치:
  - `reservation_ai_parser/src/server.js`
- 현재 endpoint:
  - `GET /health`
  - `POST /parse-reservation`
  - `POST /ims/create-reservation`
- 현재 IMS 생성 응답은 `SUCCESS/DRY_RUN` 중심이며 내부 예약에 저장할 IMS id를 반환하지 않는다.

### IMS Playwright / API
- 생성 스크립트:
  - `workspace/tools/playwright/scripts/ims-reservation-draft.js`
- 삭제 스크립트:
  - `workspace/tools/playwright/scripts/ims-reservation-cancel.js`
- 목록 export 스크립트:
  - `workspace/tools/playwright/scripts/ims-reservations-export.js`
- 삭제 API는 `schedule_id` 기반:
  - `POST https://api.rencar.co.kr/v2/company-car-schedules/delete`
  - body: `{ ids: [scheduleId] }`
- 목록 export에는 `schedule_id`, `detail_id`, 차량번호, 고객명, 연락처, 시작/종료일, 배차지 등이 나온다.
- 상세 API:
  - `GET https://api.rencar.co.kr/v2/company-car-schedules/{schedule_id}`
  - `schedule.id`가 삭제 API에 쓰는 `schedule_id`와 같다.
  - `schedule.reservation.id`는 export의 `detail_id`와 다를 수 있으므로 별도 보조값으로만 취급한다.

### DB 현재 상태
- `rc00_ops_reservations`에는 IMS 연동 전용 컬럼이 없다.
- `meta_json`은 있으나 장기 운영 기준으로는 별도 IMS 예약 바인딩 테이블이 안전하다.
- `rc00_ops_action_logs`, `rc00_ops_outbox`는 존재하지만 현재 앱에서는 대부분 preview/read-only 수준이다.

---

## Phase 0 실제 테스트 결과 잠금

### 테스트 일시
- 2026-05-15 KST

### 테스트 차량
- 입력 지시값: `4014`
- 내부 DB 확인 결과 전체 차량번호: `101허4014`
- 차량명: `GV80`
- 당시 내부 상태: `대기`, 주차지 `수푸레B1`

### 생성 요청 payload — 값/형식 잠금
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

검증:
- `rentalAt`, `returnAt`: `YYYY-MM-DD HH:mm`
- `carNumber`: 전체 차량번호 사용, 부분번호 금지
- `totalFee`: 숫자 문자열, 0보다 큼
- `customerPhone`: 숫자 11자리
- `address`: 문자열
- `useDelivery`: boolean
- `memo`: 120자 이하, `OPS:` 포함

### 생성 결과
- 실행: `IMS_SAVE=true`
- IMS 생성 결과: `SUCCESS`
- 생성 직후 IMS 목록 조회 결과 정확히 1건 매칭

생성된 IMS 값:
- `schedule_id`: `4186133`
- `detail_id` from export: `204161`
- `status`: `booking`
- `car_number`: `101허4014`
- `car_name`: `2020 GV80 3.5 가솔린 화이트`
- `customer_name`: `IMS테스트`
- `customer_contact`: `01012345678`
- `start_at`: `2026-12-01 10:00:00`
- `end_at`: `2026-12-02 10:00:00`
- `pickup_address`: `IMS 테스트 주소`
- `dropoff_address`: 빈 값
- `cost` from detail API: `100000`
- `rental_type`: `daily`

### 중요한 발견
- 생성 스크립트의 저장 응답은 `SUCCESS`만 반환하고 `schedule_id`를 직접 반환하지 않았다.
- 생성 후 IMS 목록 조회로 방금 생성한 건의 `schedule_id`를 확보할 수 있었다.
- IMS 상세 API의 `schedule.memo`는 `null`로 반환되었다.
- 즉, 현재 확인 범위에서는 `memo`/`OPS:`만으로 IMS 예약을 다시 찾는 전략은 위험하다.
- 생성 직후 id 확보는 아래 복합키로 찾는 방식이 안전하다.
  - `carNumber`
  - `customerName`
  - `customerPhone`
  - `rentalAt`
  - `returnAt`
  - 가능하면 `pickupAddress`
- `OPS:`는 내부 인식자/사람이 보는 보조값으로 유지하되, 조회 primary key로 의존하지 않는다.

### 삭제 전 잠금 검증
삭제 전 아래 값이 모두 일치할 때만 삭제했다.
- `schedule_id = 4186133`
- `car_number = 101허4014`
- `customer_name = IMS테스트`
- `customer_contact = 01012345678`
- `start_at = 2026-12-01 10:00:00`
- `end_at = 2026-12-02 10:00:00`
- `pickup_address = IMS 테스트 주소`
- `status = booking`

### 삭제 결과
- 실행: `IMS_CANCEL_DELETE=true`
- 삭제 결과: `SUCCESS`
- 삭제 대상 `scheduleId`: `4186133`
- 삭제 후 동일 기간 IMS 목록 재조회 결과:
  - total `0`
  - remainingMatches `0`

### Phase 0 결론
- 삭제 기준 id는 `schedule_id`로 확정한다.
- IMS 예약 바인딩 테이블의 `external_reservation_id`에는 IMS `schedule_id`를 저장한다.
- IMS 예약 바인딩 테이블의 `external_detail_id`에는 export의 `detail_id`를 보조값으로 저장한다.
- 생성 API 응답만으로는 id 확보가 불가능하다.
- 생성 성공 후 목록 재조회/검색으로 id를 확보해야 한다.
- id 확보 실패 시 정책은 **내부 예약/IMS 생성은 유지하고 `IMS연동실패`로 기록**하는 것이 안전하다.
  - 이유: IMS 실제 생성은 성공했는데 link만 실패한 상황을 전체 실패로 처리하면 실제 IMS 예약이 남아 있는 상태를 사용자가 놓칠 수 있다.

---

## 최종 설계 잠금

## 명칭 잠금
- 기능명: **IMS Reservation Binding**
- 한글명: **IMS 예약 바인딩**
- 의미: OPS 예약 1건과 IMS 예약 1건의 1:1 연결
- 제외: IMS 예약 목록 동기화, IMS 예약 가져오기, IMS 예약 생성 자체, 차량 가능/불가능 검색 기능
- 코드 함수명에는 `Binding`을 사용하고, 화면/문서 설명에는 `IMS 예약 바인딩`을 사용한다.

### 1. 내부 ↔ IMS 연결 키
- 내부 기준 키: `rc00_ops_reservations.reservation_id`
- IMS 기준 키: `schedule_id`
- 보조 키: export의 `detail_id`
- IMS memo에는 내부 인식자를 포함하되, 조회 primary key로 의존하지 않는다.
  - 형식: `OPS:{reservation_id}`
  - 예: `OPS:R250515ABC123`
- 기존 memo 요소는 유지한다.
  - `외부예약:{reservationNumber}`
  - `생년:{customerBirthDate}`

### 2. link 저장 방식 최종안
별도 테이블 방식으로 간다.

이유:
- `meta_json`에 넣으면 조회/버튼 노출/중복 방지/삭제 상태 관리가 지저분해진다.
- IMS는 외부 시스템이므로 내부 예약 본문과 연동 상태를 분리하는 것이 안전하다.
- 삭제 후에도 이력 보존이 필요하다.

테이블명:
`rc00_ops_external_reservation_links`

필드 초안:
- `id uuid primary key`
- `reservation_id text not null`
- `reservation_ref_id uuid null`
- `provider text not null default 'ims'`
- `external_reservation_id text null` — IMS `schedule_id`
- `external_detail_id text null` — IMS export `detail_id`
- `external_status text not null default 'linked'`
- `link_key text not null` — `OPS:{reservation_id}`
- `last_payload_json jsonb null`
- `last_result_json jsonb null`
- `linked_at timestamptz null`
- `last_checked_at timestamptz null`
- `deleted_at timestamptz null`
- `error_text text null`
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

제약:
- `unique(provider, reservation_id)`
- `index(provider, external_reservation_id)`
- `index(link_key)`

원칙:
- IMS 삭제 후에도 row 삭제 금지.
- `external_status = deleted`, `deleted_at` 으로 흔적을 남긴다.

### 3. IMS memo 인식자 최종안
`OPS:{reservation_id}`를 포함한다.

단, Phase 0에서 IMS 상세 API의 memo가 `null`로 확인되었으므로:
- `OPS:`는 보조 식별자다.
- 생성 직후 id 확보는 복합키 조회로 한다.
- 나중에 IMS 메모 조회 endpoint가 안정적으로 확인되면 `OPS:` 검색을 보조 검증으로 추가한다.

### 4. Phase 1 DB IMS 예약 바인딩 테이블 확정 DDL
Phase 1에서 실제 생성할 테이블은 아래 DDL과 동일해야 한다.

```sql
create table if not exists public.rc00_ops_external_reservation_links (
  id uuid primary key default gen_random_uuid(),
  reservation_id text not null,
  reservation_ref_id uuid references public.rc00_ops_reservations(id) on delete cascade,
  provider text not null default 'ims',
  external_reservation_id text,
  external_detail_id text,
  external_status text not null default 'linked',
  link_key text not null,
  last_payload_json jsonb not null default '{}'::jsonb,
  last_result_json jsonb not null default '{}'::jsonb,
  linked_at timestamptz,
  last_checked_at timestamptz,
  deleted_at timestamptz,
  error_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rc00_ops_external_reservation_links_provider_check
    check (provider in ('ims')),
  constraint rc00_ops_external_reservation_links_status_check
    check (external_status in ('linked', 'failed', 'deleted', 'unlinked')),
  constraint rc00_ops_external_reservation_links_link_key_check
    check (length(trim(link_key)) > 0),
  constraint rc00_ops_external_reservation_links_provider_reservation_unique
    unique (provider, reservation_id)
);

create index if not exists idx_rc00_ops_external_links_reservation_id
  on public.rc00_ops_external_reservation_links (reservation_id);

create index if not exists idx_rc00_ops_external_links_reservation_ref_id
  on public.rc00_ops_external_reservation_links (reservation_ref_id);

create index if not exists idx_rc00_ops_external_links_provider_external_id
  on public.rc00_ops_external_reservation_links (provider, external_reservation_id);

create index if not exists idx_rc00_ops_external_links_link_key
  on public.rc00_ops_external_reservation_links (link_key);

create index if not exists idx_rc00_ops_external_links_status
  on public.rc00_ops_external_reservation_links (provider, external_status);

alter table public.rc00_ops_external_reservation_links enable row level security;

drop policy if exists rc00_ops_external_reservation_links_authenticated_all
  on public.rc00_ops_external_reservation_links;
create policy rc00_ops_external_reservation_links_authenticated_all
  on public.rc00_ops_external_reservation_links
  for all
  to authenticated
  using (true)
  with check (true);
```

컬럼 의미:
- `reservation_id`: 내부 예약 문자열 ID. 앱 조회/표시의 1차 내부 키.
- `reservation_ref_id`: `rc00_ops_reservations.id` uuid FK. 내부 예약 삭제 시 link도 cascade 삭제 가능하지만, 운영 삭제보다는 상태 변경을 우선한다.
- `provider`: 외부 시스템 구분. 이번 scope는 `ims`만 허용한다.
- `external_reservation_id`: IMS `schedule_id`. 삭제 API의 primary key.
- `external_detail_id`: IMS export의 `detail_id`. 조회/분석 보조값.
- `external_status`: `linked`, `failed`, `deleted`, `unlinked` 중 하나.
- `link_key`: `OPS:{reservation_id}`.
- `last_payload_json`: IMS 생성/삭제/가져오기 요청 payload 보관.
- `last_result_json`: IMS 생성/삭제/조회 결과 보관.
- `linked_at`: IMS 연동 성공 시각.
- `last_checked_at`: IMS 조회/검증 시각.
- `deleted_at`: IMS 삭제 성공 시각.
- `error_text`: 마지막 실패 메시지.
- `created_at`, `updated_at`: IMS 예약 바인딩 row 생성/수정 시각.

상태 정책:
- `linked`: IMS `schedule_id` 확보 완료, active link.
- `failed`: IMS 생성 또는 id 확보 실패. 재추가 가능.
- `deleted`: 예약 삭제/취소 flow에서 IMS 삭제 완료. 재연동 가능.
- `unlinked`: IMS 예약은 유지하고 OPS-IMS 바인딩만 해제. 재연동 가능.

RLS 정책:
- 기존 운영 테이블 정책과 동일하게 authenticated all로 시작한다.
- 이 앱은 직원 로그인 후 내부 운영용으로만 쓰는 1차 구조이므로, 권한 세분화는 후속 phase로 둔다.

Phase 1 검증 기준:
- table 존재 확인
- column/type/check/index/policy 존재 확인
- 테스트 row insert/select/update/delete 가능 확인
- 테스트 row는 검증 후 삭제
```


---

## UI 잠금

### A. 예약 상세 > 기능 카드
최종:
1. IMS 미연동 예약
   - 전화
   - 문자
   - `IMS추가`
   - `IMS연동`
2. IMS 연동 예약
   - 전화
   - 문자
   - `IMS연동됨` 비활성 버튼 표시

정책:
- `IMS추가`: OPS 예약 정보를 기준으로 IMS에 새 예약을 생성한 뒤 IMS 예약 바인딩을 저장한다.
- `IMS연동`: 이미 IMS에 존재하는 예약을 선택해 현재 OPS 예약과 IMS 예약 바인딩을 저장한다.
- `IMS재추가` 버튼은 만들지 않는다. 실패/해제 상태는 미연동 상태로 보고 `IMS추가` 또는 `IMS연동` 중 선택하게 한다.

### B. 예약 상세 > IMS 연동 정보 섹션
항상 표시한다.

표시:
- 연동상태: 미연동 / 연동됨 / 해제됨 / 실패
- IMS ID: `schedule_id`
- detail ID: export `detail_id`
- 연동키: `OPS:{reservation_id}`
- 마지막 확인시각
- 오류 메시지
- `연동해제` 버튼

`연동해제` 위치:
- 기능 카드가 아니라 `IMS 연동 정보` 섹션 안에 둔다.
- 이 버튼은 IMS 예약 자체를 삭제하지 않는다.
- 현재 OPS 예약과 IMS 예약의 바인딩만 해제한다.
- 해제 후 해당 OPS 예약은 미연동 상태가 되며 `IMS추가` 또는 `IMS연동`을 다시 선택할 수 있다.

### C. 예약 취소 기능
예약 상세에 `예약취소` 기능을 추가한다.

동작:
1. 사용자가 예약취소 클릭
2. 확인창 표시
3. IMS 예약 바인딩이 active면 확인창 안에 `IMS 예약도 같이 삭제` 체크박스 표시
4. 체크 후 확인 시:
   - 내부 원장 상태를 `예약취소`로 변경
   - IMS 삭제도 함께 시도
5. IMS 삭제 실패 시:
   - 내부 예약취소는 유지
   - IMS 삭제 실패 상태와 오류를 기록
   - 사용자에게 실패 안내

정책:
- IMS 삭제 실패가 내부 예약취소를 막지 않는다.

### D. 예약판 상단 `+` / 예약생성 UI
현재 상단 `+` 예약생성은 유지한다.

변경:
- 예약생성 다이얼로그 상단에서 기존 `AI파서` 버튼 옆에 `IMS 연동` 버튼/토글을 배치한다.
- 기존 IMS 체크 개념은 유지하되, UI 문구를 `IMS 연동`으로 정리한다.
- 별도의 첫 선택 화면은 만들지 않는다.

### E. IMS 예약 가져오기 UI
초기 구현 위치:
- 예약생성 다이얼로그 내부 또는 상단 버튼 영역에 `IMS에서 가져오기` 버튼 추가 후보
- `AI파서` 옆 버튼군에 배치하는 방향 우선 검토

가져오기 동작:
- IMS 예약 목록 조회
- 선택한 IMS 예약을 예약생성 폼에 프리필
- 사용자가 부족한 값 확인/수정 후 저장
- 저장 시 내부 예약 + 일정 + IMS 예약 바인딩 생성

정책:
- IMS에서 가져온 예약은 바로 저장하지 않는다.
- 사용자 확인 후 저장한다.

### F. 수동 연결
- 기존 IMS에 수동 등록된 예약을 내부 예약과 수동 연결하는 기능은 이번 scope 제외.
- 운영해보고 필요하면 후속 검토.

---

## 구현 Phase 잠금

### Phase 1. DB IMS 예약 바인딩 테이블
작업:
- migration 작성
- RLS policy 추가
- repository link 조회/저장/상태변경 함수 추가

종료 조건:
- IMS 예약 바인딩 row insert/select/update 검증
- 기존 예약 데이터 영향 없음

### Phase 2. IMS 생성 응답/검색 확장
작업:
- IMS create payload memo에 `OPS:{reservation_id}` 포함
- 중간서버 `/ims/create-reservation`가 저장 성공 후 목록 재조회로 `schedule_id/detail_id` 확보
- 복합키 매칭 기준:
  - 차량번호
  - 고객명
  - 고객 연락처
  - 배차일시
  - 반납일시
  - 배차지
- 앱 client result model 확장

구현 상태:
- `ImsReservationPayload`에 `reservationId` 추가
- `buildImsReservationMemo()`가 `OPS:{reservation_id}`를 memo 앞에 포함
- 서버 `normalizeImsReservationPayload()`도 구버전 호출 대비 `reservationId`가 있으면 memo에 `OPS:`를 보강
- `/ims/create-reservation` 성공 응답을 IMS 예약 바인딩 저장 가능한 형태로 확장
  - `externalStatus`
  - `externalReservationId` = IMS `schedule_id`
  - `externalDetailId` = IMS export `detail_id`
  - `linkKey` = `OPS:{reservation_id}`
  - `errorText`
  - `matchedReservation`
- IMS 생성 `SUCCESS` 이후에만 export 조회로 id 확보 시도
- `DRY_RUN`은 실제 IMS 예약이 생성되지 않으므로 id 조회를 하지 않음
- id 확보 실패 시 `externalStatus='failed'`, `errorText='IMS id 확보 실패'`로 반환

종료 조건:
- IMS 생성 성공 결과가 앱에서 IMS 예약 바인딩 저장 가능한 형태로 돌아옴
- id 확보 실패 시 `IMS연동실패`로 기록 가능

검증:
- `npm --prefix reservation_ai_parser run check`
- `flutter test test/ims_reservation_payload_test.dart`
- `flutter analyze`

### Phase 3-A. 예약 상세 IMS 연동 상태 UI
작업:
- 예약 상세 provider에서 IMS 예약 바인딩 조회
- 미연동이면 `IMS추가` + `IMS연동`
- 연동됨이면 `IMS연동됨` 비활성 버튼
- 실패/해제 상태는 미연동으로 취급하고 `IMS추가` + `IMS연동` 표시
- `IMS 연동 정보` 섹션 항상 표시
- 연동됨 상태에서는 `연동해제`만 제공하고 IMS 예약 삭제는 제공하지 않음
- `external_status='unlinked'` 허용 migration 추가

구현 상태:
- 예약 상세 기능 카드에서 active binding 여부에 따라 `IMS추가/IMS연동` 또는 `IMS연동됨` 표시
- `IMS 연동 정보` 섹션 상시 표시
- active binding이면 IMS ID/detail ID/연동키/마지막 확인시각 표시
- `연동해제` 버튼은 IMS 예약을 삭제하지 않고 `external_status='unlinked'`로 변경
- `IMS연동` 버튼은 Phase 3-B 목록 선택 전까지 안내 메시지만 표시

종료 조건:
- 중복 IMS 추가 방지
- 연동 상태가 눈에 보임
- 일반 상세 화면에는 IMS 예약 삭제 버튼 없음
- `flutter analyze` 통과

### Phase 3-B. IMS연동 선택 바인딩
작업:
- 기능명은 화면에서 `IMS연동`으로 표시
- 이미 IMS에 존재하는 예약 목록을 조회
- 현재 OPS 예약과 같은 차량번호/고객명/전화번호/배차일시/반납일시/배차지를 기준으로 후보 표시
- 후보 선택 후 비교 확인창 표시
- 사용자가 확정하면 IMS 예약 바인딩 row 저장
- IMS 예약 자체는 생성/수정/삭제하지 않음

종료 조건:
- 미연동 OPS 예약에서 기존 IMS 예약을 선택해 바인딩 가능
- 잘못된 IMS 예약을 붙이지 않도록 비교 정보와 경고가 보임

### Phase 4. 예약 생성 시 IMS 연동 저장
작업:
- 차량상세 예약생성 + IMS 연동
- 상단 `+` 예약추가 + IMS 연동
- IMS 성공 시 IMS 예약 바인딩 row 저장
- IMS 실패/id 확보 실패 시 IMS 예약 바인딩 failed 또는 action log 기록

종료 조건:
- 신규 생성 예약도 IMS 연동 상태가 예약 상세에 바로 반영

### Phase 5. 예약취소 + IMS 삭제 연계
작업:
- 예약 상세 `예약취소` 기능 추가
- 확인창에 IMS 같이 삭제 체크 추가
- 예약취소 flow 전용 중간서버 `/ims/delete-reservation` 추가
- IMS 예약 바인딩의 `schedule_id`로 삭제
- IMS 삭제 성공 시 IMS 예약 바인딩 `deleted_at`, `external_status=deleted`
- IMS 삭제 실패 시 내부 예약취소 유지 + 실패 기록

종료 조건:
- 예약 취소와 IMS 삭제 동시 실행 가능
- 실패 시 사용자가 상태를 알 수 있음

### Phase 6. IMS에서 가져오기
작업:
- 중간서버 `/ims/list-reservations` 추가
- 앱 UI: 예약생성 다이얼로그에서 `IMS에서 가져오기`
- IMS 예약 선택 → 예약생성 폼 프리필
- 저장 시 내부 예약 + 일정 + IMS 예약 바인딩 생성

종료 조건:
- IMS 예약 1건을 내부 예약판 예약으로 안전하게 생성
- 이미 IMS 예약 바인딩된 IMS 예약은 중복 생성 방지

### Phase 7. 검증/릴리즈
작업:
- unit test: IMS payload / IMS 예약 바인딩 mapper
- parser server `--check`
- IMS dry-run
- 앱 `flutter analyze`
- APK build/upload

종료 조건:
- b28 또는 다음 build 업로드

---

## 승인 잠금
- 이 문서는 UI/설계 잠금 문서다.
- 다음 phase 코드, DB migration, IMS 서버 endpoint, Playwright 스크립트 수정은 사장님 승인 전 실행하지 않는다.
- IMS 실제 저장/삭제 테스트는 별도 명시 승인 전 실행한다.
