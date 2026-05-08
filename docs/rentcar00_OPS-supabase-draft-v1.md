# rentcar00_OPS Supabase 초안 v1

## 1. 초안 목적
이 문서는 현재 확인된 Supabase 구조와 앞으로 필요한 업무처리 구조 사이의 간극을 메우기 위한 1차 초안이다.

현재 기준 메모:
- Supabase 프로젝트 `rentcar00-ops` 생성 완료
- project ref: `wojisucidqzjrqbuiikl`
- 앱은 Supabase를 직접 조회하고, Google Sheets는 sync/import 원본으로만 다룬다
- 앱 번들에는 공개값만 포함하고, secret은 작업/서버용으로 분리한다

중요:
- Google Sheets `차량현황 > 예약` 탭의 기본 컬럼은 확인했다.
- 다만 AppSheet virtual column, 계산 로직, 실무 보조 입력 구조는 아직 확인 전이다.
- 따라서 이 문서는 `최종 스키마 확정`이 아니라 `설계 방향 초안`이다.

## 2. 시트 실사 요약
기준 원본은 Google Sheets `차량현황` 문서의 `예약` 탭 + `일정` 탭이다.

### 예약 탭
확인된 원본 예약 컬럼은 아래 13개다.
- 예약ID
- 예약번호
- 차량번호
- 차종
- 대여일
- 반납일
- 배반차위치
- 임차인
- 고객번호
- 생년월일
- 소개처
- 결제금액
- 예약상태

핵심 해석:
- 원본 시트에는 업무처리용 세부 상태가 없다.
- `오늘배차`, `반납일`, `계약서 상태`, `기사 배정`, `반납안내 발송` 등은 앱 내부 상태로 별도 보강해야 한다.
- `배반차위치`는 단일 컬럼이라 추후 앱에서는 배차/반납 주소 개념을 분리 저장할 필요가 있다.

### 일정 탭
확인된 일정 탭 컬럼은 아래 11개다.
- 일정번호
- 예약번호
- 차량번호
- Status
- Date
- 차종
- 위치
- 상세정보
- 가반납
- 예약ID
- 일정완료

핵심 해석:
- `예약ID`로 예약 탭과 직접 연결 가능한 행이 존재한다.
- `Status`는 배차/반납/기타 일정 구분값 역할을 한다.
- 다만 현재 탭에는 레거시 메모형 일정과 예약 연결형 일정이 섞여 있어 정규화가 필요하다.

## 3. 설계 원칙
### 원칙 1. 원본과 업무 상태를 분리한다
- 원본 예약 feed
- 업무 처리 상태
- 실행 로그
- 템플릿/설정
를 분리한다.

### 원칙 2. 기존 DB를 버리지 않는다
- `cars`는 재사용 가치가 높다.
- 기존 sync/연동 운영 방식은 참고 가능하다.
- 다만 이번 ops 앱의 원본 예약 기준은 Google Sheets `예약` + `일정` 탭으로 고정한다.

### 원칙 3. 업무앱은 projection 계층이 필요하다
Google Sheets 또는 IMS 원본을 그대로 업무 UI에 직접 얹지 말고,
업무 버튼 실행이 가능한 앱 전용 상태 계층을 둔다.

## 4. 추천 구조
### A. 원본 예약 feed 계층
역할:
- Google Sheets `예약` / `일정` 탭에서 들어오는 원본 저장

후보:
- `rc00_ops_sheet_reservations_raw`
- `rc00_ops_sheet_schedules_raw`

필요 이유:
- 원본값 보존
- sync 이력 추적
- 사람이 수동 처리한 업무 상태와 분리

### B. 업무처리 예약 원장 계층
역할:
- 앱이 참조하는 예약 기본 정보 1행 보유

후보:
- `rc00_ops_reservations`

포함 개념:
- 예약 식별값
- 고객/차량/일정/주소 기본값
- 시트 원문 상태
- 마지막 동기화 시각
- 원장 메모

판단:
- 이 계층은 앱의 예약 기준 원장이다.
- 앱 상태 source of truth 와는 분리하는 편이 안전하다.

### C. 예약별 현재 상태 계층
역할:
- 예약 1건당 현재 앱 상태 1행 저장

후보:
- `rc00_ops_reservation_states`

포함 개념:
- `tab_key`
- `status`
- 수동 override 값
- 확인 필요 플래그
- 현재 체크값
- 마지막 처리 시각
- 담당자 메모

