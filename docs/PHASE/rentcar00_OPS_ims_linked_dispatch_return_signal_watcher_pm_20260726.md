# IMS Linked 배차/반납 신호 감지 Watcher PM

## 0. 문서 정보
- 작성일: 2026-07-26
- 작성자/agent: rentcar00_reservation_developer
- 상태: Draft
- 승인 범위: IMS linked OPS 예약 전체를 대상으로 배차/반납 상태 변화를 감지하고 OPS에 신호만 남기는 watcher 설계·구현 계획
- 관련 문서:
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - `docs/PHASE/rentcar00_OPS_ims_contract_authority_auto_lifecycle_pm_20260723.md`
  - `docs/PHASE/rentcar00_OPS_homepage_platform_reservation_to_ims_ops_orchestrator_pm_20260724.md`
  - `reservation_ai_parser/README.md`
- 완료 후 문서명: `docs/COMPLETED/rentcar00_OPS_ims_linked_dispatch_return_signal_watcher_COMPLETE_20260726.md`
- 상태/정책문서 업데이트 대상:
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - 필요 시 `reservation_ai_parser/README.md`

## 1. 목적
- 목표:
  - OPS에 IMS link가 생긴 모든 예약을 대상으로 IMS 배차/반납 lifecycle 변화를 감지한다.
  - 감지 결과는 OPS 예약 상태를 임의로 완료 처리하지 않고, 먼저 action log/state 신호로 축적한다.
- 성공 기준:
  - `rc00_ops_external_reservation_links(provider='ims', external_status='linked')` 전체가 watcher 대상이 된다.
  - 대상에는 아래 두 경로가 모두 포함된다.
    1. OPS 앱의 `IMS 예약 가져오기`로 연결된 예약
    2. sync orchestrator가 찜카/카모아 외부예약에서 IMS 생성 후 OPS에 연결한 예약
  - IMS 상태 변화가 있으면 중복 없이 OPS 신호가 저장된다.
  - 배차/반납 실제 완료 처리는 별도 승인 전까지 자동 실행하지 않는다.
- 제외 범위:
  - 신규 IMS 예약을 자동으로 OPS 예약 생성하는 기능
  - 기존 IMS 예약 자동 link
  - IMS 반납완료 API 호출 자동 실행
  - 카모아/찜카 provider write 변경

## 2. 현재 상태
- 확인한 파일/docs:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/README.md`
  - `lib/data/repositories/supabase_ops_repository.dart`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - `supabase/migrations/20260515171000_add_external_reservation_links.sql`
  - `supabase/migrations/20260515182000_allow_unlinked_external_reservation_links.sql`
- 현재 git 상태:
  - branch: `fix/ops-return-complete-end-at`
  - 다수 dirty file 존재. 본 PM 실행 시 기존 변경과 충돌하지 않도록 phase 시작 전 재확인 필요.
- 기존 구현/문서 상태:
  - IMS link 저장소는 `rc00_ops_external_reservation_links`다.
  - linked sample에서 `external_reservation_id`는 IMS schedule id, `external_detail_id`는 IMS detail/contract id로 쓰인다.
  - OPS 앱의 IMS 가져오기와 외부예약 orchestrator 생성분이 같은 link table에 모인다.
  - 배차/반납 완료 수동 처리 경로는 `SupabaseOpsRepository.completeSchedule()` 쪽에 이미 있다.
  - IMS 반납완료 API는 parser `/ims/complete-reservation-return` → IMS `/v2/normal-contracts/{contractId}/set-done` 경로가 있다.
- 확인 필요:
  - IMS schedule status별 정확한 의미: `booking`, `using_car`, `done`, `completed`, `return_done` 등 실제 응답 샘플 기준 확정 필요.
  - 배차 완료 신호 저장 위치를 action log 단독으로 할지, reservation state memo/check payload까지 할지 확정 필요.

## 3. 전체 변경 요약
- 변경점:
  - IMS linked 예약 watcher를 추가한다.
  - watcher는 link table 기준으로 대상 예약을 수집한다.
  - IMS schedule/detail을 조회해 배차/반납 상태를 판정한다.
  - 판정 결과를 idempotent action log/state 신호로 저장한다.
- 변경대상:
  - `reservation_ai_parser/src/server.js` 또는 별도 watcher script
  - `reservation_ai_parser/README.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - 필요 시 `scripts/sync-orchestrator/*` 또는 launchd wrapper
- 예상 영향:
  - OPS 예약 원장에는 즉시 상태 변경 없이 신호만 축적된다.
  - 이후 별도 phase에서 신호를 기반으로 자동 배차완료/반납완료를 실행할 수 있다.
