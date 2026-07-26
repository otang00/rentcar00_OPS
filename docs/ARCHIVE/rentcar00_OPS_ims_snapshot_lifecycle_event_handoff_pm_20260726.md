# ARCHIVED — IMS Snapshot Lifecycle Event Handoff PM

> 2026-07-26 신규예약 오케스트레이션 재설계에서 자동 lifecycle 변경 경로를 폐기해 보관한다.

## 0. 문서 정보
- 작성일: 2026-07-26
- 작성자/agent: OpenClaw rentcar00_reservation_developer
- 상태: Draft
- 승인 범위: 구현 준비 문서 작성. 실행/DB 변경/launchd 연결/배포/커밋은 별도 승인 필요.
- 관련 문서:
  - `docs/PHASE/rentcar00_OPS_ims_using_car_snapshot_diff_lifecycle_signal_pm_20260726.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
- 관련 코드:
  - OPS parser: `reservation_ai_parser/src/server.js`
  - snapshot watcher: `reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
  - existing sender: booking-system `server/notifications/sendOpsAppReservationEvent.js`
  - orchestrator: booking-system `scripts/sync-orchestrator/*`
- 완료 후 문서명: `docs/COMPLETED/rentcar00_OPS_ims_snapshot_lifecycle_event_handoff_COMPLETE_20260726.md`
- 상태/정책문서 업데이트 대상:
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - 필요 시 `docs/COMPLETED/rentcar00_OPS-completed.md`

## 1. 목적
- 목표:
  - IMS 배차중 목록 snapshot diff에서 감지한 `appeared/disappeared`를 기존 OPS 자동 신호 구조와 같은 방식으로 OPS parser에 HMAC POST한다.
  - OPS parser는 새 lifecycle event를 받아 기존 OPS 배차완료/반납완료와 같은 DB 상태 변경을 수행한다.
- 성공 기준:
  - launchd/orchestrator 실행 시 IMS 배차중 변화가 있으면 OPS parser endpoint로 lifecycle event가 전송된다.
  - parser는 event를 idempotent 저장하고, 대상 예약의 배차/반납 일정을 완료 처리한다.
  - 배차 시 예약 상태/탭/차량 상태가 기존 `completeSchedule(배차)`와 동일하게 바뀐다.
  - 반납 시 예약 상태/탭/차량 상태가 기존 `completeSchedule(반납)`와 동일하게 바뀐다.
  - 중복 event 재수신 시 DB 상태가 중복 변경되지 않는다.
  - parser 응답의 `applied/already_applied/manual_review/failed` 결과를 sender가 기록하고, 성공/이미처리 응답 이후 같은 lifecycle event를 반복 전송하지 않는다.
- 제외 범위:
  - OPS 앱 UI 추가 표시.
  - 수동 버튼 UX 변경.
  - IMS에 반납완료를 역으로 쓰는 기능.
  - launchd 실제 자동 연결/재시작은 최종 별도 승인 전까지 제외.

## 2. 현재 상태
- 확인한 파일/docs:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
  - `server/notifications/sendOpsAppReservationEvent.js`
  - `scripts/external-reservation-import/run-import-provider-reservations.js`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
- 현재 git 상태:
  - OPS repo에는 기존 미완료 변경이 있음.
  - booking-system repo에도 orchestrator 관련 미완료 변경이 있음.
  - 따라서 phase 실행 전 dirty file 범위 재확인 필요.
- 기존 구현/문서 상태:
  - 기존 자동 신호 구조는 booking-system에서 OPS parser `/api/integrations/rentcar00/reservation-events`로 HMAC POST한다.
  - OPS parser는 `rc00_ops_reservation_events`에 event를 저장하고 예약 생성 event를 처리한다.
  - OPS 앱의 배차/반납 완료 로직은 `SupabaseOpsRepository.completeSchedule()`에 있다.
  - 현재 snapshot watcher는 `rc00_ops_action_logs`에 `ims.snapshot.*` 신호를 저장하지만, 이것은 최종 처리 경로가 아니다.
- 확인 필요:
  - `rc00_ops_reservation_events.event_type`에 새 lifecycle type 저장이 문제 없는지.
  - parser에서 event type별 분기 구조를 기존 예약 생성 event와 충돌 없이 확장할 수 있는지.
  - 보험/일반 배차 완료 시 차량 상태 정책을 동일하게 `일반`으로 할지, 보험 claim이면 `보험` 보존할지.