판단:
- MVP에서도 분리 테이블이 더 안전하다.
- 카드용 원장 필드와 현재 상태 필드를 분리하면 sync 충돌과 상태 변경 책임이 깔끔해진다.

### D. 업무 액션 로그 계층
역할:
- 모든 버튼 실행 기록

후보:
- `rc00_ops_action_logs`

필수 개념:
- 예약 참조
- 액션 종류
- 버튼명
- 실행자
- 실행 시각
- 전/후 상태
- 성공/실패
- 실패 사유
- 메모
- 발송 문구 원문
- 외부 응답값

### E. 문자 템플릿 계층
역할:
- 템플릿 종류별 문구 관리

후보:
- `rc00_ops_message_templates`

필수 개념:
- 템플릿 종류
- 활성 여부
- 제목/본문
- 치환 변수 목록
- 수정 이력 또는 버전

### F. 외부 연결 매핑 계층
역할:
- Google Sheets 행 / AppSheet 예약 / IMS 예약 / 앱 내부 예약 연결

후보:
- `rc00_ops_external_mappings`
- `rc00_ops_sheet_sync_runs`

필수 개념:
- 내부 예약 식별값
- 외부 시스템 종류
- 외부 식별값
- 마지막 sync 시각
- sync 성공/실패 상태

## 5. 현재 DB 재사용 판단
### 바로 재사용 가능
- `cars`
- 일부 sync run / error 관리 개념

### 이번 앱의 원본 기준에서 제외
- `booking_orders`
- `ims_sync_reservations`

설명:
- 두 테이블 모두 이번 ops 앱의 source of truth 로 사용하지 않는다.
- 다만 기존 프로젝트 내부 자산으로 남겨둘 수는 있다.

## 6. 1차 권장 방향
### 방향안 A (권장)
- Google Sheets `예약` + `일정` 탭을 최우선 기준 원장으로 사용
- 원본 import/feed 계층을 유지
- 그 위에 업무처리 projection 계층을 둔다
- Flutter 앱은 시트를 직접 읽지 않고 Supabase만 조회한다

이유:
- 기존 AppSheet와 데이터 의미를 맞추기 쉽다
- 업무앱 전용 상태를 원본과 분리할 수 있다
- 나중에 IMS/문자/탁송/계약 연동 붙이기 쉽다
- 모바일 앱의 응답성과 상태 일관성을 지키기 쉽다

### 방향안 B
- `ims_sync_reservations`를 원본 기준으로 삼고 부족한 값을 시트에서 보완

리스크:
- 실제 운영 기준이 시트라면 사용자 인식과 어긋날 수 있다
- AppSheet 계산 논리와 분리될 수 있다

## 6-1. 다음 구현 기준
다음 단계에서는 아래 순서로 진행한다.
1. Flutter 공개 env 로드
2. Supabase client 초기화
3. 스키마 SQL 초안 실제화
4. repository 를 mock 에서 Supabase 기반으로 교체
5. read-only sync importer 연결

원칙:
- 앱에서 사용하는 값은 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 등 공개값만 사용한다
- DB password, service role, 외부 API secret 은 앱 바깥에서만 사용한다

## 7. 1차 물리 스키마 초안

### 7-1. `rc00_ops_sheet_reservations_raw`
목적:
- 시트 `예약` 탭 원문 보존

핵심 컬럼:
- `id`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `start_at`
- `end_at`
- `location_raw`
- `customer_name`
- `customer_phone`
- `customer_birth_date`
- `referral_source`
- `payment_amount`
- `status_raw`
- `payload_json`
- `synced_at`

### 7-2. `rc00_ops_sheet_schedules_raw`
목적:
- 시트 `일정` 탭 원문 보존

핵심 컬럼:
- `id`
- `schedule_id`
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `schedule_type_raw`
- `schedule_at`
- `location_raw`
- `detail_text`
- `partial_return_raw`
- `schedule_done_raw`
- `payload_json`
- `synced_at`

### 7-3. `rc00_ops_reservations`
목적:
- 예약 원장 projection

핵심 컬럼:
- `id`
- `reservation_id`
- `reservation_number`
- `car_id`
- `car_number`
- `car_name`
- `customer_name`
- `customer_phone`
- `start_at`
- `end_at`
- `pickup_address`
- `dropoff_address`
- `location_raw`
- `status_raw`
- `is_cancelled`
- `created_at`
- `updated_at`
- `synced_at`

### 7-4. `rc00_ops_reservation_states`
목적:
- 예약 1건당 현재 앱 상태 1행 저장

핵심 컬럼:
- `id`
- `reservation_id`
- `tab_key`
- `status`
- `manual_tab_override`
- `manual_status_override`
- `auto_tab_key`
- `auto_status`
- `is_conflict`
- `is_completed`
- `has_issue`
- `check_payload_json`
- `processed_at`
- `note_text`
- `created_at`
- `updated_at`

설명:
- 현재 체크값은 별도 check 테이블이 아니라 이 상태테이블의 `check_payload_json` 에 둔다.
- MVP 체크 현재값은 모두 `done | pending | skipped` 3값으로 통일한다.
- 반복 이력은 여기 누적하지 않고 `rc00_ops_action_logs` 로 분리한다.

### 7-5. `rc00_ops_action_logs`
목적:
- 모든 버튼 실행 감사 로그

핵심 컬럼:
- `id`
- `reservation_id`
- `action_key`
- `status`
- `request_payload_json`
- `result_payload_json`
- `message_text`
- `external_ref`
- `error_code`
- `error_message`
- `executed_by`
- `executed_at`

### 7-6. `rc00_ops_message_templates`
목적:
- 문자/안내문 템플릿 관리

핵심 컬럼:
- `id`
- `template_key`
- `title`
- `body_text`
- `variables_json`
- `is_active`
- `version_no`
- `updated_at`

### 7-7. `rc00_ops_external_mappings`
목적:
- 외부 시스템 연결 관리

핵심 컬럼:
- `id`
- `reservation_id`
- `source_name`
- `external_key`
- `external_subkey`
- `status`
- `synced_at`
- `error_message`

### 7-8. `rc00_ops_sheet_sync_runs`
목적:
- 시트 import/sync 실행 로그

핵심 컬럼:
- `id`
- `sync_type`
- `started_at`
- `finished_at`
- `status`
- `rows_seen`
- `rows_upserted`
- `rows_failed`
- `note_text`

## 8. 추천 뷰 / 계산 결과
- `rc00_ops_reservation_cards`
  - 카드 표시용 projection view
- `rc00_ops_tab_counts`
  - 탭별 카운트 view
- `rc00_ops_upcoming_returns`
  - 내일/오늘 반납 강조용 view

`rc00_ops_reservation_cards` 최소 출력 기준:
- `reservation_id`
- `customer_name`
- `car_number`
- `card_time_at`
- `location_summary`
- `primary_badge_1`
- `primary_badge_2`
- `highlight_color`

## 9. 카드/탭 계산 책임
- raw 테이블은 원문 보존만 한다.
- `rc00_ops_reservations` 는 예약 원장 projection 이다.
- `rc00_ops_reservation_states` 가 탭/상태의 source of truth 다.
- 액션 실행 결과는 `rc00_ops_action_logs` 에 남긴다.
- 카드에 필요한 경고값은 상태테이블 또는 카드 view 에서 계산한다.

예:
- 오늘배차 준비 미완료 → 주황 경고
- 배차중 반납일 내일 → 노랑 경고
- 수동 상태와 날짜 계산 충돌 → `has_issue = true`

고정 계산 기준:
- 예약중/오늘배차 카드 기준 시각은 `start_at`
- 배차중/반납일 카드 기준 시각은 `end_at`
- 완료 카드는 `completed_at` 우선, 없으면 `end_at`
- 오늘배차는 준비 미완료여도 탭 진입을 막지 않는다.
- 오늘배차 → 배차중은 `request_delivery` 자체가 아니라 실제 출발 확인값 기준이다.
- 배차중 → 반납일은 `end_at` 날짜의 00:00 기준이다.

## 10. Google Sheets outbound 반영 구조
### 10-1. 기본 원칙
- OPS 앱은 AppSheet API를 직접 호출하지 않는다.
- OPS 앱의 외부 반영은 Google Sheets 수정으로만 처리한다.
- 기존 AppSheet/봇은 시트 수정에 반응해 일정 생성 등 후속 작업을 수행한다.
- 단, 실제 Google Sheets apply는 최종 phase 전까지 금지하고, 그전에는 read-only + dry-run만 허용한다.

### 10-2. 필요한 outbound 계층
권장 추가:
- `rc00_ops_sheet_outbox`

목적:
- 어떤 액션이 어떤 시트 컬럼 수정으로 나가야 하는지 관리
- 시트 반영 성공/실패를 앱 내부에서 추적
- 초기 단계에서는 실제 apply 없이 dry-run / approval gate 역할 수행

