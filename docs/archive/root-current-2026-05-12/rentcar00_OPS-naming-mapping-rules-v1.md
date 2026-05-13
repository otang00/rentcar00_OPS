# rentcar00_OPS 네이밍 · 매핑 규칙 v1

## 1. 목적
이 문서는 `rentcar00_OPS` 에서 사용할 네이밍 규칙과 시트→DB 매핑 기준을 고정한다.

기준:
- 원본 source 는 Google Sheets `예약` + `일정` 탭이다.
- OPS는 시트 예약 화면 기준으로만 설계한다.
- `booking_orders`, `ims_sync_reservations` 는 이번 앱의 source 로 쓰지 않는다.
- 다만 기존 Supabase와 연동될 때 헷갈리지 않도록, 접두를 제외한 공통 어휘는 기존 DB 스타일과 통일한다.

---

## 2. 최상위 네이밍 원칙
### 2-1. 공통 접두어
최상위 리소스명은 모두 아래 접두를 사용한다.

- `rc00_ops_`

적용 대상:
- 테이블
- 뷰
- RPC / 함수
- enum 성격 키
- 내부 상태 키

예:
- `rc00_ops_reservations`
- `rc00_ops_schedules`
- `rc00_ops_action_logs`
- `rc00_ops_tab_pending`
- `rc00_ops_action_request_delivery`

### 2-2. 컬럼명 원칙
컬럼명에는 `rc00_ops_` 접두를 반복해서 넣지 않는다.

예:
- `reservation_id`
- `reservation_number`
- `customer_phone`
- `start_at`
- `end_at`

비추천:
- `rc00_ops_reservation_id`
- `ops_customer_phone`

### 2-3. 표기 형식
- 모두 `snake_case`
- 약어 남발 금지
- 버튼/탭/체크/상태는 타입 prefix 로 구분
- 같은 의미의 명사는 한 단어로 고정

---

## 3. 공통 어휘 통일표
아래는 접두를 제외하고 OPS 내부에서 고정 사용하는 표준 어휘다.

| 의미 | 표준 이름 | 비고 |
|---|---|---|
| 예약 식별값 | `reservation_id` | 시트 `예약ID` 기준 |
| 예약번호 | `reservation_number` | 시트 `예약번호` 기준 |
| 차량 식별값 | `car_id` | 내부 참조용 |
| 차량번호 | `car_number` | 기존 `cars.car_number` 와 통일 |
| 차종명 | `car_name` | 시트 `차종` 원문/표시값 |
| 고객명 | `customer_name` | 통일 |
| 고객전화 | `customer_phone` | 통일 |
| 생년월일 | `customer_birth_date` | 날짜형/문자열형 분리 가능 |
| 소개처 | `referral_source` | `channel` 대신 이것으로 고정 |
| 결제금액 | `payment_amount` | 원문 의미 유지 |
| 원본 예약상태 | `status_raw` | 시트 `예약상태` 원문 |
| 앱 업무상태 | `status` | OPS 계산 상태 |
| 시작일시 | `start_at` | 시트 `대여일` 정규화값 |
| 종료일시 | `end_at` | 시트 `반납일` 정규화값 |
| 배차지 | `pickup_address` | 분리 저장 시 사용 |
| 반납지 | `dropoff_address` | 분리 저장 시 사용 |
| 배반차 위치 원문 | `location_raw` | 시트 `배반차위치` 원문 |
| 배차주소 | `delivery_address` | 필요 시 별도 구조화 |
| 일정 식별값 | `schedule_id` | 시트 `일정번호` 기준 |
| 일정종류 원문 | `schedule_type_raw` | 시트 `Status` 원문 |
| 일정시각 | `schedule_at` | 시트 `Date` 정규화값 |
| 일정완료 원문 | `schedule_done_raw` | 시트 `일정완료` 원문 |
| 메모/상세정보 | `detail_text` | 시트 `상세정보` |

### 3-1. 금지 혼용어
아래는 쓰지 않는다.

| 금지어 | 이유 | 대체어 |
|---|---|---|
| `user_name` | 고객 의미와 충돌 | `customer_name` |
| `user_phone` | 고객 의미와 충돌 | `customer_phone` |
| `client_*` | 용어 흔들림 | `customer_*` |
| `vehicle_*` | 기존 `car_*` 와 불일치 | `car_*` |
| `pickup_at` | OPS 내부 기준 흔들림 | `start_at` |
| `return_at` | OPS 내부 기준 흔들림 | `end_at` |
| `return_address` | 주소계 용어 흔들림 | `dropoff_address` |
| `source_status` | 기존 `status_raw` 와 불일치 | `status_raw` |
| `memo` | 범위 모호 | `detail_text` 또는 `note_text` |

