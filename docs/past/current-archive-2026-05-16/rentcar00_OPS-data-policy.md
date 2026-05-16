# rentcar00_OPS Data Policy

## 문서 역할
이 문서는 `rentcar00_OPS`의 **운영 데이터 정책 lock 문서**다.
코드 구현보다 우선해서 데이터 저장/표시/정리 기준을 정의한다.

- `main` 문서: 제품/화면/운영 전체 기준
- `current` 문서: 현재 실행 작업 1건
- `completed` 문서: 완료 기능 누적
- 이 문서: **데이터 source of truth / schema / 저장 형식 / raw-import 제거 정책**

## 작성 상태
- 작성 시작: 2026-05-15
- 현재 상태: canonical 날짜/시간 1차 적용 완료
- 목적: Google Sheets/raw/import 기반을 종료하고, 현재 운영 DB를 직접 source of truth 로 승격한다.

## 정책 결정 요약
1. Google Sheets 는 더 이상 운영 source of truth 로 쓰지 않는다.
2. raw/import 테이블은 운영 기준에서 제거한다.
3. 앱이 직접 쓰는 값은 canonical 컬럼에 저장한다.
4. 날짜/시간은 `timestamptz` 로 저장하고, 화면 표시 형식은 앱에서 만든다.
5. `_raw` suffix 컬럼은 운영 앱이 직접 읽고 쓰는 컬럼으로 쓰지 않는다.
6. 삭제/drop 은 backfill 검증 후 마지막 phase 에서만 한다.
7. 운영 직전이므로 임시 호환보다 장기 schema 를 우선한다.

---

## 1. Source of Truth

### 1.1 운영 원본 테이블
아래 테이블만 운영 앱의 source of truth 로 둔다.

- `rc00_ops_cars`
- `rc00_ops_reservations`
- `rc00_ops_reservation_states`
- `rc00_ops_schedules`
- `rc00_ops_action_logs`
- `rc00_ops_outbox`
- `rc00_ops_staff_accounts`

### 1.2 폐기 예정 테이블
아래 테이블은 Google Sheets import/normalize 과거 이관용이다.
운영 source of truth 가 아니다.

- `rc00_ops_import_runs`
- `rc00_ops_cars_raw`
- `rc00_ops_reservations_raw`
- `rc00_ops_schedules_raw`

현재 remote row 수:
- `rc00_ops_import_runs`: 3
- `rc00_ops_cars_raw`: 116
- `rc00_ops_reservations_raw`: 172
- `rc00_ops_schedules_raw`: 202
- 운영 projection:
  - `rc00_ops_cars`: 58
  - `rc00_ops_reservations`: 10
  - `rc00_ops_schedules`: 36

### 1.3 폐기 예정 도구
- `tool/import_google_sheets_raw.dart`
- `tool/normalize_raw_to_projection.dart`

### 1.4 보관 여부 검토 도구
- `tool/inspect_google_sheets.dart`
  - 운영 입력용은 아니다.
  - 과거 확인용으로 남길지, `docs/past` 성격으로 archive 할지 결정 필요.

---

## 2. 날짜/시간 정책

### 2.1 저장 원칙
- DB 저장 기준 날짜/시간은 `timestamptz` 로 둔다.
- Flutter 앱 내부에서는 `DateTime` 으로 다룬다.
- 외부 API/DB 저장은 ISO/timestamp compatible 형식을 쓴다.
- 사용자에게 보이는 형식은 UI layer 에서만 만든다.

### 2.2 표시 원칙
예시:
- 날짜 헤더: `2026.05.16(토)`
- 시간: `11:00`
- 입력 필드: `2026-05-16 11:00`

이 형식은 저장 형식이 아니라 **표시 형식**이다.

### 2.3 금지
아래 값은 canonical 날짜로 저장하지 않는다.