핵심 컬럼:
- `id`
- `reservation_id`
- `sheet_name`
- `target_row_key`
- `target_column`
- `new_value`
- `trigger_reason`
- `status`
- `attempted_at`
- `applied_at`
- `error_message`

### 10-3. 반영 책임 분리
- `rc00_ops_action_logs`: 사용자가 버튼을 눌렀다는 사실
- `rc00_ops_reservation_states`: 앱 내부 완료/체크 상태
- `rc00_ops_sheet_outbox`: 외부 반영용 시트 수정 작업

즉,
버튼 실행 = 내부 상태 변경
시트 수정 = 외부 트리거 발사
를 분리한다.

### 10-4. 트리거 명세 방식
각 outbound 항목은 아래 4가지를 가져야 한다.
1. source action key
2. target sheet / row / column
3. expected downstream reaction
4. retry / fallback rule

## 11. 현재 시점 1차 스키마 해석
현재는 아래 4층 구조가 가장 적합해 보인다.

1. 원본 예약 데이터층
2. 업무처리 상태층
3. 로그/템플릿/연동층
4. 시트 outbound 트리거층

즉,
`원본 예약 = 사실 소스`
`업무 상태 = 앱 처리 소스`
`시트 수정 = 외부 반영 소스`
로 나누는 방식이다.

## 12. 1차 DDL 제안
주의:
- 아래는 **실제 SQL 확정본이 아니라 구조 잠금용 제안**이다.
- Google Sheets write는 여전히 금지 상태이며, outbox는 generate only 기준으로 본다.

### 12-1. 우선 생성 대상
1. `rc00_ops_sheet_reservations_raw`
2. `rc00_ops_sheet_schedules_raw`
3. `rc00_ops_reservations`
4. `rc00_ops_reservation_states`
5. `rc00_ops_action_logs`
6. `rc00_ops_message_templates`
7. `rc00_ops_sheet_sync_runs`
8. `rc00_ops_sheet_outbox`

### 12-2. 보류 가능 대상
- `rc00_ops_external_mappings`

판단:
- 초기에는 `reservation_id` 기준만으로도 충분할 가능성이 높다.
- 외부 시스템 식별값이 늘어날 때 별도 테이블로 분리해도 늦지 않다.

## 13. 체크 payload / 상태 계산 고정안
### 13-1. `check_payload_json` 저장 형식
예시 키:
- `id_verified`
- `address_verified`
- `pickup_ready`
- `pickup_notice_sent`
- `delivery_requested`
- `contract_created`
- `signature_notice_sent`
- `dispatch_started`
- `signature_verified`
- `return_notice_sent`
- `end_at_changed`
- `emergency_notice_sent`
- `accident_reported`
- `dropoff_address_changed`
- `extension_fee_notice_sent`
- `return_completed`

값 규칙:
- `pending`
- `done`
- `skipped`

### 13-2. 상태 계산 우선순위
1. `manual_tab_override`
2. `manual_status_override`
3. `check_payload_json.return_completed = done`
4. `end_at` today
5. `check_payload_json.dispatch_started = done`
6. `start_at` today
7. 기본 pending

## 14. raw import / 일정 정규화 고정안
### 14-1. 예약 생성 원칙
- `rc00_ops_reservations` 는 `예약` 탭에서만 생성한다.
- `일정` 탭 단독 행으로 예약 원장을 만들지 않는다.

### 14-2. 일정 연결 우선순위
1. `reservation_id`
2. `reservation_number` unique match
3. orphan raw 유지

### 14-3. 레거시 일정 처리
- direct/unique match 실패 시 레거시 메모 일정으로 둔다.
- 레거시 일정은 `rc00_ops_sheet_schedules_raw` 에만 저장한다.
- 카드/탭 계산과 outbox 생성에는 사용하지 않는다.

### 14-4. normalized schedule type
- `pickup`
- `return`
- `maintenance`
- `other`

## 15. outbound 최소 고정안
outbox 생성 대상은 아래 4개만 MVP 고정으로 본다.
- `rc00_ops_action_request_delivery`
- `rc00_ops_action_change_end_at`
- `rc00_ops_action_change_dropoff_address`
- `rc00_ops_action_complete_return`

나머지 액션은 내부 로그 + `check_payload_json` 갱신만 수행한다.

### 12-3. 키 / 제약 제안
#### `rc00_ops_sheet_reservations_raw`
- PK: `id`
- Unique: `reservation_id`
- Index: `reservation_number`, `car_number`, `start_at`, `end_at`

