# ARCHIVED — OPS IMS 배차중 Snapshot Diff 기반 lifecycle signal PM

> 2026-07-27 현재 기준으로 자동 lifecycle 변경 경로는 폐기한다.
> 이 문서는 구현 검토 이력 보관용이며, 운영 실행/launchd 연결/자동 배차완료/자동 반납완료 기준으로 사용하지 않는다.
> 현재 코드의 snapshot diff 산출물도 `send-events`와 OPS handoff send가 명시 차단된 상태로만 보관한다.

## 상태

- 작성일: 2026-07-26
- 상태: Archived / automatic lifecycle disabled
- 현재 기준: IMS linked 전체 상세조회 방식은 운영 기준에서 폐기한다.
- 승인 범위: snapshot diff 로컬 구현, lifecycle event POST/OPS apply 로컬 구현, 테스트, migration 파일 생성. parser restart, OPS/IMS live write 실행, launchd/cron 연결, commit/push는 미승인.

## 목적

IMS의 “현재 배차중 목록”을 일반대차와 보험대차로 나눠 snapshot 저장하고, 이전 snapshot과의 diff만 lifecycle 후보로 본다.

자동화 대상은 OPS 예약 생성이 아니다. OPS에 이미 존재하고 `rc00_ops_external_reservation_links`로 IMS와 exact binding된 예약의 배차/반납 일정 완료 신호만 준비한다.

핵심 원칙:

- 전체 IMS linked 예약을 매번 상세조회하지 않는다.
- IMS 배차중 목록의 변화분만 상세조회한다.
- `appeared`는 배차 후보, `disappeared`는 반납 후보로 본다.
- 후보 확정은 반드시 IMS detail과 OPS exact link, OPS schedule 1건 검증을 통과해야 한다.

## 현재 확인된 실제 상태

- OPS parser `/api/integrations/rentcar00/reservation-events`는 `reservation.created`와 `ims.lifecycle.*` signed event를 구분 처리하는 로컬 코드가 준비되어 있다. 운영 parser 반영은 restart 전까지 미실행이다.
- `reservation.created` 경로는 외부 provider 예약을 OPS 예약/state/배차·반납 일정으로 만들고, provider 예약은 IMS 생성 또는 exact reuse 후 link를 저장하는 방향으로 보강되어 있다.
- `reservation_ai_parser/src/ims-lifecycle-signal-worker.js`는 현재 exact-linked detail scan 형태다. 이 파일은 운영 기준에서 대체 대상이다.
- 보험배차 import는 `claimId` 기준 link를 저장하고, 생성 직후 배차 일정을 완료하며 차량 상태를 `보험`으로 유지한다.
- OPS 앱의 수동 완료 기준은 `SupabaseOpsRepository.completeSchedule()`다.

## Scope Lock

### 원래 목표

IMS 원장 lifecycle을 기준으로 OPS의 배차/반납 일정 완료 신호를 만든다.

### 승인된 작업 범위

- 일반대차/보험대차 배차중 snapshot 설계
- snapshot diff 기준 lifecycle 후보 설계
- diff 건만 detail 조회하는 검증 흐름 설계
- exact OPS link와 schedule 1건 검증 기준 정리
- 구현 Phase 재정의

### 범위 밖 항목

- remote DB migration apply
- 운영 DB insert/update/delete
- 실제 IMS 생성/삭제/반납완료 write
- 승인 없는 실제 OPS parser event POST
- parser restart
- launchd/cron 연결
- commit/push
- 과거 untyped/missing link backfill
- 차량번호/기간 기반 자동 연결

### 유혹적이지만 금지할 개선사항

- 전체 linked 예약을 주기적으로 detail 조회하는 방식
- `disappeared`만으로 반납 완료 처리
- API 조회 실패 회차의 대량 disappeared를 반납 후보로 처리
- 차량번호만으로 OPS 예약을 찾아 자동 완료
- source type 없는 과거 row를 임의 추론해 자동처리

### 완료 기준