- `2026/05/24, 10:00`
- `2026-05-16 11:00:00` text 기준화
- `2026-05-16T11:00:00.000` 를 text 컬럼에 저장
- `11월25일`, `6월12일`, `10월18일` 같은 연도 없는 값
- `24/11/6`, `25/10/14` 같은 2자리 연도값을 검증 없이 자동 확정

---

## 3. 테이블별 정책

## 3.1 `rc00_ops_schedules`

### 현재 코드 의존성
현재 앱은 아래 raw 컬럼을 직접 사용 중이다.

- `schedule_type_raw`
- `schedule_at_raw`
- `schedule_done_raw`
- `partial_return_raw`
- `source_import_run_id`
- `source_schedule_raw_id`

주요 코드:
- `SupabaseOpsRepository.createReservationFromVehicle()`
- `SupabaseOpsRepository.createScheduleOnly()`
- `SupabaseOpsRepository.updateSchedule()`
- `SupabaseOpsRepository.completeSchedule()`
- `SupabaseOpsRepository.fetchStatusBoardRecords()`
- `SupabaseOpsRepository._toScheduleRecord()`
- `StatusBoardTabPage` schedule grouping/sort
- `StatusBoardDetailPage` schedule edit/complete/delete

### 현재 DB 값 분포
`rc00_ops_schedules.schedule_at_raw`:
- 기존 공백+초 형식: 32건
- slash/comma 형식: 3건
- ISO text 형식: 0건으로 보정 완료

### 목표 schema
신규 canonical 컬럼:
- `schedule_type text not null`
- `schedule_at timestamptz`
- `schedule_done boolean not null default false`
- `partial_return_at timestamptz null`

유지 후보:
- `id`
- `schedule_id`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `location_text`
- `detail_text`
- `payload_json`
- `created_at`
- `updated_at`

삭제 후보:
- `schedule_type_raw`
- `schedule_at_raw`
- `schedule_done_raw`
- `partial_return_raw`
- `source_import_run_id`
- `source_schedule_raw_id`

### 앱 정책
- 일정 feed 포함 여부는 `schedule_done = false` 기준.
- 일정 종류는 `schedule_type in ('배차', '반납', '기타')` 기준.
- 정렬/그룹은 `schedule_at` 기준.
- 표시 문자열은 앱에서 계산.
- 일정 수정/생성은 `schedule_at` 에만 저장.
- raw fallback 은 migration 전환 중 임시로만 허용하고 release 이후 제거한다.

---

## 3.2 `rc00_ops_cars`

### 현재 코드 의존성
현재 앱은 차량 날짜를 text 로 읽고 일부 parsing 한다.

- `start_at`
- `end_at`

주요 코드:
- `SupabaseOpsRepository.updateCarInstantStatus()`
- `SupabaseOpsRepository.completeSchedule()`
- `SupabaseOpsRepository._toCarRecord()`
- `StatusBoardTabPage` 일반/보험/장기 카드 표시/정렬
- `StatusBoardDetailPage` 차량 상태 수정 dialog

### 현재 문제값
`rc00_ops_cars.start_at/end_at` 중 canonical 변환 확인이 필요한 row 9건:

- `101하3154` / IG / 장기 / `24/11/6`
- `101하7004` / 소나타 / 장기 / `25/10/14`
- `101하7031` / IG / 장기 / `22/11/15`
- `125하1718` / GN7 / 장기 / `25/11/7`
- `125호3844` / 소나타 / 장기 / `24/3/25`
- `142호1587` / K5 / 장기 / `20/12/28`
- `29하2763` / MODEL Y / 장기 / `11월25일`
- `34호7488` / IG / 장기 / `6월12일`
- `34호7499` / K7 / 장기 / `10월18일`

### 목표 schema
권장 방식은 기존 text 컬럼을 바로 type 변경하지 않고, 신규 canonical 컬럼을 추가한 뒤 검증 후 rename/drop 한다.

1차 추가:
- `start_at_ts timestamptz null`
- `end_at_ts timestamptz null`

검증 후 최종:
- `start_at timestamptz null`
- `end_at timestamptz null`

삭제 후보:
- `source_import_run_id`
- `source_car_raw_id`