---

## 4. 시트 → OPS 필드 매핑 규칙
### 4-1. 예약 탭 매핑
| 시트 컬럼 | OPS 표준 필드 | 규칙 |
|---|---|---|
| 예약ID | `reservation_id` | 원본 기준 고유키 |
| 예약번호 | `reservation_number` | 표시/검색용 보조키 |
| 차량번호 | `car_number` | `cars.car_number` 와 매칭 |
| 차종 | `car_name` | 원문 보존 |
| 대여일 | `start_at` | datetime 정규화 |
| 반납일 | `end_at` | datetime 정규화 |
| 배반차위치 | `location_raw` | 원문 그대로 저장 |
| 임차인 | `customer_name` | 원문 보존 |
| 고객번호 | `customer_phone` | 하이픈 정규화 가능 |
| 생년월일 | `customer_birth_date` | 정규화 가능 |
| 소개처 | `referral_source` | 원문 보존 |
| 결제금액 | `payment_amount` | 숫자 정규화 가능 |
| 예약상태 | `status_raw` | 원문 보존 |

### 4-2. 일정 탭 매핑
| 시트 컬럼 | OPS 표준 필드 | 규칙 |
|---|---|---|
| 일정번호 | `schedule_id` | 일정 원본키 |
| 예약번호 | `reservation_number` | 보조 연결키 |
| 차량번호 | `car_number` | 차량 매칭 |
| Status | `schedule_type_raw` | 원문 보존 |
| Date | `schedule_at` | datetime 정규화 |
| 차종 | `car_name` | 예약 탭과 동일 어휘 사용 |
| 위치 | `location_raw` | 원문 보존 |
| 상세정보 | `detail_text` | 원문 보존 |
| 가반납 | `partial_return_raw` | 원문 보존 |
| 예약ID | `reservation_id` | 1차 연결키 |
| 일정완료 | `schedule_done_raw` | 원문 보존 |

### 4-3. 차량 마스터 연동
유일한 강한 연결 기준:
- `car_number` ↔ `cars.car_number`

보조 비교값:
- `car_name`

원칙:
- OPS raw source 는 시트다.
- `*_raw` 는 import 원본 보존 전용이다.
- raw 없는 이름은 앱이 실제로 읽고 쓰는 운영 테이블이다.
- 차량 마스터 참조는 기존 `cars` 를 재사용한다.
- 예약 source 를 기존 예약 테이블로 바꾸지 않는다.

---

## 5. 리소스명 규칙
### 5-1. 테이블
#### RAW
- `rc00_ops_import_runs`
- `rc00_ops_cars_raw`
- `rc00_ops_reservations_raw`
- `rc00_ops_schedules_raw`

#### OPS
- `rc00_ops_cars`
- `rc00_ops_reservations`
- `rc00_ops_schedules`
- `rc00_ops_reservation_states`
- `rc00_ops_action_logs`
- `rc00_ops_outbox`

### 5-2. 뷰
- `rc00_ops_reservation_cards`
- `rc00_ops_tab_counts`
- `rc00_ops_today_pickups`
- `rc00_ops_today_returns`

### 5-3. 함수 / RPC
- `rc00_ops_sync_sheet_reservations`
- `rc00_ops_sync_sheet_schedules`
- `rc00_ops_rebuild_tab_status`
- `rc00_ops_complete_return`

---

## 6. 탭 키 규칙
탭은 모두 아래 형식으로 고정한다.

- `rc00_ops_tab_<name>`

확정 키:
- `rc00_ops_tab_pending`
- `rc00_ops_tab_pickup_today`
- `rc00_ops_tab_in_use`
- `rc00_ops_tab_return_due`
- `rc00_ops_tab_completed`

탭명 대응:
- 예약중 → `rc00_ops_tab_pending`
- 오늘배차 → `rc00_ops_tab_pickup_today`
- 배차중 → `rc00_ops_tab_in_use`
- 반납일 → `rc00_ops_tab_return_due`
- 완료 → `rc00_ops_tab_completed`