## 3. 전체 변경 요약
- 변경점:
  - snapshot watcher의 확정 후보를 action log 저장이 아니라 OPS parser event POST payload로 변환한다.
  - 기존 HMAC sender 구조를 재사용하거나 공통화한다.
  - OPS parser에 lifecycle event type 수신/처리 분기를 추가한다.
  - parser 서버 쪽에 기존 `completeSchedule()`과 동일한 DB update 함수를 구현한다.
- 변경대상:
  - booking-system:
    - `server/notifications/sendOpsAppReservationEvent.js` 또는 별도 lifecycle sender
    - `scripts/sync-orchestrator/run-ims-using-car-snapshot-diff.js`
    - `scripts/sync-orchestrator/run-job.js`
    - 테스트
  - OPS repo:
    - `reservation_ai_parser/src/server.js`
    - `reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
    - 테스트
    - 관련 docs
- 예상 영향:
  - 배차/반납 상태가 외부 IMS 상태를 기준으로 자동 반영될 수 있다.
  - 잘못 매칭되면 실제 OPS 예약/차량 상태가 바뀐다.
- 주요 리스크:
  - 중복 event로 일정 완료가 반복 적용되는 문제.
  - 차량번호/window 복수 매칭 문제.
  - 보험 claim 배차의 차량 상태 정책 오류.
  - 반납 감지 시 사라짐이 IMS API 누락인지 실제 반납인지 오판.

## 3-A. 처리 책임과 반복신호 제어 기준

### 3-A.1 처리 책임
- orchestrator/watcher 책임:
  - IMS 배차중 snapshot diff 감지.
  - 변경 후보 상세조회.
  - OPS 예약/일정 단일 매칭.
  - lifecycle event HMAC POST.
  - parser 응답 수신 후 전송/처리 결과 기록.
- OPS parser 책임:
  - HMAC 검증.
  - `rc00_ops_reservation_events`에 event idempotent 저장.
  - 배차완료/반납완료 DB 변경 적용.
  - 처리 결과를 응답으로 반환.
  - 이미 처리된 event/schedule은 `already_applied`로 응답.
- OPS 앱 책임:
  - 이 자동 lifecycle event를 직접 소비하지 않는다.
  - 기존 수동 버튼 흐름은 유지한다.

### 3-A.2 event id / dedupe key
- event id는 같은 lifecycle 사실에 대해 항상 동일해야 한다.
- 후보 형식:
  - `ims.lifecycle.dispatch_detected:<sourceType>:<externalId>:<reservationId>`
  - `ims.lifecycle.return_detected:<sourceType>:<externalId>:<reservationId>`
- `rc00_ops_reservation_events.event_id unique`가 receiver 1차 중복 방지다.
- sender도 동일 event id의 성공/이미처리 결과를 기억해 재전송하지 않는다.

### 3-A.3 parser 응답 contract
parser는 lifecycle event 처리 후 아래 상태 중 하나를 반환한다.

- `applied`
  - 이번 요청으로 DB 상태 변경 완료.
  - sender는 해당 event를 완료 처리하고 반복 전송 중지.
- `already_applied`
  - event 중복이거나 대상 schedule이 이미 완료 상태.
  - sender는 성공과 동일하게 반복 전송 중지.
- `manual_review`
  - 대상 예약/일정 0건, 복수 매칭, 상태 불일치, 정책 미확정.
  - sender는 자동 재시도하지 않고 수동확인 상태로 기록.
- `failed`
  - 일시 오류 가능성이 있는 처리 실패.
  - sender는 제한된 재시도 정책을 따른다.

응답 payload 후보:

```json
{
  "ok": true,
  "eventId": "ims.lifecycle.dispatch_detected:normal_schedule:4400181:R-1785042394296-UU77ELFK",
  "eventType": "ims.lifecycle.dispatch_detected",
  "status": "applied",
  "deduped": false,
  "reservationId": "R-1785042394296-UU77ELFK",
  "scheduleId": "<rc00_ops_schedules.id>",
  "scheduleType": "배차",
  "carNumber": "29하2763",
  "ops": {
    "scheduleDone": true,
    "reservationStatus": "배차중",
    "tabKey": "inUse"
  }
}
```

### 3-A.4 sender 상태 기록 후보
- 기존 snapshot/action log만으로는 “parser 적용 완료” 상태를 안정적으로 추적하기 어렵다.
- 후보 A: `rc00_ops_ims_using_car_snapshots.raw_payload_json` 또는 별도 metadata에 마지막 handoff 결과 저장.
  - 장점: 신규 테이블 없음.
  - 단점: snapshot row와 event 전송 이력이 섞임.
- 후보 B: 신규 lifecycle handoff 상태 테이블 생성.
  - 후보명: `rc00_ops_ims_lifecycle_event_handoffs`
  - 주요 필드:
    - `event_id text unique`
    - `event_type text`
    - `source_type text`
    - `external_id text`
    - `reservation_id text`
    - `schedule_id uuid null`
    - `car_number text`
    - `send_status text`: `pending/sent/applied/already_applied/manual_review/failed/failed_final`
    - `attempt_count int`
    - `last_attempt_at timestamptz`
    - `next_attempt_at timestamptz null`
    - `response_json jsonb`
    - `error_message text null`
  - 장점: 반복신호 제어와 운영 추적이 명확함.
  - 단점: DB migration 필요.
- 권장: 후보 B. 자동 적용 기능이므로 전송/적용 이력은 snapshot과 분리한다.

### 3-A.5 반복 전송 중지/재시도 정책
- 반복 전송 중지:
  - parser 응답 `applied`.
  - parser 응답 `already_applied`.
  - parser 응답 `manual_review`.
- 재시도 허용:
  - 네트워크 오류.
  - parser 5xx.
  - parser 응답 `failed` 중 일시 오류로 분류된 경우.
- 재시도 제한:
  - exponential backoff.
  - 최대 3회 우선.
  - 3회 실패 후 `manual_review` 또는 `failed_final`로 고정하고 반복 중지.
- 재전송 금지:
  - 매칭 0건/복수건.
  - 이미 OPS 상태가 기대와 반대로 진행된 경우.
  - 보험/일반 차량 상태 정책이 확정되지 않은 경우.

## 4. Phase 목록

### Phase 1. 기존 reservation event contract 확장 설계
- 목적:
  - 기존 `/api/integrations/rentcar00/reservation-events`를 유지하면서 lifecycle event type을 안전하게 추가한다.
- 변경점:
  - event type 후보 확정:
    - `ims.lifecycle.dispatch_detected`
    - `ims.lifecycle.return_detected`
  - payload schema 확정:
    - `eventId`
    - `eventType`
    - `occurredAt`
    - `source`
    - `ims.sourceType`
    - `ims.externalId`
    - `ims.externalDetailId`
    - `ims.status`
    - `ops.reservationId`
    - `ops.scheduleType`
    - `car.carNumber`
    - `reason`
  - parser response schema 확정:
    - `status`: `applied/already_applied/manual_review/failed`
    - `deduped`
    - `reservationId`
    - `scheduleId`
    - `scheduleType`
    - `carNumber`
    - `ops` 변경 결과 요약
- 변경대상:
  - 문서/테스트 fixture 우선.
- 실행방법:
  - 현재 parser의 `normalizeReservationEventPayload()`와 저장 로직을 읽고, 새 event payload가 기존 검증을 통과하도록 최소 확장안을 만든다.
- 종료조건:
  - 새 lifecycle payload sample 2개가 정의된다.
- 검증방법:
  - unit test로 payload normalization만 검증.
- 리스크:
  - 기존 reservation.created payload와 필수값 충돌.
- 되돌릴 방법:
  - 새 event type 분기와 fixture 제거.
- 출력보고:
  - 확정 event type, 필수 payload, dedupe key, ack/result contract 보고.

### Phase 2. OPS parser lifecycle event 수신/저장 분기
- 목적:
  - parser endpoint가 lifecycle event를 받아 `rc00_ops_reservation_events`에 idempotent 저장한다.
- 변경점:
  - event type별 validation 분리.
  - 기존 `reservation.created` 처리와 lifecycle 처리 분리.
  - 동일 `eventId` 재수신 시 deduped 처리.
  - 처리 결과를 `applied/already_applied/manual_review/failed`로 응답.
- 변경대상:
  - `reservation_ai_parser/src/server.js`
  - parser tests
- 실행방법:
  - `receiveRentcar00ReservationEvent()` 근처에 lifecycle 분기 추가.
- 종료조건:
  - lifecycle event POST가 저장되고 중복 POST가 deduped/already_applied로 응답된다.
- 검증방법:
  - unit/integration style test 또는 local function test.
  - DB write는 테스트 fixture 또는 승인된 개발 DB에 한정.
- 리스크:
  - 기존 홈페이지 예약 event 수신 regression.
- 되돌릴 방법:
  - lifecycle 분기 제거.
- 출력보고:
  - 저장 row status/event_type/deduped/ack result.

### Phase 3. parser 서버 쪽 OPS 배차/반납 적용 함수 구현
- 목적:
  - 기존 앱 `completeSchedule()`과 같은 DB 변경을 server.js에서 수행한다.
- 변경점:
  - dispatch apply:
    - 대상 예약의 미완료 `배차` schedule 찾기.
    - `schedule_done=true`.
    - reservation status `배차중`.
    - reservation state tab `inUse`.
    - 차량 상태/고객/기간 정보 업데이트.
    - `schedule.complete_dispatch` action log 기록.
  - return apply:
    - 대상 예약의 미완료 `반납` schedule 찾기.
    - `schedule_done=true`.
    - reservation status `완료`.
    - reservation state tab `completed`.
    - 차량 `대기중`, 세차 flags, 주차 위치 등 기존 reset 정책 적용.
    - `schedule.complete_return` action log 기록.
- 변경대상:
  - `reservation_ai_parser/src/server.js`
  - tests
- 실행방법:
  - 기존 Dart `SupabaseOpsRepository.completeSchedule()`을 기준으로 Node 함수로 동일 구현.
  - 이미 완료된 schedule이면 no-op/deduped로 처리.
- 종료조건:
  - 배차/반납 각각 정상 적용/중복 적용 방지 테스트 통과.
- 검증방법:
  - read-only precheck.
  - 승인된 단일 테스트 예약으로 dry-run 또는 dev DB apply.
  - DB row diff 확인.
- 리스크:
  - 운영 DB 실제 상태 변경.
  - 반납 처리 시 차량 상태 reset 정책이 운영 기대와 다를 수 있음.
- 되돌릴 방법:
  - 적용 전 row snapshot 확보.
  - 해당 schedule/reservation/car/action_log 수동 복구 SQL 준비.
- 출력보고:
  - 변경된 schedule/reservation/state/car/log row 요약.

### Phase 4. snapshot watcher → OPS lifecycle event sender 연결
- 목적:
  - snapshot diff 확정 후보를 기존 OPS HMAC event sender 방식으로 parser에 전송한다.
- 변경점:
  - `ims-using-car-snapshot-diff`에 send mode 또는 sender 함수 추가.
  - action log 저장은 보조 감사 로그로 낮추거나 제거 후보로 정리.
  - 중복 event id 생성:
    - `ims.lifecycle.dispatch_detected:<sourceType>:<externalId>:<reservationId>`
    - `ims.lifecycle.return_detected:<sourceType>:<externalId>:<reservationId>`
  - parser 응답 결과를 기록하고 `applied/already_applied/manual_review` 이후 재전송 금지.
  - `failed`는 backoff/attempt limit 이후 중지.
- 변경대상:
  - `reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
  - booking-system sender 재사용 파일 또는 별도 sender
  - orchestrator runner