### 앱 정책
- 차량 상태 수정 저장은 canonical timestamp 에 쓴다.
- 카드 표시값은 canonical timestamp 를 앱에서 포맷한다.
- 불완전 날짜값은 자동 변환하지 않고 확인 목록으로 남긴다.

---

## 3.3 `rc00_ops_reservations`

### 현재 상태
- `start_at`, `end_at` 은 schema 상 `timestamptz` 이다.
- 예약 데이터는 날짜 정책상 가장 정상에 가깝다.

### 코드 의존성
- `SupabaseOpsRepository.createReservationFromVehicle()`
- `SupabaseOpsRepository.fetchReservations()`
- `ReservationRecord.startAt/endAt`
- `ReservationSummary.displayAt`
- IMS payload build

### 정책
- 예약 날짜는 현재 컬럼을 유지한다.
- 앱 표시만 UI layer 에서 처리한다.
- 예약 생성 시 `DateTime.toIso8601String()` 저장은 허용한다.
- 일정 생성과 예약 생성이 동시에 일어날 경우, 일정은 `rc00_ops_schedules.schedule_at` 으로 별도 저장한다.

---

## 3.4 `rc00_ops_reservation_states`

### 정책
- 예약 업무 상태 source of truth 로 유지한다.
- raw/import 와 직접 연결하지 않는다.
- 상태 계산/변경은 예약 테이블과 함께 운영 기준으로 재정리 가능.

검토 필요:
- 현재 tab 계산이 생성 시점 기준으로 고정되는 구조인지 확인.
- 날짜가 바뀔 때 state tab 재계산 필요 여부.

---

## 3.5 `rc00_ops_action_logs`

### 정책
- 운영 액션 감사 로그로 유지한다.
- 직원 로그인 도입 후 actor 는 `staff_accounts` 기반으로 확장 가능.
- raw/import 기준 action key 신규 추가 금지.

검토 필요:
- 현재 앱은 action log 를 거의 표시하지 않는다.
- 후속 phase 에서 실제 액션 기록 저장 여부 결정.

---

## 3.6 `rc00_ops_outbox`

### 현재 코드 상태
- `OutboxEntry` 모델에 `sheetName` 이 남아 있다.
- `outboxEntriesProvider` 는 현재 빈 데이터만 반환한다.
- Sync page 는 Google Sheets write 비활성 문구와 outbox preview 를 보여준다.

### 정책
- Google Sheets 전송 전제는 제거한다.
- outbox 를 유지한다면 범용 외부 연동 큐로 재정의한다.
- `sheetName` 모델 필드는 제거 또는 `targetName/targetType` 으로 일반화한다.

검토 필요:
- Sync page 자체를 삭제할지, 운영 진단 페이지로 바꿀지 결정.

---

## 3.7 `rc00_ops_staff_accounts`

### 정책
- 앱 접근 제어 source of truth 로 유지한다.
- `auth_user_id`, `login_id`, `role`, `is_active` 유지.
- 계정 공유는 기술적으로 가능하지만 운영 추적성 기준으로 비권장.
- 공개 signup 은 계속 차단한다.

---

## 4. 코드 정리 정책

### 4.1 Repository
`SupabaseOpsRepository` 는 현재 raw/import 의존이 가장 크다.

제거 대상:
- `_latestImportRunId()`
- `fetchSyncRuns()` 또는 의미 전환
- `source_import_run_id` 쓰기
- `source_*_raw_id` 의존
- `schedule_*_raw` 읽기/쓰기
- text 날짜 parsing 기반 정렬

유지/전환 대상:
- 예약 fetch/create
- 차량 fetch/update
- 일정 fetch/create/update/complete/delete
- staff auth repository

### 4.2 Models
변경 후보:
- `StatusBoardRecord.startAt/endAt`: 표시용 String 유지 가능하나 canonical DateTime 필드 추가 권장.
- `StatusBoardRecord.scheduleDone`: String → bool.
- `OutboxEntry.sheetName`: 제거 또는 일반화.
- `SyncRunEntry`: import 종료 후 제거 가능.

