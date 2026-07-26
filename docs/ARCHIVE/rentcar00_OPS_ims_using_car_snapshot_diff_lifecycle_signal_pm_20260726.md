# ARCHIVED — IMS 배차중 목록 Snapshot Diff 기반 배차/반납 신호 PM

> 2026-07-26 신규예약 오케스트레이션 재설계에서 자동 lifecycle 변경 경로를 폐기해 보관한다.

## 0. 문서 정보
- 작성일: 2026-07-26
- 상태: Draft
- 목적: IMS linked 예약 전체를 매번 상세조회하지 않고, IMS 배차중 목록의 변화분만 후보 상세조회하여 OPS에 배차/반납 신호를 저장하는 구현 준비 문서
- 문서 위치: `docs/PHASE/rentcar00_OPS_ims_using_car_snapshot_diff_lifecycle_signal_pm_20260726.md`
- 완료 후 이동 후보: `docs/COMPLETED/rentcar00_OPS_ims_using_car_snapshot_diff_lifecycle_signal_COMPLETE_20260726.md`

## 1. 배경
현재 구현된 `ims-linked-lifecycle-watcher`는 OPS에 IMS link가 있는 예약을 기준으로 IMS schedule detail을 조회한다.

확인된 문제:
- 전체 linked 약 205건을 매번 상세조회하면 부하가 크다.
- 2일 전~2일 후 window로 줄여도 1회 약 28건 상세조회가 필요하다.
- 실제 감지 목적은 “배차중 목록에 새로 생겼는지 / 사라졌는지”이므로 전체 상세조회가 비효율적이다.

새 기준:
- IMS 배차중 목록을 주기적으로 조회한다.
- 이전 snapshot과 비교한다.
- 새로 생긴 항목만 배차 후보로 본다.
- 사라진 항목만 반납 후보로 본다.
- 후보만 상세조회 또는 보조조회로 확정한다.
- 확정된 신호만 OPS action log에 중복 없이 저장한다.

## 2. 대상 범위
조회 대상은 두 갈래다.

### 2.1 보험 배차중
- API 후보: `GET /v2/rencar-claims`
- 기준:
  - `periodOption=using_car`
  - window start/end
  - 필요 시 차량번호 필터 없이 전체 조회
- 기존 코드 참고:
  - `reservation_ai_parser/src/server.js`
  - `searchImsInsuranceClaimsForDispatch()`

### 2.2 일반 예약 배차중
- API 후보:
  - `GET /v2/company-car-schedules/reservations`
  - 또는 `GET /v2/company-car-schedules`
- 기준:
  - window start/end
  - status/상태가 `using_car` 또는 이에 대응하는 값
- 기존 코드 참고:
  - `findImsReservationsBySearchApi()`
  - `fetchImsScheduleDetail()`

## 3. 핵심 설계

### 3.1 Snapshot 저장
신규 snapshot 저장소를 둔다.

후보 테이블명:
- `rc00_ops_ims_using_car_snapshots`

필드 후보:
- `id uuid`
- `source_type text` : `insurance_claim` / `normal_schedule`
- `external_id text` : claim id 또는 schedule id
- `external_detail_id text null`
- `car_number text`
- `customer_name text null`
- `rental_at timestamptz null`
- `return_at timestamptz null`
- `raw_status text null`
- `raw_payload_json jsonb`
- `snapshot_seen_at timestamptz`
- `first_seen_at timestamptz`
- `last_seen_at timestamptz`
- `missing_since timestamptz null`
- `active boolean`
- unique 후보: `(source_type, external_id)`

주의:
- snapshot 테이블 생성은 DB migration이므로 별도 승인 필요.
- 대안으로 초기 구현은 파일 snapshot도 가능하지만 운영 안정성은 DB snapshot이 낫다.

### 3.2 Diff 기준
- 이전 snapshot에 없고 이번 목록에 있음 → `appeared`
- 이전 snapshot에 있고 이번 목록에 없음 → `disappeared_candidate`
- 계속 있음 → no change
- 2회 연속 없음 또는 후보 상세조회 returned 확인 → `return_detected`

### 3.3 후보 상세조회 기준
상세조회는 변화분만 수행한다.

배차 후보:
- appeared 항목만 상세조회
- 상세 status가 `using_car`이면 `dispatch_detected`

반납 후보:
- disappeared 항목만 상세조회
- 상세 status가 `returned/completed`이면 `return_detected`
- 상세조회 실패 또는 상태 애매하면 `manual_review` 또는 다음 run 재확인

## 4. OPS 연결 기준
OPS 자동 처리 아님.

