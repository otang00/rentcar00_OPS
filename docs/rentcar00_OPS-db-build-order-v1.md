# rentcar00_OPS DB Build Order v1

## 1. 문서 목적
이 문서는 `rentcar00_OPS`의 Supabase DB를 어떤 구조로 만들고, 어떤 순서로 생성할지 고정하는 실행 기준 문서다.

이 문서에서 잠그는 것:
- 테이블 계층
- 테이블 생성 순서
- 초기 컬럼 우선순위
- Google Sheets import 흐름
- projection / status 갱신 순서

---

## 2. 핵심 원칙
- 앱은 Google Sheets를 직접 읽지 않는다.
- Google Sheets는 원본 source다.
- Supabase는 앱의 조회/처리 source of truth 다.
- 앱은 Supabase만 조회한다.
- 초기 단계는 read-only import 만 허용한다.
- 실제 Sheets write 는 마지막 phase 전까지 금지한다.

한 줄 구조:
`Google Sheets -> raw tables -> projection tables -> state tables -> app`

---

## 3. 테이블 계층

### 3-1. raw 원본 계층
1. `rc00_ops_sheet_sync_runs`
2. `rc00_ops_sheet_reservations_raw`
3. `rc00_ops_sheet_schedules_raw`

역할:
- 시트 원문 보존
- sync 단위 추적
- import 실패 분석
- orphan 일정 보존

### 3-2. projection 원장 계층
4. `rc00_ops_reservations`

역할:
- 앱이 보는 예약 1건 기준 원장
- 고객/차량/주소/일정 핵심 필드 정규화

### 3-3. 현재 업무 상태 계층
5. `rc00_ops_reservation_states`

역할:
- 예약 1건당 현재 업무 상태 1행
- 탭/상태/check/warning 관리

### 3-4. 실행 기록 계층
6. `rc00_ops_action_logs`
7. `rc00_ops_outbox`

역할:
- 버튼 실행 기록
- 나중에 외부 반영할 요청 기록

---

## 4. 생성 순서

### Phase A. 기반 테이블
먼저 만든다.

#### A-1. `rc00_ops_sheet_sync_runs`
이유:
- 모든 import 배치가 어떤 sync run 에 속하는지 먼저 기록해야 한다.
- 이후 raw 테이블이 `sync_run_id` 를 참조할 수 있다.

최소 컬럼:
- `id`
- `source_type` (`google_sheets`)
- `status`
- `started_at`
- `finished_at`
- `meta_json`
- `error_text`

#### A-2. `rc00_ops_sheet_reservations_raw`
이유:
- 예약 탭 원문이 앱 데이터의 첫 기준이다.

최소 컬럼:
- `id`
- `sync_run_id`
- `sheet_row_number`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `start_at_raw`
- `end_at_raw`
- `location_raw`
- `customer_name`
- `customer_phone`
- `customer_birth_date_raw`
- `referral_source`
- `payment_amount_raw`
- `status_raw`
- `payload_json`
- `imported_at`

권장 unique:
- `(sync_run_id, sheet_row_number)`

인덱스:
- `reservation_id`
- `reservation_number`
- `car_number`

#### A-3. `rc00_ops_sheet_schedules_raw`
이유:
- 일정 원문은 예약 원장보다 연결 품질이 낮아도 raw 보존이 먼저 필요하다.

최소 컬럼:
- `id`
- `sync_run_id`
- `sheet_row_number`
- `schedule_id`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `schedule_type_raw`
- `schedule_at_raw`
- `location_raw`
- `detail_text`
- `partial_return_raw`
- `schedule_done_raw`
- `payload_json`
- `imported_at`

권장 unique:
- `(sync_run_id, sheet_row_number)`

인덱스:
- `schedule_id`
- `reservation_id`
- `reservation_number`
- `car_number`

---

### Phase B. projection 원장

#### B-1. `rc00_ops_reservations`
이유:
- 앱은 raw 를 직접 읽지 않고 정규화된 예약 원장을 읽어야 한다.

최소 컬럼:
- `id`
- `reservation_id`
- `reservation_number`
- `car_id` nullable
- `car_number`
- `car_name`
- `customer_name`
- `customer_phone`
- `start_at`
- `end_at`
- `pickup_location`
- `dropoff_location` nullable
- `status_raw`
- `source_sync_run_id`
- `source_reservation_raw_id`
- `primary_schedule_raw_id` nullable
- `last_synced_at`
- `note_text` nullable
- `meta_json`

권장 unique:
- `reservation_id`

보조 인덱스:
- `reservation_number`
- `car_number`
- `start_at`
- `end_at`

정규화 규칙:
- 예약 원장은 `예약` 탭 기준으로만 생성
- 일정만 있고 예약 원문이 없으면 원장 생성 금지
- 위치는 초기엔 `pickup_location` 중심으로 저장
- `dropoff_location` 은 나중에 분리 가능