- 실행방법:
  - 기존 `sendOpsAppReservationEvent()` HMAC 서명/POST 로직과 동일한 방식 적용.
- 종료조건:
  - appeared 후보 1건이 parser로 POST되고 parser apply 결과가 반환되며, 다음 run에서 같은 event가 재전송되지 않는다.
- 검증방법:
  - preview: payload만 출력.
  - live: 단일 `29하2763` 배차 테스트 후 event 전송.
- 리스크:
  - 잘못된 event가 즉시 OPS 상태 변경으로 이어짐.
- 되돌릴 방법:
  - send mode gate off.
  - 해당 row 복구.
- 출력보고:
  - sent/failed/deduped/applied/already_applied/manual_review count와 반복중지 대상.

### Phase 4-A. lifecycle handoff 상태 저장소 확정
- 목적:
  - sender가 parser의 완료 피드백을 기억하고 반복 신호를 멈출 수 있게 한다.
- 변경점:
  - 권장 신규 테이블 `rc00_ops_ims_lifecycle_event_handoffs` 설계/마이그레이션.
  - 또는 snapshot metadata 저장 대안 확정.
- 변경대상:
  - `supabase/migrations/*` 후보.
  - `reservation_ai_parser/src/ims-using-car-snapshot-diff.js` 또는 booking-system sender.