저장 대상:
- `rc00_ops_action_logs`

action_key 후보:
- `ims.lifecycle.dispatch_detected`
- `ims.lifecycle.return_detected`
- `ims.lifecycle.manual_review`
- `ims.lifecycle.lookup_failed`

중복 방지:
- `signal_key = source_type + external_id + reservation_id + signal_type + reason`
- 기존 `ims-linked-lifecycle-watcher`의 signal_key 방식 유지

매칭 기준:
1. IMS external id가 `rc00_ops_external_reservation_links.external_reservation_id`와 직접 매칭되면 우선
2. 없으면 차량번호 + 배차/반납 window로 후보 매칭
3. 복수 매칭이면 자동 신호 금지, manual_review

## 5. Phase 계획

### Phase 1. API 응답 구조 확인
목적:
- 보험 배차중/일반 배차중 목록 API가 상세조회 없이 필요한 상태값을 주는지 확인한다.

변경점:
- 없음. read-only 조사.

종료조건:
- 보험/일반 각각 목록 응답 필드 확정
- 목록만으로 `using_car` 판정 가능한지 확정
- 후보 상세조회가 필요한 조건 정리

검증:
- 실제 window 2일전~2일후 조회
- API 호출 수 기록

### Phase 2. Snapshot diff read-only 구현
목적:
- 저장 없이 현재 목록과 기존 snapshot mock을 비교하는 read-only report 구현

변경점:
- snapshot diff 함수 추가
- appeared/disappeared/no_change 분류

종료조건:
- read-only report에 변화 후보가 출력된다.
- 상세조회는 아직 하지 않거나 mock/fallback만 한다.

검증:
- node check/test
- fixture 기반 appeared/disappeared 테스트

### Phase 3. Snapshot 저장소 추가
목적:
- 이전 배차중 목록을 운영 DB에 저장한다.

변경점:
- migration 추가
- snapshot upsert 로직 추가

주의:
- DB migration이라 별도 승인 필요.

종료조건:
- 동일 목록 재실행 시 중복 row 없음
- first_seen/last_seen/missing_since 정상 갱신

검증:
- dry-run
- save-run 1회
- 재실행 idempotency 확인

### Phase 4. 후보 상세조회 및 신호 저장
목적:
- appeared/disappeared 후보만 상세조회하고 OPS action log 신호를 저장한다.

변경점:
- 후보 상세조회 로직
- OPS linked reservation 매칭
- action log 저장

종료조건:
- 전체 linked 상세조회 없이 변화분만 상세조회한다.
- 신호 중복 저장이 없다.

검증:
- 후보 count 대비 상세조회 count 확인
- action log signal_key 중복 없음 확인

### Phase 5. sync-orchestrator 연결
목적:
- snapshot diff watcher를 기존 sync-orchestrator 수동/launchd 흐름에 연결한다.

변경점:
- job registry 추가 또는 기존 `ims-linked-lifecycle-watcher` 대체
- `run-launchd.sh`에 save-signals 단계 추가

운영 권장:
- 10분 주기 또는 기존 orchestrator 주기에 맞춤
- window: `오늘-2일 ~ 오늘+2일`
- 전체 scan: 하루 1회 별도 job 또는 수동 job

종료조건:
- launchd 연결 전 수동 save-signals 1회 성공
- 중복 저장 없음
- API 호출 수가 기존 상세조회 방식 대비 감소

### Final Phase. 문서/검수/커밋
- 변경 파일 검수
- 테스트 실행
- 운영 문서 업데이트
- PM 문서 COMPLETED 이동
- 커밋

## 6. 예상 부하
기존 방식:
- window 2일전~2일후 기준 약 28건 상세조회/회
- 5분 주기면 약 8,064 상세조회/일

새 방식 예상:
- 목록 API: 보험 1~N page + 일반 1~N page
- 상세조회: appeared/disappeared 변화분만
- 평시 변화분이 적으면 상세조회 0~소수

결론:
- API 부하와 IMS 상세조회 의존도가 크게 줄어든다.
- 반납 감지는 사라짐 기반이라 1회 누락 방지를 위해 상세조회 또는 2회 연속 미출현 기준이 필요하다.

## 7. 중단 조건
- 목록 API에서 일반/보험 배차중 상태를 안정적으로 구분할 수 없음
- 동일 차량/시간대 복수 OPS 예약 매칭 발생
- snapshot DB migration 없이 운영 신뢰성을 확보할 수 없음
- IMS API 응답이 pagination/기간 필터에서 누락을 보임
- 자동 처리 요구가 발생함. 이 문서 범위는 신호 저장까지만 포함한다.