- snapshot diff 설계가 active PM 기준으로 정리된다.
- Phase별 수정 대상과 종료조건이 명확하다.
- 구현 전 승인 필요 항목이 분리된다.

### 중단 조건

- IMS 목록 API가 배차중 목록을 안정적으로 반환하지 않음
- pagination/window 실패로 snapshot 품질을 보장할 수 없음
- diff 후보가 exact IMS link와 연결되지 않음
- OPS schedule 미완료 row가 0건 또는 복수건
- 자동 write/live apply 필요가 발생함

## IMS source 분리

| 구분 | 일반대차 | 보험대차 |
| --- | --- | --- |
| snapshot source | IMS 일반 배차중 목록 | IMS 보험 배차중 목록 |
| API 후보 | `/v2/company-car-schedules/reservations` | `/v2/rencar-claims` |
| query 기준 | IMS API가 제공하는 배차중 조건 | `periodOption=using_car` |
| snapshot key | `normal_schedule:{scheduleId}` | `insurance_claim:{claimId}` |
| detail API | `/v2/company-car-schedules/{scheduleId}` | `/v2/rencar-claims/{claimId}` |
| 배차 후보 | snapshot appeared | snapshot appeared |
| 반납 후보 | snapshot disappeared + detail `returned` | snapshot disappeared + claim `send_claim/done_claim` + 계약 return_date |
| 자동 제외 | `overdue_return`, 상태 불명, 차량 불일치 | 계약 0건/복수건, return_date 없음, 차량 불일치 |

주의:

- snapshot key는 차량번호가 아니다.
- 차량번호는 OPS 예약/차량 검증용 보조값이다.
- 목록 API 응답은 로컬에서 임의 status 필터링하지 않고 원본 기준으로 저장한다. 배차중 조건은 API query의 책임으로 둔다.

## 처리 설계

### 1. Snapshot 수집

두 목록을 별도로 수집한다.

1. 일반대차 배차중 목록
2. 보험대차 배차중 목록

각 row는 아래 정규형으로 변환한다.

- `source_type`: `normal_schedule` 또는 `insurance_claim`
- `external_id`: schedule id 또는 claim id
- `external_detail_id`: detail id 또는 claim id
- `car_number`
- `customer_name`
- `rental_at`
- `return_at`
- `raw_status`
- `raw_payload_json`
- `snapshot_seen_at`

### 2. Snapshot 품질 guard

이번 회차 snapshot이 불완전해 보이면 diff를 계산하지 않는다.

skip 조건:

- 목록 API 일부 page 실패
- 인증 실패
- pagination 중단
- 이전 active count 대비 현재 count가 비정상 급감
- source별 현재 목록이 비어 있는데 실패 여부가 불명확

이 경우:

- snapshot 저장도 보류하거나 `snapshot_invalid`로만 기록한다.
- disappeared 후보를 만들지 않는다.

### 3. Diff 계산

source별 key 기준으로 이전 active snapshot과 비교한다.

- 이전에 없고 현재 있음 → `appeared`
- 이전에 있고 현재 없음 → `disappeared_candidate`
- 이전에도 있고 현재도 있음 → `unchanged`

첫 실행은 bootstrap이다.

- 현재 목록만 저장한다.
- appeared/disappeared 신호를 만들지 않는다.

### 4. 후보 detail 조회

상세조회는 diff 후보에게만 수행한다.

배차 후보:

- `appeared`만 detail 조회
- 일반대차 detail status가 `using_car`이면 배차 후보 확정
- 보험대차 `appeared`는 import/OPS 배차 완료 여부를 먼저 확인한다. 이미 완료면 `already_applied`, 아니면 manual review

반납 후보:

- `disappeared_candidate`만 detail 조회
- 일반대차 detail status가 `returned`이면 반납 후보 확정
- 일반대차 detail status가 `overdue_return`이면 반납 아님
- 보험대차 claim이 `send_claim` 또는 `done_claim`이고, 차량번호 일치 계약 1건의 `return_date`가 있으면 반납 후보 확정

### 5. OPS exact link 확인

확정 후보는 반드시 `rc00_ops_external_reservation_links`로 연결한다.

조건:

- `provider='ims'`
- `external_status='linked'`
- `source_type` 일치
- `external_reservation_id = external_id`
- `deleted_at is null`

차량번호/기간 fallback 자동매칭은 금지한다.

### 6. OPS schedule 선택

OPS link가 1건이면 대상 예약의 schedule을 확인한다.

- 배차 신호: 미완료 `배차` schedule exactly 1건
- 반납 신호: 미완료 `반납` schedule exactly 1건

결과:

- 미완료 일정 1건 → signal 생성
- 이미 완료된 일정 있음 → `already_applied`
- 0건 → `manual_review`
- 복수건 → `manual_review`

### 7. Signal 생성

신호 type:

- `ims.lifecycle.dispatch_detected`
- `ims.lifecycle.return_detected`

event id:

```text
ims.lifecycle.{dispatch|return}:{sourceType}:{externalId}:{reservationId}:{scheduleType}
```

신호 payload에는 아래를 포함한다.

- snapshot diff kind
- IMS source type/id/detail id/status
- OPS reservation id
- OPS schedule id/type
- car number
- detail verification result
- raw payload 출력 금지 표시
- secret 출력 금지 표시

### 8. OPS 완료 command

이 PM의 최종 목표는 OPS schedule 완료까지 이어지는 구조다.

현재 로컬 구현은 OPS parser signed event receiver에서 `completeSchedule()`과 같은 핵심 정책으로 schedule/reservation/state/car/action log를 갱신한다. 실제 event POST와 parser restart는 별도 승인 전까지 실행하지 않는다.

배차 적용 정책:

- schedule done
- 예약 `배차중`
- tab `inUse`
- 차량 상태 갱신

반납 적용 정책:

- schedule done
- 예약 `완료`
- tab `completed`
- 차량 `대기중`
- action log 기록

보험 배차는 import 시 이미 완료되므로 중복 배차 완료를 다시 실행하지 않는다.

## 저장소 설계

### Snapshot table

후보:

- `rc00_ops_ims_using_car_snapshots`

필드:

- `id uuid`
- `source_type text not null`
- `external_id text not null`
- `external_detail_id text null`
- `car_number text null`
- `customer_name text null`
- `rental_at timestamptz null`
- `return_at timestamptz null`
- `raw_status text null`
- `raw_payload_json jsonb not null default '{}'::jsonb`
- `first_seen_at timestamptz not null`
- `last_seen_at timestamptz not null`
- `missing_since timestamptz null`
- `active boolean not null default true`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

unique:

- `(source_type, external_id)`

### Signal/handoff state

반복 신호 방지를 위해 event id별 terminal 상태를 저장하는 별도 저장소가 필요하다.

후보:

- `rc00_ops_ims_lifecycle_event_handoffs`

terminal:

- `applied`
- `already_applied`
- `manual_review`
- `failed_final`

transient:

- `pending`
- `sent`
- `failed`

## Phase 계획

### Phase 1. API 응답 구조 read-only 확정

목적:

- 일반대차/보험대차 배차중 목록 API의 실제 응답 구조를 확정한다.

변경점:

- 없음. read-only probe만 허용.

종료조건:

- source별 primary id 확정
- pagination/window 파라미터 확정
- 목록 응답 원본 저장 필드 확정
- detail 조회 endpoint와 상태 필드 확정

### Phase 2. Snapshot diff core 구현

목적:

- 저장 없이 목록 정규화와 diff 계산을 테스트 가능하게 만든다.

변경점:

- `reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
- `reservation_ai_parser/test/ims-using-car-snapshot-diff.test.js`

종료조건:

- fixture 기준 appeared/disappeared/unchanged/bootstrap/snapshot_invalid 테스트 통과
- detail call count가 diff 후보 수와 일치

### Phase 3. Migration 파일 생성

목적:

- snapshot 저장소와 lifecycle handoff 저장소 migration 파일을 준비한다.

변경점:

- `supabase/migrations/*_add_ims_using_car_snapshots.sql`
- `supabase/migrations/*_add_ims_lifecycle_event_handoffs.sql`

주의:

- 파일 생성까지만 허용한다.
- remote DB apply는 별도 승인 전 금지한다.

종료조건:

- SQL 파일 생성
- RLS/unique/index/constraint 기준 검토
- apply 미실행 상태 확인

### Phase 4. Snapshot save/dry-run mode 구현

목적:

- DB apply 이후 사용할 수 있는 snapshot upsert 흐름을 구현하되, write gate를 둔다.

변경점:

- `--mode report`
- `--mode save-snapshot`
- `--allowDbWrite true` 없으면 save 차단

종료조건:

- no-write report는 DB write 없이 실행
- save mode는 gate 없이 실패
- 동일 snapshot 재실행 시 중복 row를 만들지 않는 로직 테스트

### Phase 5. Diff 후보 detail verification 구현

목적:

- appeared/disappeared 후보만 detail 조회하고 signal payload를 만든다.

변경점:

- 일반대차 detail verifier
- 보험대차 detail verifier
- OPS exact link resolver
- OPS schedule selector

종료조건:

- 전체 linked detail scan 없음
- diff 후보만 detail 조회
- exact link 없으면 manual_review
- schedule 0/복수건이면 manual_review

### Phase 6. Signal 저장/전송 준비

목적:

- signal/handoff 상태 저장과 parser event handoff 준비.

변경점:

- event id 멱등
- terminal 상태 반복 전송 방지
- parser endpoint 전송은 별도 gate

종료조건:

- `allowDbWrite` 없이 저장 차단
- `allowOpsHandoffSend` 없이 POST 차단
- terminal 상태 재전송 차단 테스트

### Phase 7. 단일 canary

목적:

- 별도 승인 후 1건만 live 검증한다.

금지:

- canary 승인 전 remote DB apply/live write/event POST/parser restart 금지

종료조건:

- OPS schedule, reservation state, vehicle state, action log가 기대값과 일치
- 재실행 시 `already_applied`

## 이번 재설계로 폐기되는 기준

- OPS linked 전체를 주기적으로 detail 조회
- time window만으로 후보를 자르는 방식
- 일정 시간이 도래해야만 배차/반납 후보로 보는 방식
- `disappeared`만 보고 반납 완료하는 방식
- 차량번호/기간 fallback 자동매칭

## 다음 승인 전 준비물

1. typed IMS link가 있는 단일 canary 대상 확정
2. canary 전 parser restart 승인
3. canary 성공 후 launchd/cron 연결 여부 별도 승인
4. commit/push 여부 별도 승인

## 2026-07-26 PA local implementation evidence

변경:

- `reservation_ai_parser/src/ims-using-car-snapshot-diff.js` 추가
- `reservation_ai_parser/src/ims-api-client.js`에 배차중 목록 adapter 추가
- exact-linked 전체 detail scan worker 제거
- `reservation_ai_parser/test/ims-using-car-snapshot-diff.test.js` 추가
- snapshot/handoff migration 파일 생성

검증:

- `node --check reservation_ai_parser/src/ims-api-client.js`
- `node --check reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
- `node --check reservation_ai_parser/src/server.js`
- `node --test reservation_ai_parser/test/homepage-reservation-mapper.test.js reservation_ai_parser/test/ims-using-car-snapshot-diff.test.js`
- `save-snapshot` mode가 `allowDbWrite` 없이 차단됨
- 해당 시점에는 `allowOpsHandoffSend`가 명시 차단됨

해당 시점 미실행:

- remote DB migration apply
- 실제 IMS/OPS live write
- 실제 OPS parser event POST
- parser restart
- launchd/cron 연결
- commit/push

## 2026-07-26 launch prep status

booking-system sync-orchestrator에 `ims-using-car-snapshot-diff` launch-prep job을 추가했다.

준비 완료:

- `no-write-smoke` preview
- `save-run` preview gate
- `save-run` DB write gate
- OPS worker env override
- launchd 삽입 후보 명령 문서화

확인된 blocker:

- OPS remote DB `source_type` blocker는 2026-07-26 승인 후 migration apply로 해소됐다.
- no-write smoke는 통과했지만, 과거 IMS link는 `source_type`이 null이라 자동 신호 대상에서 제외된다.
- OPS 완료 command/event POST는 로컬 구현 완료됐고, 운영 반영은 parser restart/canary 전까지 보류한다.

## 2026-07-26 lifecycle event POST local implementation evidence

변경:

- `reservation_ai_parser/src/ops-lifecycle-event-handler.js` 추가
- OPS parser signed event receiver가 `ims.lifecycle.dispatch_detected`, `ims.lifecycle.return_detected`를 수신하도록 확장
- `ims-using-car-snapshot-diff.js`에 `send-events` mode, handoff retry/terminal 상태, HMAC POST 구현
- booking-system wrapper가 `--allowOpsHandoffSend true`일 때만 OPS worker를 `send-events` mode로 호출하도록 보강

OPS 적용 정책:

- 배차: 대상 OPS schedule `schedule_done=true`, 예약 `배차중`, state tab `rc00_ops_tab_in_use`, 차량 `일반/일정완료`, action log 기록
- 반납: 대상 OPS schedule `schedule_done=true`, 예약 `완료`, state tab `rc00_ops_tab_completed`, 차량 `대기중/반납 완료`, action log 기록
- exact link, reservation, schedule, state가 불명확하면 write 없이 `manual_review`
- 동일 event 재수신 시 schedule/state 기준으로 `already_applied`

검증:

- `node --check reservation_ai_parser/src/server.js`
- `node --check reservation_ai_parser/src/ops-lifecycle-event-handler.js`
- `node --check reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
- `node --test reservation_ai_parser/test/ops-lifecycle-event-handler.test.js reservation_ai_parser/test/ims-using-car-snapshot-diff.test.js`
- 결과: 19 passed
- booking-system `node --check scripts/sync-orchestrator/run-ims-using-car-snapshot-diff.js`
- booking-system `node --check scripts/sync-orchestrator/run-job.js`
- booking-system `node --test scripts/sync-orchestrator/__tests__/preflight.test.js scripts/sync-orchestrator/__tests__/report.test.js`
- 결과: 18 passed
- booking-system `node scripts/sync-orchestrator/run-job.js ims-using-car-snapshot-diff --mode no-write-smoke --maxPages 1`
- 결과: exitCode 0, readOnly true, writeAttempted false, currentCount 40, previousCount 15, detailCandidateCount 53, signalCount 0

미실행:

- 실제 OPS parser event POST
- parser restart
- launchd/cron 연결
- commit/push

## 2026-07-26 DB apply and no-write smoke evidence

승인 후 적용:

- `20260726121316_add_ims_lifecycle_link_source_type.sql`
- `20260726124628_add_ims_lifecycle_event_handoffs.sql`
- `20260726193000_enforce_future_unique_ims_binding.sql`

정합성 보정:

- 원격 migration history에 있던 `20260726151500_add_ims_using_car_snapshots.sql` 파일을 로컬에 복원했다.
- 중복 snapshot migration 파일은 제거했다.
- remote/local migration list가 `20260726121316`, `20260726124628`, `20260726151500`, `20260726193000` 모두 일치함을 확인했다.

검증:

- `node scripts/sync-orchestrator/run-job.js ims-using-car-snapshot-diff --mode no-write-smoke --maxPages 1`
- 결과: exitCode 0, readOnly true, writeAttempted false, currentCount 40, previousCount 15, signalCount 0
- 추가 REST read 검증: `rc00_ops_external_reservation_links.source_type` select 200, `rc00_ops_ims_lifecycle_event_handoffs` select 200

판정:

- DB blocker는 해소됐다.
- 과거 untyped IMS link는 backfill하지 않으므로 이번 smoke에서 `exact_link_not_found` manual_review가 발생한다.
- 앞으로 생성되는 typed IMS link 기준으로 lifecycle 자동 신호가 가능하다.
- 단일 canary는 현재 signalCount 0이라 미실행.