원칙:
- 탭 키는 OPS 내부 계산 상태다.
- 시트 `예약상태` 원문을 그대로 탭 키로 쓰지 않는다.
- 완료 탭은 조회용이며, 반납완료 후 7일까지만 기본 노출 대상으로 본다.

탭 강조 규칙:
- `rc00_ops_tab_pickup_today`: 준비 미완료면 주황 경고
- `rc00_ops_tab_in_use`: 반납일이 내일이면 노랑 경고

---

## 7. 액션 키 규칙
형식:
- `rc00_ops_action_<verb>_<object>`

### 7-1. 예약중
- `rc00_ops_action_save_customer_phone`
- `rc00_ops_action_request_id_address`
- `rc00_ops_action_check_id`
- `rc00_ops_action_check_address`
- `rc00_ops_action_mark_pickup_ready`

### 7-2. 오늘배차
- `rc00_ops_action_call_customer`
- `rc00_ops_action_send_pickup_notice`
- `rc00_ops_action_request_delivery`
- `rc00_ops_action_contact_delivery_driver`
- `rc00_ops_action_create_contract`
- `rc00_ops_action_send_signature_notice`
- `rc00_ops_action_confirm_dispatch_start`

### 7-3. 배차중
- `rc00_ops_action_call_customer`
- `rc00_ops_action_check_signature`
- `rc00_ops_action_send_return_notice`
- `rc00_ops_action_change_end_at`
- `rc00_ops_action_send_emergency_notice`
- `rc00_ops_action_report_accident`

### 7-4. 반납일
- `rc00_ops_action_send_return_notice`
- `rc00_ops_action_request_delivery`
- `rc00_ops_action_change_dropoff_address`
- `rc00_ops_action_send_extension_fee_notice`
- `rc00_ops_action_complete_return`

원칙:
- 버튼은 실행 키다.
- 버튼 키에 `done`, `completed`, `checked` 를 넣지 않는다.

---

## 8. 체크 키 규칙
형식:
- `rc00_ops_check_<object>_<result>`

확정 키:
- `rc00_ops_check_id_verified`
- `rc00_ops_check_address_verified`
- `rc00_ops_check_pickup_ready`
- `rc00_ops_check_pickup_notice_sent`
- `rc00_ops_check_delivery_requested`
- `rc00_ops_check_contract_created`
- `rc00_ops_check_signature_notice_sent`
- `rc00_ops_check_dispatch_started`
- `rc00_ops_check_signature_verified`
- `rc00_ops_check_return_notice_sent`
- `rc00_ops_check_end_at_changed`
- `rc00_ops_check_emergency_notice_sent`
- `rc00_ops_check_accident_reported`
- `rc00_ops_check_dropoff_address_changed`
- `rc00_ops_check_extension_fee_notice_sent`
- `rc00_ops_check_return_completed`

원칙:
- 체크 키는 완료 판정용이다.
- 버튼 클릭과 체크 완료를 같은 키로 합치지 않는다.

---

## 9. 상태값 규칙
형식:
- `rc00_ops_status_<value>`

공통 원칙:
- `status` 는 예약의 현재 업무 단계를 표현한다.
- 액션 실행 이력은 `action_logs` 로 분리한다.
- 완료 체크 현재값은 `check_payload_json` 으로 분리한다.
- `send`, `request`, `assign`, `check` 같은 동작어를 상태값으로 남발하지 않는다.
- `clicked`, `pressed` 같은 UI 이벤트 단어는 상태값으로 쓰지 않는다.

탭별 확정 값:
### 예약중
- `rc00_ops_status_pending`
- `rc00_ops_status_waiting_for_id`
- `rc00_ops_status_waiting_for_address`
- `rc00_ops_status_ready`
- `rc00_ops_status_hold`

### 오늘배차
- `rc00_ops_status_pending`
- `rc00_ops_status_ready_for_dispatch`
- `rc00_ops_status_dispatch_prepared`
- `rc00_ops_status_dispatch_in_progress`
- `rc00_ops_status_pickup_completed`
- `rc00_ops_status_hold`

해석 고정:
- `rc00_ops_status_ready_for_dispatch`: 오늘배차 탭 진입은 했지만 준비 미완료가 남아 있는 상태
- `rc00_ops_status_dispatch_prepared`: 배차안내/탁송요청/계약 관련 준비가 끝난 상태
- `rc00_ops_status_dispatch_in_progress`: 실제 출발 확인값이 잡힌 상태
- `rc00_ops_status_pickup_completed`: 고객 인수 확인까지 끝났으나 탭 재계산 전 과도 상태