### 4.3 UI
- UI 입력 필드는 사용자가 보기 쉬운 형식으로 둔다.
- 저장 전 반드시 `DateTime`/canonical type 으로 변환한다.
- 정렬/그룹/필터는 표시 문자열이 아니라 canonical 값 기준.

### 4.4 Tool
삭제 후보:
- `tool/import_google_sheets_raw.dart`
- `tool/normalize_raw_to_projection.dart`

보류:
- `tool/inspect_google_sheets.dart`

---

## 5. Migration 정책

### 원칙
운영 직전이므로 장기 구조로 바로 간다.
단, drop 은 마지막에 한다.

### 권장 순서
1. canonical 컬럼 추가
2. 기존 값 backfill
3. 파싱 실패 row 목록 산출
4. 앱 코드 canonical 우선으로 전환
5. 실기기 검증
6. raw/import 컬럼 제거
7. raw/import 테이블 제거
8. Google Sheets 문서 기준 제거
9. completed 문서 반영

### 금지
- backfill 검증 전 raw/import table drop 금지
- 불완전 날짜값 임의 보정 금지
- 표시 문자열을 저장 기준으로 삼는 것 금지
- 앱과 DB schema 불일치를 오래 유지하는 것 금지

---

## 6. 실행 phase 제안

### Phase A. DB canonical 컬럼 추가 + backfill
대상:
- `rc00_ops_schedules`
- `rc00_ops_cars`

종료 조건:
- `schedule_at` backfill 완료
- `schedule_done` boolean 변환 완료
- 차량 날짜 변환 가능 row backfill 완료
- 변환 불가 차량 9건 목록 고정

### Phase B. 앱 canonical 전환
대상:
- `SupabaseOpsRepository`
- `StatusBoardRecord`
- `StatusBoardTabPage`
- `StatusBoardDetailPage`
- `ScheduleEditorDialog`

종료 조건:
- 일정탭 정렬/그룹이 `schedule_at` 기준
- 일정 수정/생성이 `schedule_at` 에 저장
- 차량 날짜 표시/정렬이 canonical 기준
- `flutter analyze` 통과

### Phase C. raw/import 제거
대상:
- raw/import tables
- source reference columns
- import/normalize tools
- Sync page/import 문구
- main/completed 문서의 Google Sheets 운영 기준

종료 조건:
- 앱 코드에서 `*_raw`, `source_import`, `import_runs` 운영 의존 제거
- migration 적용 후 remote schema 확인
- 실기기 주요 흐름 확인

### Phase D. 배포
- APK build
- gdrive upload
- completed 문서 반영
- commit

---

## 7. 현재 검토 체크리스트

- [x] raw/import 테이블 목록 확인
- [x] projection 테이블 row 수 확인
- [x] `schedule_at_raw` 형식 분포 확인
- [x] 차량 날짜 불완전 row 9건 확인
- [x] repository raw/import 의존 확인
- [x] sync/outbox Google Sheets 잔재 확인
- [x] migration 작성 및 remote 적용
- [x] 앱 날짜/시간 canonical 컬럼 전환
- [ ] main/current/completed 문서 기준 정리
- [ ] 실기기 검증 항목 확정

## 8. 미결정 사항
1. `rc00_ops_cars.start_at/end_at` 은 신규 `*_ts` 컬럼으로 1차 이관 후 rename 할지 여부
2. 차량 불완전 날짜 9건 중 연도 없는 3건의 실제 연도 확정 방식
3. `SyncPage` 를 삭제할지, 운영 진단 페이지로 바꿀지
4. `tool/inspect_google_sheets.dart` 보관 여부
5. raw/import drop 을 같은 release 에 할지, canonical 전환 후 1회 release 뒤 할지

---

# DB 변경 설계안 v1

## 목적
현재 운영 직전 상태에서 Google Sheets/raw/import 기반을 제거하고, 앱이 직접 운영할 canonical DB 구조로 전환한다.

