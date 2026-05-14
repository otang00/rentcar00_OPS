# rentcar00_OPS 예약 레이어 데이터 설계 v1

## 1. 문서 목적
이 문서는 예약 레이어 작업에 필요한 데이터 기준 문서를 하나로 묶는다.

포함 범위:
- Google Sheets 원본 구조
- 중요 참고 경로
- import / normalization 기준
- Supabase 구조
- 테이블 생성 순서

이 문서는 예약 레이어 데이터 기준만 다룬다.
현황판 레이어 규칙은 별도 문서에서 본다.

## 2. 중요 참고 위치
### Google Sheets
- spreadsheet id: `1sEHaOI-zrLNzlGC8IdogQ3CidKuL4R_vFGGvFnGyGWk`
- spreadsheet title: `차량현황`
- 예약 레이어 원본 시트:
  - `예약`
  - `일정`

### Google service account JSON
- `/Users/otang_server/.openclaw/media/inbound/test001-39500280-8a165c8d3c50---fc41748b-2ac5-40fd-962e-2330fc79bd25.json`

원칙:
- secret 값 자체를 문서에 복사하지 않는다.
- 경로와 용도만 기록한다.

### env / Supabase
- 앱 공개 env: `projects/rentcar00_OPS/.env`
- 로컬 참고 env: `projects/rentcar00_OPS/.env.local`
- 예시 env: `projects/rentcar00_OPS/.env.example`
- Supabase config: `projects/rentcar00_OPS/supabase/config.toml`
- Supabase pooler URL fallback: `projects/rentcar00_OPS/supabase/.temp/pooler-url`
- Supabase project ref: `projects/rentcar00_OPS/supabase/.temp/project-ref`
- migration:
  - `projects/rentcar00_OPS/supabase/migrations/20260508154107_initial_rc00_ops_schema.sql`
  - `projects/rentcar00_OPS/supabase/migrations/20260509002000_simplify_reservation_states.sql`
  - `projects/rentcar00_OPS/supabase/migrations/20260510121500_add_sheet1_cars_table.sql`
  - `projects/rentcar00_OPS/supabase/migrations/20260511195000_split_raw_and_ops_tables.sql`

## 3. 원본 시트 구조
### 예약 시트 헤더
- `예약ID`
- `예약번호`
- `차량번호`
- `차종`
- `대여일`
- `반납일`
- `배반차위치`
- `임차인`
- `고객번호`
- `생년월일`
- `소개처`
- `결제금액`
- `예약상태`

### 일정 시트 헤더
- `일정번호`
- `예약번호`
- `차량번호`
- `Status`
- `Date`
- `차종`
- `위치`
- `상세정보`
- `가반납`
- `예약ID`
- `일정완료`

## 4. 원본 해석 기준
- 예약 원장 생성 기준은 `예약` 시트다.
- `일정` 시트는 연결 보강용이다.
- ops 연결 우선순위는 아래와 같다.
  1. `예약ID`
  2. `예약번호` unique
  3. 그 외는 orphan raw 유지
- 앱은 Google Sheets를 직접 읽지 않고 Supabase만 조회한다.

## 5. import 기준
### 입력값
- service account JSON 경로
- spreadsheet id
- 대상 시트명: `예약`, `일정`

### inspect 명령
```bash
dart run tool/inspect_google_sheets.dart <service-account.json> <spreadsheet-id> 예약 일정
```

### import 원칙
- 초기 단계는 read-only만 허용
- `예약` 시트는 header + blank row 제외 후 전행 적재
- `일정` 시트는 완전 blank row 제외 후 적재
- 원문 payload 는 전체 json 으로 보존
- parsing 실패가 있어도 payload 는 버리지 않음
- 원장 생성은 `예약` 탭 기준으로만 수행
- `일정` orphan 행은 raw 에 남긴다

### 확인된 첫 실행 기록
- 실행 일시: `2026-05-09`
- sync run id: `89fe1958-d25a-4b96-a100-b6bea28a93df`
- reservation raw count: `79`
- schedule raw count: `78`

## 6. normalization 기준
### reservation 원장
- 원장은 `예약` raw 기준으로만 생성
- `reservation_id` 를 primary upsert 키로 사용
- `pickup_location` 은 우선 `배반차위치` 원문을 그대로 저장
- `meta_json` 에 raw payload 원문 유지

### state 계산
- 원본 상태는 `status_raw` 로 유지
- 앱 탭 source of truth 는 `rc00_ops_reservation_states.tab_key`
- 탭 계산은 `status_raw + start_at + end_at` 기준을 우선한다