---

### Phase C. 현재 상태

#### C-1. `rc00_ops_reservation_states`
이유:
- 탭 계산과 업무 상태를 예약 원장과 분리해야 충돌이 줄어든다.

최소 컬럼:
- `id`
- `reservation_id`
- `reservation_ref_id`
- `tab_key`
- `status_key`
- `auto_tab_key`
- `auto_status_key`
- `manual_override` boolean
- `needs_attention` boolean
- `warning_level`
- `check_payload_json`
- `last_action_at` nullable
- `completed_at` nullable
- `memo_text` nullable
- `updated_at`
- `created_at`

권장 unique:
- `reservation_id`

핵심 원칙:
- 앱의 탭 source of truth 는 이 테이블
- 자동 계산값과 수동 override 값을 분리 저장
- 초기 check 값은 전부 `check_payload_json` 에 저장

---

### Phase D. 기록/외부반영 준비

#### D-1. `rc00_ops_action_logs`
최소 컬럼:
- `id`
- `reservation_id`
- `reservation_ref_id`
- `action_key`
- `before_tab_key`
- `after_tab_key`
- `before_status_key`
- `after_status_key`
- `actor_id` nullable
- `actor_name` nullable
- `message_text` nullable
- `result_status`
- `error_text` nullable
- `meta_json`
- `created_at`

인덱스:
- `reservation_id`
- `action_key`
- `created_at`

#### D-2. `rc00_ops_outbox`
최소 컬럼:
- `id`
- `reservation_id`
- `reservation_ref_id`
- `action_log_id`
- `target_type`
- `target_ref`
- `payload_json`
- `delivery_status`
- `attempt_count`
- `last_attempt_at` nullable
- `delivered_at` nullable
- `error_text` nullable
- `created_at`

원칙:
- MVP 에서는 실제 apply 말고 dry-run 생성까지만
- 대상 액션은 4개만 시작
  - `request_delivery`
  - `change_end_at`
  - `change_dropoff_address`
  - `complete_return`

---

## 5. Google Sheets import 흐름

### Step 1. sync run 생성
- `rc00_ops_sheet_sync_runs` 에 1행 생성
- 상태: `running`

### Step 2. 예약 탭 raw 적재
- `예약` 시트 행을 그대로 읽어 `rc00_ops_sheet_reservations_raw` 적재
- parsing 실패가 있어도 raw payload 는 보존

### Step 3. 일정 탭 raw 적재
- `일정` 시트 행을 그대로 읽어 `rc00_ops_sheet_schedules_raw` 적재
- 연결 실패 행도 버리지 않음

### Step 4. 예약 projection 생성/갱신
- `reservation_id` 기준 upsert
- 없으면 `reservation_number` 는 보조 확인용만 사용
- 원장 생성은 `예약` raw 가 있을 때만

### Step 5. 일정 연결
우선순위:
1. `reservation_id`
2. `reservation_number` unique
3. orphan 유지

원칙:
- orphan 일정은 raw 에 남긴다
- 잘못된 추정 연결은 하지 않는다

### Step 6. 상태 계산
입력값:
- `start_at`
- `end_at`
- raw 상태
- schedule 연결 여부
- 현재 check 값
- 수동 override 값

출력값:
- `auto_tab_key`
- `auto_status_key`
- `tab_key`
- `status_key`
- `needs_attention`
- `warning_level`

### Step 7. sync run 종료
- 성공 시 `success`
- 부분실패면 `partial_success`
- 치명실패면 `failed`

---

## 6. 초기 생성 순서 잠금
실제 생성은 아래 순서로 고정한다.

1. `rc00_ops_sheet_sync_runs`
2. `rc00_ops_sheet_reservations_raw`
3. `rc00_ops_sheet_schedules_raw`
4. `rc00_ops_reservations`
5. `rc00_ops_reservation_states`
6. `rc00_ops_action_logs`
7. `rc00_ops_outbox`

이 순서를 먼저 지키는 이유:
- raw 가 먼저 있어야 projection 검증이 가능하다
- projection 이 있어야 state 를 계산할 수 있다
- state 가 있어야 action / outbox 가 의미를 가진다

---

## 7. 바로 다음 작업 순서
1. Flutter dotenv 연결
2. Supabase client 초기화
3. 위 7개 테이블 SQL 초안 작성
4. migration 디렉토리 생성
5. 테이블 생성 실행
6. mock repository -> Supabase repository 교체 준비
7. read-only importer 붙이기

---

## 8. 보류 사항
지금은 아직 하지 않는다.
- service_role 을 앱에 연결
- Google Sheets write
- AppSheet API 직접 호출
- orphan 일정 자동 추정 병합
- message template / external mappings 실제 운영 반영

---

## 9. 한 줄 결론
초기 DB는 **raw 3개 -> projection 1개 -> state 1개 -> log/outbox 2개** 순서로 만든다.