이 설계안은 **실제 DB 변경 전 검토용**이다.
적용 전 별도 승인 필요.

## 변경 원칙
1. 먼저 추가한다.
2. 기존 값을 복사/backfill 한다.
3. 앱을 새 컬럼 기준으로 전환한다.
4. 검증 후 기존 raw/import 컬럼과 테이블을 제거한다.
5. 파싱 실패값은 임의 보정하지 않는다.

---

## A. `rc00_ops_schedules` 변경 설계

### 현재 컬럼
현재 remote 확인 기준:
- `id`
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
- `created_at`
- `updated_at`

### 문제
- 앱 운영 컬럼인데 이름과 타입이 raw 기준이다.
- `schedule_at_raw` 는 text 라서 정렬/그룹/외부 연동 기준으로 부적합하다.
- `schedule_done_raw` 는 text truthy 값이라 앱에서 매번 truthy 파싱한다.
- `source_import_run_id`, `source_schedule_raw_id` 는 앞으로 운영 기준이 아니다.

### 추가할 canonical 컬럼
1차 추가:
- `schedule_type text`
- `schedule_at timestamptz`
- `schedule_done boolean not null default false`
- `partial_return_at timestamptz null`

권장 index:
- `idx_rc00_ops_schedules_schedule_at` on `schedule_at`
- `idx_rc00_ops_schedules_schedule_done` on `schedule_done`
- `idx_rc00_ops_schedules_schedule_type` on `schedule_type`

### backfill 규칙
- `schedule_type = trim(schedule_type_raw)`
- `schedule_done = truthy(schedule_done_raw)`
  - truthy: `true`, `t`, `y`, `yes`, `1`, `완료`
  - 그 외 false
- `schedule_at = parse(schedule_at_raw)`
  - 허용 입력:
    - `YYYY-MM-DD HH:mm:ss`
    - `YYYY-MM-DD HH:mm`
    - `YYYY/MM/DD, H:mm`
    - ISO timestamp
- `partial_return_at = parse(partial_return_raw)` 가능할 때만

### 파싱 실패 처리
- `schedule_at_raw` 파싱 실패 row 는 `schedule_at = null` 로 둔다.
- 실패 row 는 적용 전/후 보고한다.
- 실패 row 를 임의 날짜로 보정하지 않는다.

### 앱 전환 기준
- 일정 목록 조회:
  - 기존: `schedule_type_raw`, `schedule_done_raw`, `schedule_at_raw`
  - 변경: `schedule_type`, `schedule_done`, `schedule_at`
- 일정 생성/수정:
  - 기존 raw 컬럼 write 중단
  - canonical 컬럼만 write
- 화면 표시:
  - `schedule_at` 을 앱에서 `YYYY.MM.DD(요일)`, `HH:mm` 으로 포맷

### 최종 삭제 후보
검증 완료 후 삭제:
- `schedule_type_raw`
- `schedule_at_raw`
- `schedule_done_raw`
- `partial_return_raw`
- `source_import_run_id`
- `source_schedule_raw_id`

---

## B. `rc00_ops_cars` 변경 설계

### 현재 컬럼
현재 remote 확인 기준:
- `id`
- `car_number`
- `car_name`
- `status`
- `car_wash`
- `interior_wash`
- `start_at` text
- `end_at` text
- `customer_name`
- `customer_phone`
- `pickup_location`
- `parking_location`
- `note_text`
- `car_registered_at`
- `car_inspection_at`
- `car_age_expiry_at`
- `car_number_front`
- `car_number_middle`
- `car_number_rear`
- `status_action`
- `source_import_run_id`
- `source_car_raw_id`
- `payload_json`
- `last_synced_at`
- `created_at`
- `updated_at`

### 문제
- `start_at`, `end_at` 이 text 이다.
- 장기 차량 일부 값이 불완전하다.
- 화면 정렬/표시가 text parsing 에 의존한다.

### 추가할 canonical 컬럼
기존 컬럼명과 충돌을 피하기 위해 1차는 새 컬럼으로 둔다.

- `start_at_ts timestamptz null`
- `end_at_ts timestamptz null`

권장 index:
- `idx_rc00_ops_cars_start_at_ts`
- `idx_rc00_ops_cars_end_at_ts`

### backfill 규칙
- `start_at_ts = parse(start_at)` 가능할 때만
- `end_at_ts = parse(end_at)` 가능할 때만

허용 입력:
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm:ss`
- `YY/M/D` 는 2000년대 기준으로 변환 가능하나, 정책상 적용 전 확인 목록에 먼저 올린다.

### 자동 변환 보류 row
현재 확인된 9건은 자동 변환 보류 대상이다.

- `101하3154` / `24/11/6`
- `101하7004` / `25/10/14`
- `101하7031` / `22/11/15`
- `125하1718` / `25/11/7`
- `125호3844` / `24/3/25`
- `142호1587` / `20/12/28`
- `29하2763` / `11월25일`
- `34호7488` / `6월12일`
- `34호7499` / `10월18일`

정책:
- 위 값들은 migration 에서 임의 확정하지 않는다.
- 운영 판단 후 수동 보정하거나 null 로 두고 화면에서 `날짜확인필요` 로 표시한다.

### 앱 전환 기준
- 차량 카드 정렬은 `end_at_ts` 우선, 없으면 `start_at_ts`.
- 표시값은 앱에서 포맷한다.
- 차량 상태 수정 dialog 는 `start_at_ts/end_at_ts` 에 저장한다.

### 최종 삭제/rename 후보
검증 후 선택:
1. 안전안:
   - 기존 `start_at/end_at` text 를 한 release 동안 deprecated 로 유지
   - 앱은 `*_ts` 만 사용
2. 정리안:
   - 기존 `start_at/end_at` text 를 `start_at_legacy/end_at_legacy` 로 rename
   - `start_at_ts/end_at_ts` 를 `start_at/end_at` 으로 rename

추천:
- 운영 직전이지만 데이터 위험이 있으므로 **안전안 먼저**.
- 실기기 검증 후 정리안 적용.

삭제 후보:
- `source_import_run_id`
- `source_car_raw_id`

---

## C. `rc00_ops_reservations` 변경 설계

### 현재 상태
- `start_at`, `end_at` 은 이미 `timestamptz`.
- 날짜 저장 정책상 큰 변경 필요 없음.

### 정리 후보
- 예약 테이블은 이미 provenance column 을 과거 migration 에서 제거했다.
- 유지한다.

### 앱 전환 기준
- 예약 생성은 현재처럼 `DateTime.toIso8601String()` 허용.
- 예약 화면 표시만 앱에서 포맷.

---

## D. import/raw 제거 설계

### 제거 대상 테이블
최종 drop 후보:
- `rc00_ops_import_runs`
- `rc00_ops_cars_raw`
- `rc00_ops_reservations_raw`
- `rc00_ops_schedules_raw`

### 제거 전 조건
아래를 모두 만족해야 drop 가능하다.

1. 앱 코드에서 `rc00_ops_import_runs` 조회 제거
2. 앱 코드에서 `source_import_run_id` 쓰기 제거
3. 앱 코드에서 `source_*_raw_id` 의존 제거
4. `tool/import_google_sheets_raw.dart` 제거
5. `tool/normalize_raw_to_projection.dart` 제거
6. `docs/current/rentcar00_OPS-main.md` 의 Google Sheets source 기준 제거
7. canonical 컬럼 기반 APK 실기기 검증 완료

### 현재 코드상 제거 필요 지점
- `SupabaseOpsRepository._latestImportRunId()`
- `SupabaseOpsRepository.fetchSyncRuns()`
- `syncRunsProvider`
- `SyncPage`
- `SyncRunEntry`
- `MockOpsRepository.fetchSyncRuns()`
- `tool/import_google_sheets_raw.dart`
- `tool/normalize_raw_to_projection.dart`

---

## E. outbox/sync 정리 설계

### 현재 상태
- `rc00_ops_outbox` schema 는 범용 큐에 가깝다.
- 앱 모델 `OutboxEntry` 에만 `sheetName` 이 남아 있다.
- 실제 provider 는 빈 리스트를 반환한다.
- `SyncPage` 는 Google Sheets write 비활성 문구를 보여준다.

### 정책
- `rc00_ops_outbox` 테이블은 유지 가능.
- 앱 모델의 `sheetName` 은 제거한다.
- `SyncPage` 는 삭제하거나 `운영 진단` 화면으로 이름/내용을 바꾼다.

추천:
- 이번 canonical 전환 phase 에서는 `SyncPage` 를 제거하는 쪽이 깔끔하다.
- outbox 테이블은 후속 외부 연동용으로 유지한다.

---

## F. SQL 설계 스케치

> 아래는 실행 SQL 이 아니라 설계 스케치다. 실제 적용 전 별도 migration 파일로 작성하고 검토한다.

### F-1. schedules canonical column 추가
```sql
alter table public.rc00_ops_schedules
  add column if not exists schedule_type text,
  add column if not exists schedule_at timestamptz,
  add column if not exists schedule_done boolean not null default false,
  add column if not exists partial_return_at timestamptz;