### 현재 잠긴 탭 규칙
- `예약상태='예약중'` + `start_at` 오늘 아님 → 예약중
- `예약상태='예약중'` + `start_at` 오늘 → 오늘배차
- `예약상태='배차중'` + `end_at` 오늘 아님 → 배차중
- `예약상태='배차중'` + `end_at` 오늘 → 반납일
- `예약상태='반납완료'` → 완료
- `예약상태='예약취소'` → 기본 탭 제외

### attention 기준
- 고객명/전화번호/위치 공란 여부 반영
- 1차는 최소 경고만 계산

### normalization 명령
```bash
dart run tool/normalize_raw_to_projection.dart <db-password>
```

주의:
- 스크립트 이름은 아직 `projection` 이지만 현재 의미는 raw → ops 변환이다.

## 7. Supabase 구조
한 줄 구조:
`Google Sheets -> raw tables -> ops tables -> state tables -> app`

### raw 원본 계층
1. `rc00_ops_import_runs`
2. `rc00_ops_cars_raw`
3. `rc00_ops_reservations_raw`
4. `rc00_ops_schedules_raw`

규칙:
- import 원본 보존 전용
- 앱 운영 write 금지

### ops 원장 계층
5. `rc00_ops_cars`
6. `rc00_ops_reservations`
7. `rc00_ops_schedules`

### 현재 업무 상태 계층
8. `rc00_ops_reservation_states`

### 실행 기록 계층
9. `rc00_ops_action_logs`
10. `rc00_ops_outbox`

## 8. 테이블 생성 순서
1. `rc00_ops_import_runs`
2. `rc00_ops_cars_raw`
3. `rc00_ops_reservations_raw`
4. `rc00_ops_schedules_raw`
5. `rc00_ops_cars`
6. `rc00_ops_reservations`
7. `rc00_ops_schedules`
8. `rc00_ops_reservation_states`
9. `rc00_ops_action_logs`
10. `rc00_ops_outbox`

이 순서를 먼저 지키는 이유:
- raw 가 먼저 있어야 ops 검증이 가능하다
- ops 원장이 있어야 state 를 계산할 수 있다
- state 가 있어야 action / outbox 가 의미를 가진다

## 9. 최소 필드 기준
### `rc00_ops_reservations_raw`
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

### `rc00_ops_schedules_raw`
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

### `rc00_ops_cars_raw`
- `sync_run_id`
- `sheet_row_number`
- `car_number`
- `car_name`
- `status`
- `car_wash`
- `interior_wash`
- `start_at`
- `end_at`
- `customer_name`
- `pickup_location`
- `customer_phone`
- `note_text`
- `parking_location`
- `status_action`
- `payload_json`

### `rc00_ops_reservations`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `customer_name`
- `customer_phone`
- `start_at`
- `end_at`
- `pickup_location`
- `dropoff_location`
- `status_raw`
- `source_sync_run_id`
- `source_reservation_raw_id`
- `primary_schedule_raw_id`
- `last_synced_at`
- `note_text`
- `meta_json`

### `rc00_ops_cars`
- `car_number`
- `car_name`
- `status`
- `car_wash`
- `interior_wash`
- `start_at`
- `end_at`
- `customer_name`
- `pickup_location`
- `customer_phone`
- `note_text`
- `parking_location`
- `status_action`
- `source_import_run_id`
- `source_car_raw_id`
- `payload_json`
- `last_synced_at`

### `rc00_ops_schedules`
- `schedule_id`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `schedule_type_raw`
- `schedule_at_raw`
- `location_text`
- `detail_text`
- `partial_return_raw`
- `schedule_done_raw`
- `source_import_run_id`
- `source_schedule_raw_id`
- `payload_json`

### `rc00_ops_reservation_states`
- `reservation_id`
- `reservation_ref_id`
- `tab_key`
- `needs_attention`
- `warning_level`
- `check_payload_json`
- `last_action_at`
- `completed_at`
- `memo_text`
- `updated_at`
- `created_at`

## 10. 외부 반영 원칙
- Google Sheets write 는 최종 phase 전까지 금지
- MVP 에서는 outbox dry-run 까지만 허용
- AppSheet API 직접 호출 안 함
- AppSheet/기존 봇은 시트 변경에 반응하는 후속 자동화 레이어로 본다
- 앱 운영 write 는 `rc00_ops_cars / rc00_ops_reservations / rc00_ops_schedules` 에만 허용한다

## 11. 바로 볼 문서
- 예약 UI / 상태 전이 / 업무 흐름: `rentcar00_OPS-reservation-layer-design-v1.md`
- 전체 허브 / 중요 참고 위치: `rentcar00_OPS-current-index-progress.md`
- 공통 네이밍 규칙: `rentcar00_OPS-naming-mapping-rules-v1.md`
