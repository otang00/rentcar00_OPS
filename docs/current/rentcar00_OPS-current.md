# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **현재 실행 문서**다.
지금 실제로 코딩/수정/검증 중인 액티브 작업 1건만 적는다.

## 현재 실행 작업
- Google Sheets `차량현황` 기준 latest raw import 후 1차 정리 규칙을 반영해 projection을 재구성했다.
- 이어서 `기타` 일정 반영, 일정 수정 기능, 대기차량 주차지 enum 선택 기능까지 마무리하고 빌드 준비 상태로 정리한다.

## 목적
- 현재 DB의 과거/오염 데이터를 그대로 신뢰하지 않는다.
- 최신 `차량현황` 원본을 다시 들고 와서 앱 기준 테이블을 재구성할 준비를 마친다.
- import 직후 바로 normalize 하지 않고, **애매한 값 보정 포인트를 한 번 점검**하는 흐름으로 잠근다.

## 기준점
### 원본 문서
- spreadsheet title: `차량현황`
- spreadsheet id: `1sEHaOI-zrLNzlGC8IdogQ3CidKuL4R_vFGGvFnGyGWk`
- 기준 시트: `시트1`
- 보조 시트: `예약`, `일정`

### 관련 스크립트
- raw import:
  - `tool/import_google_sheets_raw.dart`
- raw → projection 재구성:
  - `tool/normalize_raw_to_projection.dart`

### 현재 스크립트 기준 동작
#### raw import
- `rc00_ops_import_runs` 에 새 run 생성
- 아래 raw 테이블에 새 적재
  - `rc00_ops_cars_raw`
  - `rc00_ops_reservations_raw`
  - `rc00_ops_schedules_raw`
- 성공 시 row count 를 `meta_json` 에 기록

#### normalize
- 최신 run 또는 지정 run 기준으로 projection 재구성
- 시작 시 아래 projection 성격 테이블을 비운다.
  - `rc00_ops_outbox`
  - `rc00_ops_action_logs`
  - `rc00_ops_reservation_states`
  - `rc00_ops_reservations`
- 이후 raw 기준으로 아래를 다시 채운다.
  - `rc00_ops_reservations`
  - `rc00_ops_reservation_states`
  - `rc00_ops_cars`
  - `rc00_ops_schedules`

## 핵심 판단 잠금
- **raw는 먼저 살리고 projection만 갈아엎는 순서**로 간다.
- 이유:
  1. import 결과를 눈으로 검토할 근거가 남는다.
  2. 애매한 값 보정 포인트를 raw 기준으로 판단할 수 있다.
  3. projection 전체 삭제를 먼저 해버리면 비교 기준이 사라진다.

## 이번 작업에서 보는 오염 범위
### 신뢰하지 않는 현재 projection
- `rc00_ops_cars`
- `rc00_ops_reservations`
- `rc00_ops_reservation_states`
- `rc00_ops_schedules`
- `rc00_ops_outbox`
- `rc00_ops_action_logs`

### 일단 보존하는 것
- `rc00_ops_import_runs`
- `rc00_ops_cars_raw`
- `rc00_ops_reservations_raw`
- `rc00_ops_schedules_raw`

## 보정 포인트 잠금
import 직후 아래를 먼저 본다.

### 예약 raw
- `reservation_id` 비어 있는 행
- `reservation_number` 누락/중복
- `car_number` 비어 있거나 공백/형식 흔들림 있는 행
- `customer_name`, `customer_phone` 누락 행
- `start_at_raw`, `end_at_raw` 파싱 애매한 행
- `location_raw` 가 너무 길거나 의미가 섞인 행
- `status_raw` 값 종류가 normalize 규칙과 어긋나는 행

### 일정 raw
- `schedule_id` 누락 행
- `reservation_id` 비어 있지만 의도된 독립 일정인지 애매한 행
- `schedule_type_raw` 값이 `배차/반납` 외로 흔들리는 행
- `schedule_done_raw` truthy 해석이 애매한 행
- `location_raw`, `detail_text_raw` 가 fallback 의존인지 실제 원본인지 구분 필요한 행

### 차량 raw
- `car_number` 공백/중복/형식 흔들림
- `status_raw` 가 `대기/대기중/보험/일반/장기` 외 값인 행
- 고객정보/예약번호가 차량 상태와 충돌하는 행
- 세차/주차지 값 공백 또는 기존 앱 기대 형식과 다른 행

## 권장 실행 순서
### Phase 1. 최신 raw import
실행 명령 기준:
- `dart run tool/import_google_sheets_raw.dart <service-account.json> <spreadsheet-id> <db-password> [db-url]`

종료 조건:
- `rc00_ops_import_runs` latest 1건 `success`
- `car_row_count / reservation_raw_count / schedule_raw_count` 확인 가능

### Phase 2. raw 검토
확인 항목:
- counts 정상 여부
- 핵심 누락값 여부
- status/type/date 형식 흔들림 여부
- 샘플 10~20건 눈검토

종료 조건:
- 보정 대상 규칙이 짧게 잠김
- normalize 바로 돌려도 되는지 판단 가능

### Phase 3. 필요 시 보정 1회
원칙:
- 원본 시트를 직접 고치지 않고,
  우선은 raw/normalize 기준 해석 보정이 가능한지 본다.
- 원본 수정이 필요하면 별도 승인 범위로 분리한다.

종료 조건:
- 어떤 값을 어디서 보정할지 결정
  - raw 해석 보정
  - normalize 로직 보정
  - 원본 시트 수정

### Phase 4. projection 재구성
실행 명령 기준:
- `dart run tool/normalize_raw_to_projection.dart <db-password> [db-url] [sync-run-id]`

종료 조건:
- 최신 run 기준 projection 재생성 완료
- 예약/상태/차량/일정 count 확인 가능

### Phase 5. 앱 검증
확인 화면:
- 현황판 5탭
- 일정 상세
- 예약판 5탭
- 예약 상세 연결

종료 조건:
- 탭 분류/상세 진입/날짜/위치 fallback 이상 없음

## 예상 영향 범위
- 앱이 조회하는 ops projection 전체
- 현황판 / 예약판 / 일정 상세 / 예약 상세
- import 이력은 누적되지만 projection 내용은 크게 바뀔 수 있다.

## 리스크
- normalize 는 현재 실행 시 projection 테이블을 실제로 비운다.
- raw 데이터 형식이 예상과 다르면 projection 재생성 후 일부 탭이 비정상일 수 있다.
- `latest run` 기준 실행하면 의도하지 않은 run 을 잡을 수 있으므로,
  가능하면 **sync_run_id 명시 실행**이 더 안전하다.

## 실행 시 확인 원칙
- 먼저 import 결과의 `sync_run_id` 를 받는다.
- normalize 는 가능하면 그 `sync_run_id` 를 명시해서 실행한다.
- latest 자동 선택은 보조 수단으로만 쓴다.

## 검증 방법
- import stdout 확인
  - `sync_run_id`
  - 각 row count
- normalize stdout 확인
  - `normalized_sync_run_id`
  - projection count
- 필요 시 SQL count 확인
- 앱에서 탭/상세 직접 확인

## 되돌릴 방법
- import run 은 누적 기록으로 남긴다.
- projection 재구성 실패 시:
  1. 직전 정상 `sync_run_id` 확인
  2. 해당 run id 로 normalize 재실행
- raw를 지우지 않는 이유도 여기 있다.

## 상태
- 실행 준비 완료
- 아직 실제 import / normalize / 삭제는 미실행
- 다음 승인 시:
  1. raw import 실행
  2. raw 검토
  3. 보정 규칙 잠금
  4. projection 재구성