### 배차중
- `rc00_ops_status_in_use`
- `rc00_ops_status_return_preparing`
- `rc00_ops_status_extension_review`
- `rc00_ops_status_issue_handling`
- `rc00_ops_status_hold`

### 반납일
- `rc00_ops_status_return_due`
- `rc00_ops_status_return_in_progress`
- `rc00_ops_status_settlement_needed`
- `rc00_ops_status_return_completed`
- `rc00_ops_status_hold`

### 완료
- `rc00_ops_status_done`

---

## 10. 컬럼 네이밍 세부 규칙
### 10-1. 식별자
- 단일 PK: `id`
- 외부 예약키: `reservation_id`
- 외부 일정키: `schedule_id`
- 참조키: `<entity>_id`

### 10-2. 날짜/시간
- 시각: `*_at`
- 날짜만: `*_date`
- 마지막 동기화: `synced_at`
- 마지막 처리: `processed_at`

### 10-3. 원문 보존값
- 원문 상태: `status_raw`
- 원문 위치: `location_raw`
- 원문 일정타입: `schedule_type_raw`
- 원문 완료값: `schedule_done_raw`
- 원문 부분반납값: `partial_return_raw`

### 10-4. 불리언 / 확인값
- 단순 여부: `is_*` / `has_*` 가능
- 체크 엔티티 키는 `rc00_ops_check_*`
- 컬럼은 의미 중심으로 작성

예:
- `is_cancelled`
- `is_completed`
- `has_issue`
- `signature_verified_at`

---

## 11. 혼선 방지 규칙
1. source 는 시트다.
2. 차량 참조만 기존 `cars` 와 강하게 연결한다.
3. 기존 예약 테이블명을 새 OPS 테이블/컬럼명에 끌어오지 않는다.
4. OPS 내부 시간 필드는 `start_at`, `end_at` 로 고정한다.
5. 고객 관련 명사는 전부 `customer_*` 로 통일한다.
6. 차량 관련 명사는 전부 `car_*` 로 통일한다.
7. 주소는 `pickup_address`, `dropoff_address`, `delivery_address` 만 사용한다.
8. 원문값은 `*_raw`, 계산값은 접미어 없이 표준 필드명으로 쓴다.
9. 탭/액션/체크/상태는 서로 다른 prefix 체계로 분리한다.

---

## 12. 원본 → 내부 → 시트 반영 최소 규칙
### 12-1. 원본 보존
- 시트 원문은 raw 계층에 그대로 둔다.
- 정규화된 값이 있어도 `*_raw` 를 함께 유지한다.

### 12-2. 내부 계산
- 앱 탭 상태는 `reservation_states.tab_key` 를 기준으로 본다.
- 앱 세부 상태는 `reservation_states.status` 를 기준으로 본다.
- 현재 체크값은 `reservation_states` 에 둔다.
- 액션 결과는 `action_key + status` 로 기록한다.
- 완료 판정 키는 `check_key` 체계를 유지하되, 현재값 저장 위치는 상태테이블이다.

### 12-3. 시트 반영
- 시트로 되돌려 쓰는 값은 최소 체크만 대상으로 한다.
- 세부 로그/문자 발송 이력/실패 메모는 시트로 밀어넣지 않는다.

## 13. 최종 결론
이번 OPS 네이밍 규칙은 아래로 고정한다.

- 최상위 접두: `rc00_ops_`
- 공통 명사: 기존 DB 스타일과 통일
- source 기준: Google Sheets `예약` + `일정`
- 차량 연결 기준: `car_number`
- 내부 시간 기준: `start_at`, `end_at`
- 상태 source of truth: `rc00_ops_reservation_states`
- 내부 탭 키: `rc00_ops_tab_*`
- 버튼 키: `rc00_ops_action_*`
- 완료 체크 키: `rc00_ops_check_*`
- 상태값: `rc00_ops_status_*`
- 실제 출발 확인 체크: `rc00_ops_action_confirm_dispatch_start` + `rc00_ops_check_dispatch_started`

이 문서 이후 실제 스키마/코드 작성 시, 새 이름은 이 규칙을 벗어나면 안 된다.