- 실행방법:
  - Phase 1~4 구현 전 최종 저장 방식 확정.
  - 신규 테이블 선택 시 DB migration은 별도 승인 후 적용.
- 종료조건:
  - 같은 eventId의 상태 조회로 전송 여부를 결정할 수 있다.
- 검증방법:
  - `applied` 기록 후 같은 후보 재실행 시 POST skip.
  - `failed` 기록 후 attempt/backoff 동작 확인.
- 리스크:
  - 신규 DB table 추가.
  - sender 상태와 parser `rc00_ops_reservation_events` 상태가 불일치할 수 있음.
- 되돌릴 방법:
  - 신규 table 미사용/삭제 migration 후보.
  - sender 상태 체크 제거.
- 출력보고:
  - 선택한 저장소, eventId별 상태 전이, 재전송 중지 기준.

### Phase 5. orchestrator gate 및 launchd 연결 준비
- 목적:
  - 자동 실행 전 수동 검증 가능한 gate를 둔다.
- 변경점:
  - save/apply mode는 아래 조건이 모두 true일 때만 허용:
    - `ORCHESTRATOR_ENABLE_WRITE=true`
    - `OPS_HANDOFF_SEND_ENABLED=true`
    - 명령 인자 `--allowOpsHandoffSend true`
  - launchd 연결용 run_step 준비.