#### `rc00_ops_sheet_schedules_raw`
- PK: `id`
- Unique: `schedule_id`
- Index: `reservation_id`, `reservation_number`, `car_number`, `schedule_at`

#### `rc00_ops_reservations`
- PK: `id`
- Unique: `reservation_id`
- Index: `car_number`, `start_at`, `end_at`, `is_cancelled`
- FK 후보: `car_id -> cars.id` nullable

#### `rc00_ops_reservation_states`
- PK: `id`
- Unique: `reservation_id`
- Index: `tab_key`, `status`, `is_completed`, `has_issue`, `processed_at`

#### `rc00_ops_action_logs`
- PK: `id`
- Index: `reservation_id`, `action_key`, `status`, `executed_at`

#### `rc00_ops_message_templates`
- PK: `id`
- Unique: `template_key`
- Index: `is_active`

#### `rc00_ops_sheet_sync_runs`
- PK: `id`
- Index: `sync_type`, `status`, `started_at`

#### `rc00_ops_sheet_outbox`
- PK: `id`
- Index: `reservation_id`, `status`, `sheet_name`, `created_at`
- Unique 후보: `(reservation_id, source_action_log_id, target_sheet_name, target_column)`

### 12-4. enum 대신 문자열 키 제안
초기에는 DB enum보다 문자열 키를 우선한다.

대상:
- `tab_key`
- `action_key`
- `check_key`
- `status`
- `sync_type`
- `sheet_name`

이유:
- 문서 기준 변경에 유연하다.
- Flutter/관리 화면/운영 수정 시 enum migration 비용을 줄인다.

### 12-5. outbox 필드 보강 제안
기존 초안 필드에 아래를 추가하는 안을 권장한다.
- `source_action_log_id`
- `target_sheet_name`
- `target_row_key_name`
- `target_row_key_value`
- `payload_json`
- `dry_run_preview_text`
- `approved_for_apply_at`
- `approved_for_apply_by`
- `created_at`
- `updated_at`

판단:
- 단일 `target_row_key` 만으로는 운영 검증이 약하다.
- row key 이름/값을 분리해 두는 편이 안전하다.

### 12-6. 예약 원장 / 상태 최소 필드 제안
`rc00_ops_reservations` 에 최소 포함 권장:
- `reservation_id`
- `reservation_number`
- `car_number`
- `car_name`
- `customer_name`
- `customer_phone`
- `start_at`
- `end_at`
- `location_raw`
- `status_raw`
- `is_cancelled`
- `created_at`
- `updated_at`
- `synced_at`

`rc00_ops_reservation_states` 에 최소 포함 권장:
- `reservation_id`
- `tab_key`
- `status`
- `auto_tab_key`
- `auto_status`
- `manual_tab_override`
- `manual_status_override`
- `is_completed`
- `has_issue`
- `check_payload_json`
- `note_text`
- `processed_at`
- `created_at`
- `updated_at`

초기 보류 가능:
- 개별 체크 승격 컬럼들

### 12-7. 상태테이블 체크 저장 원칙
- 현재 체크값은 `rc00_ops_reservation_states.check_payload_json` 에 둔다.
- `check_payload_json` 내부 키는 `snake_case` 로 고정한다.
- JSON 상세 스키마는 지금 고정하지 않는다.
- 자주 쓰는 체크만 나중에 실컬럼으로 승격한다.
- 주소 변경 / 일정 변경처럼 구조화 데이터가 필요한 값은 별도 JSON 또는 로그 payload 로 보조 저장한다.

## 13. 바로 다음 단계
1. raw import 규칙과 upsert 규칙 확정
2. 탭별 기능 리스트 확정
3. 탭별 카드 표시 항목 확정
4. 시트 수정 트리거 표 작성
5. 이후 Flutter 상태모델/리포지토리 설계 진입

## 14. 현 단계 결론
- Supabase 프로젝트 접속 및 구조 확인 완료
- Google Sheets `예약` / `일정` 탭 기본 컬럼 확인 완료
- 현재 DB는 `cars` 중심 일부 재사용 가능
- 하지만 ops 앱 전용 상태 계층은 별도로 설계해야 함
- 외부 반영은 AppSheet 직접 호출이 아니라 Google Sheets 수정 기반으로 잠근다
- 실제 시트 apply는 마지막 phase까지 금지하고 outbox dry-run만 설계한다
- 다음 확정 포인트는 시트 키 규칙, 트리거 표, 1차 DDL 보류항목 확정이다