create index if not exists idx_rc00_ops_schedules_schedule_at
  on public.rc00_ops_schedules (schedule_at);
create index if not exists idx_rc00_ops_schedules_schedule_done
  on public.rc00_ops_schedules (schedule_done);
create index if not exists idx_rc00_ops_schedules_schedule_type
  on public.rc00_ops_schedules (schedule_type);
```

### F-2. cars canonical date column 추가
```sql
alter table public.rc00_ops_cars
  add column if not exists start_at_ts timestamptz,
  add column if not exists end_at_ts timestamptz;

create index if not exists idx_rc00_ops_cars_start_at_ts
  on public.rc00_ops_cars (start_at_ts);
create index if not exists idx_rc00_ops_cars_end_at_ts
  on public.rc00_ops_cars (end_at_ts);
```

### F-3. drop 은 별도 migration
```sql
-- canonical 전환 검증 후 별도 적용
-- alter table public.rc00_ops_schedules drop column ...;
-- drop table public.rc00_ops_*_raw;
-- drop table public.rc00_ops_import_runs;
```

---

## G. 검증 기준

### DB 검증
- `rc00_ops_schedules` 전체 36건 중 가능한 row 의 `schedule_at` 이 채워져야 한다.
- `schedule_at` null row 는 이유와 row 목록을 보고한다.
- `schedule_done` 은 기존 truthy 값과 동일하게 동작해야 한다.
- `rc00_ops_cars` 날짜 변환 실패 row 는 기존 9건으로 고정되어야 한다.

### 앱 검증
- 일정탭 날짜 그룹 정상
- 일정 상세 수정 후 같은 날짜 그룹에 유지
- 일정 생성 후 `schedule_at` 저장 확인
- 일정 완료 후 목록에서 제외
- 차량 상세 날짜 표시 정상
- 차량 상태 수정 저장 후 날짜 표시 정상
- 예약 원장 날짜 표시 정상
- 로그인/로그아웃 기존 동작 유지

### 중단 기준
아래 발생 시 DB 변경/코드 전환 중단:
- backfill 실패 row 가 예상보다 많음
- 일정탭에서 날짜 그룹이 깨짐
- 예약/차량 날짜가 하루 밀림
- timezone 때문에 오전/오후가 바뀜
- raw/import 컬럼이 아직 코드에서 필요한 것으로 확인됨

---

## H. 권장 실행 순서 확정안

1. 이 정책 문서 검토/승인
2. migration 파일 작성만 진행
3. migration SQL review
4. remote DB 적용 승인
5. remote DB 적용
6. backfill 결과 확인
7. 앱 코드 canonical 전환
8. `flutter analyze`
9. APK build/gdrive upload
10. 실기기 확인
11. raw/import 제거 migration 별도 진행



---

# 적용 기록 — 2026-05-15 canonical 날짜/시간 1차 적용

## 적용 migration
- `20260515124500_add_canonical_datetime_columns.sql`

## DB 적용 내용
- `rc00_ops_schedules`
  - `schedule_type text`
  - `schedule_at timestamptz`
  - `schedule_done boolean`
  - `partial_return_at timestamptz`
- `rc00_ops_cars`
  - `start_at_ts timestamptz`
  - `end_at_ts timestamptz`
- `rc00_ops_reservations`
  - 기존 `start_at/end_at` timestamptz 값을 Asia/Seoul 기준 시간으로 1회 재해석
  - `meta_json.kst_reinterpreted_at` 마킹

## backfill 검증 결과
- schedules: 36건
- schedules `schedule_at` missing: 0건
- schedules `schedule_type` missing: 0건
- cars: 58건
- cars legacy `end_at` 존재하지만 `end_at_ts` missing: 0건
- cars legacy `start_at` 존재하지만 `start_at_ts` missing: 3건
  - `29하2763` / `11월25일`
  - `34호7488` / `6월12일`
  - `34호7499` / `10월18일`
- reservations: 10건
- reservations `kst_reinterpreted_at` marked: 10건

## 앱 코드 적용 내용
- 일정 생성/수정/완료는 canonical 컬럼 사용
  - `schedule_type`
  - `schedule_at`
  - `schedule_done`
- 차량 상태 수정은 canonical 날짜 컬럼 사용
  - `start_at_ts`
  - `end_at_ts`
- 일정 목록 조회/정렬/그룹은 `schedule_at` 기준
- UI/IMS 표시 포맷은 `DateTime.toLocal()` 기준으로 변환
- raw/import drop 은 아직 하지 않음

## 검증
- `flutter analyze` 통과
- `git diff --check` 통과

## 남은 정책 작업
- raw/import 테이블과 source 컬럼 제거는 별도 phase
- `SyncPage` / `SyncRunEntry` / Google Sheets 문구 제거 또는 운영진단 전환 필요
- 차량 연도 없는 start date 3건은 운영 확인 필요


---

# 적용 기록 — 2026-05-15 raw/import drop 완료

## 적용 migration
- `20260515130000_drop_raw_import_tables.sql`

## 제거한 DB 대상
- `rc00_ops_import_runs`
- `rc00_ops_cars_raw`
- `rc00_ops_reservations_raw`
- `rc00_ops_schedules_raw`
- `rc00_ops_cars.source_import_run_id`
- `rc00_ops_cars.source_car_raw_id`
- `rc00_ops_schedules.source_import_run_id`
- `rc00_ops_schedules.source_schedule_raw_id`
- `rc00_ops_schedules.schedule_type_raw`
- `rc00_ops_schedules.schedule_at_raw`
- `rc00_ops_schedules.schedule_done_raw`
- `rc00_ops_schedules.partial_return_raw`

## 제거한 앱/도구 대상
- `tool/import_google_sheets_raw.dart`
- `tool/normalize_raw_to_projection.dart`
- `lib/data/models/sync_run_entry.dart`
- 사용되지 않는 mock/sync 상태 모델

## 앱 정리
- `SyncPage` 는 Google Sheets sync 화면에서 `운영 진단` 화면으로 전환
- import run 조회 provider 제거
- 운영 데이터 기준은 projection/canonical 테이블로 고정

## 검증
- remote migration 적용 확인: local/remote `20260515130000` 일치
- 삭제된 raw/import 테이블 REST 접근 결과: 모두 `HTTP_404`
- `flutter analyze` 통과
- `git diff --check` 통과

## 남은 확인
- 차량 시작일 3건은 연도 없는 원문이라 수동 확인 필요
  - `29하2763` — `11월25일`
  - `34호7488` — `6월12일`
  - `34호7499` — `10월18일`