- 변경대상:
  - booking-system `scripts/sync-orchestrator/*`
  - `run-launchd.sh`는 최종 승인 전 수정 금지.
- 실행방법:
  - preview → read-only → single live candidate → gated send 순서.
- 종료조건:
  - 기본 상태에서는 차단.
  - 승인 env/arg 조합에서만 전송 가능.
- 검증방법:
  - preflight test.
  - orchestrator test.
- 리스크:
  - gate 설정 오류로 자동 적용이 열릴 수 있음.
- 되돌릴 방법:
  - job registration 제거 또는 env gate off.
- 출력보고:
  - gate 상태와 launchd 연결 명령.

### Final Phase. 검수·완료판정·상태/정책문서 정리·문서 COMPLETE 변경·커밋
- 목적:
  - 구현 완료 여부를 검수하고 문서/커밋 기준을 맞춘다.
- 변경점:
  - 전체 변경 검수.
  - 완료판정.
  - 상태변경/정책변경 여부 판단.
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`, `docs/HARNESS/CURRENT_STATE_MAP.md` 업데이트.
  - PM 문서를 완료 위치로 이동 또는 이름 변경.
  - 파일명에 `COMPLETE_20260726` 반영.
  - 최종 커밋.
- 변경대상:
  - 구현 파일.
  - 테스트 파일.
  - docs.
- 실행방법:
  - diff review → tests → DB single-case verification → docs update → commit.
- 종료조건:
  - 계획 phase 완료.
  - 검증 통과.
  - 문서 최신화.
  - 커밋 완료 또는 커밋 제외 사유 기록.
- 검증방법:
  - node tests.
  - parser event fixture test.
  - single live reservation verification.
- 리스크:
  - live 검증 대상 상태가 이미 변경되어 재현 안 될 수 있음.
- 되돌릴 방법:
  - 커밋 전 diff revert.
  - DB 변경분은 준비한 복구 SQL로 되돌림.
- 출력보고:
  - 변경 파일, 검증 결과, 완료 문서 경로, 커밋 해시/제외 사유.

## 5. 승인 및 중단 조건
- 승인 요청:
  - Phase 1부터 순차 진행 승인 필요.
  - DB 상태 변경이 발생하는 Phase 3 이후 live apply는 단일 테스트 예약 기준으로 별도 승인 필요.
  - launchd 실제 연결은 Final 전 별도 승인 필요.
- 중단 조건:
  - lifecycle event가 기존 `reservation.created` 검증과 충돌.
  - 대상 예약/일정이 0건 또는 복수건으로 매칭.
  - 이미 완료된 일정인데 상태가 불일치.
  - 보험/일반 차량 상태 정책이 확정되지 않음.
  - parser endpoint auth/HMAC 검증 실패.
- protected target 별도 승인 필요 여부:
  - env/secret 수정 금지.
  - launchd/restart/deploy 금지.
  - 운영 DB apply는 phase별 명시 승인 필요.

## 6. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- 완료 문서 경로:
- 상태/정책문서 업데이트:
- 커밋:
- 남은 리스크:
