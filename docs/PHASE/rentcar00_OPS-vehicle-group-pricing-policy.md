# 자동차 그룹별 가격 정책 재설정 PM

## Document Metadata
- Created at: 2026-06-18
- Last updated at: 2026-06-18
- Author/agent: Codex
- Related milestone: rentcar00_OPS 운영 기준점 정리 / 가격 정책 재설정 준비
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/COMPLETED/rentcar00_OPS-completed.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_UI_API_BOUNDARY_MAP.md`
- Current status: In Review
- Approval scope: 문서 기준점 정리만 승인됨. 코드 수정, DB 변경, 배포, restart, 외부 API write, commit은 미승인.
- Archive target: 완료·검증·커밋 후 `docs/COMPLETED/COMPLETE_20260618_rentcar00_OPS_vehicle_group_pricing_policy_pm.md`

## 0. Goal Lock
- Objective: 자동차/차종 그룹별 가격 정책을 OPS의 예약 생성·수정·IMS·홈페이지 이벤트 흐름에서 일관되게 다룰 기준을 확정한다.
- Final success condition: 가격 정책 적용 대상, 제외 대상, 저장 위치, 검증 기준, rollback 기준이 확정되고 승인된 구현 phase만 반영된다.
- Explicit non-goals:
  - 승인 없는 코드 수정
  - 승인 없는 운영 DB 보정
  - 승인 없는 Supabase migration
  - 승인 없는 `.env`, secret, runtime config 수정
  - 승인 없는 IMS/홈페이지/외부 서비스 write
  - 임시 호환 레이어 또는 추후 삭제 예정 구조
- Protected targets:
  - `.env*`
  - `supabase/config.toml`
  - `supabase/migrations/*`
  - `reservation_ai_parser` 운영 service/launchd/cloudflared 설정
  - 실제 운영 DB
  - IMS, 홈페이지, GDrive 등 외부 서비스 상태
- Approval required for:
  - 각 구현 phase 시작
  - 파일 수정 범위 확장
  - DB schema/data 변경
  - parser service restart/deploy
  - APK build/upload
  - commit/push

## 1. Current State Evidence
- Repo status:
  - branch: `fix/ops-return-complete-end-at`
  - HEAD: `05efdba docs: record b50 APK release`
  - app version/build: `1.0.0+50`
  - PM 문서 작성 전 기준 dirty worktree 없음
- Existing implementation:
  - 가격 저장 필드: `rc00_ops_reservations.payment_amount`
  - 앱 직접 예약 생성/수정: `lib/data/repositories/supabase_ops_repository.dart`
  - 예약 생성 UI 가격 입력: `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
  - 예약 상세 수정 UI 가격 입력: `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
  - AI파서 가격 추출: `reservation_ai_parser/src/parser-core.js`
  - 홈페이지 이벤트 가격 importer: `reservation_ai_parser/src/server.js`
  - IMS 생성 payload 검증: `lib/features/reservations/detail/data/ims_reservation_payload.dart`
- Existing docs/specs:
  - `docs/GOAL/rentcar00_OPS-current.md`는 이 문서 작성 전 `main`, b48, `ddf13e5` 기준이라 실제 repo와 drift가 있었다.
  - `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`는 준비 phase였고 실행 PM 문서 구조가 아니었다.
- Existing tests/harness:
  - `test/ims_reservation_payload_test.dart`
  - `test/ops_input_formatters_test.dart`
  - `test/widget_test.dart`
  - `reservation_ai_parser/package.json`의 `npm --prefix reservation_ai_parser run check`
  - 기본 후보: `flutter analyze`, `flutter test`, `dart format`, `git diff --check`
- Known conflicts or drift:
  - 문서 기준점이 실제 repo 기준점보다 오래됐다.
  - 가격 정책 테이블 또는 자동차 그룹별 자동 계산 구현은 현재 확인되지 않았다.
  - 홈페이지 송신부 구현은 이 repo 안에 현재 active 기준으로 없다.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Active phase status | 가격 정책 재설정이 active 작업처럼 남아 있음 | active 구현 없음, PM 문서 In Review | 설정 종료 후 무승인 구현을 막기 위해 |
| Baseline | `main`, `ddf13e5`, b48 | `fix/ops-return-complete-end-at`, `05efdba`, b50 | 실제 repo 상태와 문서 기준 일치 |
| Price policy evidence | 경로 후보만 나열 | 저장 필드와 입력/import/export 경로 명시 | 구현 전 영향 범위 잠금 |
| Approval boundary | 일반 phase 문서 | PM 문서 승인 게이트 | 실행/문서/commit 권한 분리 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Flutter reservation flow | `supabase_ops_repository.dart`, reservation/status board presentation | 구현 phase 전 설계 필요 | 가격 적용 누락 | 경로별 테스트와 수동 리뷰 |
| Parser/API flow | `reservation_ai_parser/src/parser-core.js`, `src/server.js` | parser 변경 시 별도 검증 필요 | 홈페이지/IMS 가격 불일치 | node check와 fixture 기반 검증 |
| DB/schema | `rc00_ops_reservations.payment_amount`, migrations | 현재는 Not in scope | 운영 데이터 손상 | 별도 DB phase 승인 |
| Docs | `docs/GOAL`, `docs/PHASE`, `docs/COMPLETED` | 즉시 정리 가능 | 오래된 기준 재사용 | current 문서 우선 |
| Runtime/external | IMS, parser service, 홈페이지 event sender | Not in scope | 외부 상태 변경 | 승인 전 write 금지 |

## 4. Execution Policy
- Approval model: 이 PM 문서 리뷰와 실제 구현 승인은 분리한다. `pa all` 또는 명시 phase 승인 전 구현하지 않는다.
- Phase transition rule: 각 phase는 이전 phase의 검증·리뷰가 끝난 뒤에만 진입한다.
- Review rule: 코드 변경 phase는 변경 파일, 호출 경로, 테스트 결과를 같이 리뷰한다.
- Commit rule: commit은 phase 검증 완료 후 사장님이 승인한 경우에만 수행한다.
- Rollback/compensation rule: 코드 변경은 phase commit 단위 revert를 기본으로 한다. DB/외부 상태 변경은 별도 보정 계획 없이는 수행하지 않는다.
- Stop conditions:
  - 운영 DB 변경 필요 발견
  - `.env`, secret, runtime config 변경 필요 발견
  - 가격 정책 적용 범위가 홈페이지/IMS 외부 write까지 확장됨
  - 현재 코드와 문서 기준이 다시 충돌함
  - 테스트 실패 원인이 즉시 설명되지 않음

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. Policy Decision Lock | 차량 그룹/가격 정책과 적용 범위 확정 | 사장님 + Codex | 문서만 | No | Optional docs commit |
| 2. Data Model Decision | 현 `payment_amount` 유지 또는 정책 테이블 도입 결정 | 사장님 + Codex | 문서만, DB 미변경 | No | Optional docs commit |
| 3. Approved Implementation | 승인된 최소 코드 구현 | Codex | 코드 변경 있음 | Limited | Required if approved |
| 4. Verification and Release Prep | 테스트, 문서 완료, 배포 필요 여부 판단 | Codex | 테스트/문서, 배포는 별도 | Limited | Required before release |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Price source audit | Phase 1 only | 가격 관련 코드 경로를 no-write로 재확인하라. 코드/문서 수정 금지. | `lib`, `reservation_ai_parser/src`, `test` | 경로 목록과 리스크 | primary agent review |
| Vehicle group draft | Phase 1 only | 차량/차종 그룹 기준 후보를 문서 초안으로 정리하라. DB/코드 수정 금지. | 사장님 제공 차량 그룹 기준, 현재 차량 목록 | 정책표 초안 | 사장님 확인 |
| Test plan draft | Phase 2 only | 구현 전 테스트 케이스 후보를 작성하라. 테스트 파일 수정 금지. | price flow evidence | 테스트 계획 | implementation phase 승인 |

## 7. Phases

### Phase 1. Policy Decision Lock
Status: PLANNED

Purpose:
자동차/차종 그룹 기준과 가격 정책 적용 범위를 먼저 확정한다.

Scope:
- In:
  - 차량 그룹 기준 정리
  - 가격 정책표 초안
  - 적용 경로 선택: 직접 예약, 예약 수정, AI파서, IMS import, 홈페이지 event, IMS 생성
- Out:
  - 코드 수정
  - DB 변경
  - 외부 서비스 반영

Files/Targets:
- `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`
- 필요 시 `docs/GOAL/rentcar00_OPS-current.md`

Execution Steps:
1. 사장님 기준 차량 그룹/가격표를 받는다.
2. 현재 가격 흐름별 적용 여부를 표로 고정한다.
3. 자동 계산과 수동 입력 중 운영 방식을 선택한다.

Verification:
- Static checks: 문서 링크와 경로 확인
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 정책 확인

Completion Evidence:
- Code/doc evidence: 가격 정책표와 적용 범위가 문서에 남음
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: 차량 그룹, 가격표, 적용/제외 경로 명시
- Failure handling: 정책 기준을 다시 잠그고 구현 phase로 넘어가지 않는다.

Completion Judgment:
- PASS criteria: 구현자가 해석 없이 적용할 수 있는 정책표가 있다.
- FAIL criteria: 그룹명, 가격, 적용 경로 중 하나라도 애매하다.

Commit Gate:
- Stage scope: 승인된 문서 파일만
- Commit message: `docs: lock vehicle group pricing policy`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Phase 1 문서가 리뷰 완료되고 Phase 2 진입 승인을 받는다.

Rollback/Compensation:
문서 변경은 이전 커밋 또는 diff revert로 되돌린다.

### Phase 2. Data Model Decision
Status: PLANNED

Purpose:
가격 정책을 기존 `payment_amount` 수동 입력 흐름으로 유지할지, 별도 정책 모델을 도입할지 결정한다.

Scope:
- In:
  - `payment_amount` 유지안
  - 앱 내부 계산 helper 도입안
  - DB 정책 테이블 도입안
  - 각 안의 리스크 비교
- Out:
  - migration 작성
  - 운영 DB write
  - 코드 구현

Files/Targets:
- `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`
- 참고 대상: `supabase/migrations/*`, `lib/data/models/reservation_record.dart`

Execution Steps:
1. 현재 저장 필드와 import/export 경로를 기준으로 선택지를 비교한다.
2. 운영 영향이 가장 작은 적용 방식을 선택한다.
3. DB 변경이 필요한 경우 별도 DB phase로 분리한다.

Verification:
- Static checks: 관련 파일 경로 재확인
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 승인

Completion Evidence:
- Code/doc evidence: 선택한 데이터 모델과 제외한 선택지 사유
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: DB 변경 필요 여부 명시
- Failure handling: 구현 phase 진입 중단

Completion Judgment:
- PASS criteria: 구현 범위와 DB 필요 여부가 분리된다.
- FAIL criteria: 구현 중 DB 변경 필요성이 새로 드러난다.

Commit Gate:
- Stage scope: 승인된 문서 파일만
- Commit message: `docs: decide pricing data model`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
구현 방식과 승인 범위가 문서에 고정된다.

Rollback/Compensation:
문서 변경 revert.

### Phase 3. Approved Implementation
Status: PLANNED

Purpose:
승인된 가격 정책만 최소 코드 범위로 구현한다.

Scope:
- In:
  - 승인된 Flutter 파일
  - 승인된 parser 파일
  - 필요한 테스트 수정
- Out:
  - 미승인 DB migration
  - 미승인 runtime config
  - 미승인 parser restart/deploy
  - 미승인 APK build/upload

Files/Targets:
- 후보:
  - `lib/data/repositories/supabase_ops_repository.dart`
  - `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
  - `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
  - `lib/features/reservations/detail/data/ims_reservation_payload.dart`
  - `reservation_ai_parser/src/parser-core.js`
  - `reservation_ai_parser/src/server.js`
  - `test/*`

Execution Steps:
1. 승인된 파일만 수정한다.
2. 가격 정책 적용 경로를 중복 없이 구현한다.
3. 기존 이름과 실제 역할이 어긋나면 같은 phase 안에서 정리한다.
4. 테스트를 새 기준에 맞게 수정한다.

Verification:
- Static checks:
  - `dart format <changed dart files>`
  - `git diff --check`
  - `flutter analyze`
  - `npm --prefix reservation_ai_parser run check` if parser changed
- Tests:
  - `flutter test`
  - parser 관련 변경 시 fixture 또는 최소 API mapping check 추가
- Harness/smoke:
  - 직접 예약 생성/수정 가격
  - IMS 가져오기 가격
  - 홈페이지 event importer 가격
  - IMS 생성 payload `totalFee`
- Manual review:
  - UI 표시명과 저장값 확인

Completion Evidence:
- Code/doc evidence: 변경 파일 목록과 정책 적용 경로
- Test evidence: 명령 결과
- Runtime/DB/external evidence, if applicable: 별도 승인 없으면 없음

Review Gate:
- Reviewer: 사장님 또는 지정 리뷰어
- Required checks: 테스트 통과, 정책 누락 없음, protected target 미수정
- Failure handling: 원인 보고 후 수정 승인 범위 재확인

Completion Judgment:
- PASS criteria: 승인된 모든 경로에서 가격 정책이 동일하게 적용된다.
- FAIL criteria: 한 경로라도 가격이 다르게 적용되거나 테스트가 실패한다.

Commit Gate:
- Stage scope: 승인된 코드/테스트/문서 파일만
- Commit message: `feat: apply vehicle group pricing policy`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
구현 commit 완료 또는 사장님이 commit 생략을 명시한다.

Rollback/Compensation:
phase commit revert. DB/외부 write가 있었다면 별도 승인된 보정 계획을 따른다.

### Phase 4. Verification and Release Prep
Status: PLANNED

Purpose:
실사용 투입 전 검증과 문서 완료 처리를 한다.

Scope:
- In:
  - 테스트 결과 정리
  - 완료 문서 정리
  - APK build/upload 필요 여부 판단
- Out:
  - 승인 없는 APK build/upload
  - 승인 없는 deploy/restart
  - 승인 없는 GDrive 정리

Files/Targets:
- `docs/COMPLETED/rentcar00_OPS-completed.md`
- `docs/GOAL/rentcar00_OPS-current.md`
- APK/release 관련 파일은 별도 승인 시에만 포함

Execution Steps:
1. 구현 결과와 검증 결과를 정리한다.
2. 문서가 실제 코드와 맞는지 확인한다.
3. 배포가 필요하면 별도 release phase로 분리한다.

Verification:
- Static checks: 문서 경로와 변경 요약 확인
- Tests: Phase 3 검증 결과 재확인
- Harness/smoke: 필요한 경우 사장님 실기기 확인
- Manual review: 완료 기준 확인

Completion Evidence:
- Code/doc evidence: 완료 문서와 current 기준점 갱신
- Test evidence: Phase 3 결과
- Runtime/DB/external evidence, if applicable: 별도 승인된 경우만 기록

Review Gate:
- Reviewer: 사장님
- Required checks: 완료 내용, 남은 리스크, 후속 작업
- Failure handling: 완료 처리하지 않고 Phase 3 또는 별도 phase로 되돌린다.

Completion Judgment:
- PASS criteria: 문서/코드/검증 기준이 일치한다.
- FAIL criteria: 배포물이나 운영 기준이 모호하다.

Commit Gate:
- Stage scope: 완료 문서와 승인된 변경 파일
- Commit message: `docs: record vehicle pricing policy completion`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
필요 시 release phase 별도 승인.

Rollback/Compensation:
문서/코드 commit revert. 외부 반영은 별도 보정 계획 필요.

### Final Completion Report
- Completed phases: None yet
- Commits: None from this PM document
- Verification summary: PM document prepared from current repo evidence; implementation not executed
- Residual risks:
  - 자동차 그룹/가격표는 아직 사장님 결정 필요
  - 홈페이지 송신부는 이 repo 안에서 확인되지 않음
  - DB 정책 테이블 도입 여부 미결정
- Follow-up work:
  - 사장님이 가격표와 적용 경로를 확정
  - 승인된 phase만 구현