- 주요 리스크:
  - IMS status 해석 오류 시 잘못된 배차/반납 신호가 생길 수 있다.
  - 기존 dirty work와 충돌 가능성이 있다.
  - 같은 IMS schedule id가 여러 OPS 예약에 연결된 경우 중복 신호 위험이 있다.

## 4. Phase 목록

### Phase 1. 기준 데이터/상태 샘플 확정
- 목적:
  - watcher 대상과 IMS 상태 판정 기준을 코드 변경 전 고정한다.
- 변경점:
  - 없음. read-only 조사만 수행.
- 변경대상:
  - 없음.
- 실행방법:
  - `rc00_ops_external_reservation_links`에서 linked 대상 전체/샘플 조회.
  - IMS API schedule detail 샘플 조회.
  - `booking`, `using_car`, 반납완료 상태 후보 확인.
  - 동일 IMS id 중복 link 여부 확인.
- 종료조건:
  - 배차 신호 기준과 반납 신호 기준이 명확히 문서화된다.
- 검증방법:
  - 실제 linked sample 5건 이상으로 상태값과 OPS 예약 상태를 대조.
- 리스크:
  - IMS 응답 필드가 계약 유형별로 다를 수 있다.
- 되돌릴 방법:
  - read-only라 되돌릴 변경 없음.
- 출력보고:
  - watcher 대상 수, 상태값 샘플, 판정 기준, 애매한 케이스.

### Phase 2. Watcher read-only 리포트 구현
- 목적:
  - 상태 변경 없이 배차/반납 신호 후보만 계산한다.
- 변경점:
  - linked 예약 수집 함수 추가.
  - IMS schedule/detail 조회 함수 재사용 또는 추가.
  - 신호 후보 계산 리포트 생성.
- 변경대상:
  - `reservation_ai_parser/src/server.js` 또는 별도 `reservation_ai_parser/src/ims-linked-lifecycle-watcher.js`
  - 테스트 파일 필요 시 추가.
- 실행방법:
  - `provider='ims'`, `external_status='linked'`, `external_reservation_id not null` 기준으로 조회.
  - IMS status를 읽고 후보를 `dispatch_detected`, `return_detected`, `no_change`, `ambiguous`로 분류.
- 종료조건:
  - no-write 실행 시 신호 후보가 출력되고 DB write가 없다.
- 검증방법:
  - node syntax check.
  - 샘플 linked 예약으로 read-only 결과 확인.
- 리스크:
  - IMS API rate/timeout.
- 되돌릴 방법:
  - 추가 파일/함수 revert.
- 출력보고:
  - 후보 수, 대상 예약 id, IMS id, 판정 상태, 애매한 건.

### Phase 3. Idempotent OPS 신호 저장
- 목적:
  - watcher 결과를 OPS에 중복 없이 저장한다.
- 변경점:
  - action log에 신호 저장.
  - 필요 시 reservation state memo/check payload에 lightweight marker 저장.
  - 동일 `reservation_id + ims_id + signal_type` 중복 방지.
- 변경대상:
  - `reservation_ai_parser/src/server.js` 또는 watcher script
  - `rc00_ops_action_logs` write 경로
  - 필요 시 `rc00_ops_reservation_states` update 경로
- 실행방법:
  - action_key 후보:
    - `ims.lifecycle.dispatch_detected`
    - `ims.lifecycle.return_detected`
  - meta_json에 `ims_schedule_id`, `ims_detail_id`, `ims_status`, `detected_at` 저장.
  - 이미 같은 action_key/meta가 있으면 skip.
- 종료조건:
  - 같은 watcher를 두 번 실행해도 로그가 중복 생성되지 않는다.
- 검증방법:
  - 1회 write 후 2회 재실행 중복 없음 확인.
  - Supabase action log 직접 조회.
- 리스크:
  - action log 중복 방지 기준이 약하면 로그가 쌓일 수 있다.
- 되돌릴 방법:
  - 해당 action_key 로그만 삭제 또는 ignore 처리. 삭제는 별도 승인 필요.
- 출력보고:
  - 생성된 신호 로그 수, skipped 수, 중복 방지 결과.

### Phase 4. Sync orchestrator 연결
- 목적:
  - 기존 자동화 루프에서 watcher가 주기적으로 실행되게 한다.
- 변경점:
  - sync orchestrator job 또는 launchd wrapper에 watcher 단계 추가.
  - 기본은 no-write/read-only gate 후 save-run gate로 분리.
- 변경대상:
  - `scripts/sync-orchestrator/jobs.js`
  - `scripts/sync-orchestrator/run-job.js`
  - `scripts/sync-orchestrator/run-launchd.sh`
  - 필요 시 tests.
- 실행방법:
  - first stage: no-write smoke.
  - second stage: approved save-run only.
  - 운영 write gate env 확인.
- 종료조건:
  - launchd에서 watcher가 실행되며 실패해도 다른 critical step에 영향 최소화.
- 검증방법:
  - `node --test scripts/sync-orchestrator/__tests__/*.test.js`
  - `zsh -n scripts/sync-orchestrator/run-launchd.sh`
  - 수동 no-write run.
- 리스크:
  - launchd/runtime 설정 변경은 운영 자동화 영향 있음.
- 되돌릴 방법:
  - orchestrator job 추가 commit revert.
  - launchd 단계 제거.
- 출력보고:
  - run 결과, affected count, 실패/skip count.

### Phase 5. OPS 화면/운영 확인
- 목적:
  - 저장된 신호가 운영자가 실제로 볼 수 있는지 확인한다.
- 변경점:
  - 필요 시 상태보드/예약상세에 신호 badge 또는 action log 표시 보강.
- 변경대상:
  - `lib/features/status_board/*`
  - `lib/features/reservations/detail/*`
  - `lib/data/repositories/supabase_ops_repository.dart`
- 실행방법:
  - action log가 이미 표시된다면 UI 변경 없음.
  - 표시가 부족하면 최소 badge/메모만 추가.
- 종료조건:
  - 운영자가 예약 상세 또는 상태보드에서 배차/반납 감지 신호를 확인할 수 있다.
- 검증방법:
  - Flutter analyze/test 또는 최소 `flutter analyze`.
  - 실기기/빌드 검증은 별도 승인 필요.
- 리스크:
  - UI 변경 범위가 커질 수 있다.
- 되돌릴 방법:
  - UI 변경 revert.
- 출력보고:
  - 신호 표시 위치, 화면 확인 결과.

### Final Phase. 검수·완료판정·상태/정책문서 정리·문서 COMPLETE 변경·커밋
- 목적:
  - 전체 구현 완료 여부를 검수하고 문서/커밋 기준을 맞춘다.
- 변경점:
  - 전체 변경 검수
  - 완료판정
  - 상태변경/정책변경 여부 판단
  - `CURRENT_STATE_MAP`, `CURRENT_EVENT_FLOW_MAP`, `reservation_ai_parser/README.md` 업데이트
  - PM 문서를 `docs/COMPLETED/`로 이동 또는 이름 변경
  - 파일명에 `COMPLETE_20260726` 반영
  - 최종 커밋
- 변경대상:
  - 관련 코드/문서 전체
- 실행방법:
  - git diff 검토.
  - 테스트 실행.
  - 문서 최신화.
  - commit 전 변경 목록 보고.
- 종료조건:
  - planned phase 완료, 검증 통과, 문서 반영, 커밋 가능 상태.
- 검증방법:
  - node syntax/test
  - sync orchestrator tests
  - 필요 시 Flutter analyze
  - read-only/manual smoke
- 리스크:
  - 기존 dirty work와 커밋 범위가 섞일 수 있음. 커밋 전 반드시 분리 확인.
- 되돌릴 방법:
  - commit 전 diff revert.
  - commit 후 revert commit.
- 출력보고:
  - 완료 phase, 변경 파일, 검증 결과, 완료 문서 경로, 커밋 해시, 남은 리스크.

## 5. 승인 및 중단 조건
- 승인 요청:
  - Phase 1은 read-only 조사라 승인 후 바로 진행 가능.
  - Phase 2 이후 파일 수정은 phase별 명시 승인 필요.
  - Phase 3 write 저장, Phase 4 launchd/orchestrator 연결은 별도 승인 필요.
- 중단 조건:
  - IMS status 의미가 불명확한 경우
  - 동일 IMS id가 여러 OPS 예약에 연결되어 자동 판정 위험이 있는 경우
  - 기존 dirty work와 충돌하는 경우
  - DB schema 변경이 필요한 경우
  - launchd/운영 자동화 영향이 예상보다 큰 경우
- protected target 별도 승인 필요 여부:
  - launchd/orchestrator wrapper 변경은 운영 자동화 영향이 있으므로 별도 승인 필요.
  - DB migration/schema 변경은 별도 승인 필요.
  - 외부 API write는 이번 범위 제외.

## 6. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- 완료 문서 경로:
- 상태/정책문서 업데이트:
- 커밋:
- 남은 리스크:
