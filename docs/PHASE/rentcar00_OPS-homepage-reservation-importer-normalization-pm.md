# Homepage Reservation Importer Normalization PM

## Document Metadata
- Created at: 2026-06-25 14:10 KST
- Last updated at: 2026-06-25 14:10 KST
- Author/agent: OpenClaw rentcar00_ops_developer
- Related milestone: 홈페이지 예약 자동 유입 품질 안정화
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/COMPLETED/rentcar00_OPS-completed.md`
- Current status: Phase 1-6 executed; Phase 7 pending final review/commit
- Approval scope: `pa all` approved Phase 1-7. DB correction, parser restart, docs, and commit are included; push/deploy beyond local launchd restart is not included.
- Archive target: 완료 후 `docs/COMPLETED/COMPLETE_YYYYMMDD_rentcar00_OPS_homepage_reservation_importer_normalization_pm.md`

## 0. Goal Lock
- Objective: 홈페이지 예약 이벤트 importer를 임시 매핑 수준에서 운영 가능한 정규화 importer로 정리한다.
- Final success condition:
  - 홈페이지 예약 생년월일 `19840528` 같은 raw 값이 OPS 저장 시 `1984-05-28`로 정규화된다.
  - 앱 `IMS추가` 검증 기준과 importer 저장 기준이 일치한다.
  - 전화번호, 금액, 날짜, 장소, 예약번호, 차량, 고객명 등 핵심 필드 매핑 기준이 문서/테스트로 고정된다.
  - 신규 홈페이지 예약 1건이 OPS에 들어온 뒤 IMS추가 전 앱 내부 검증에서 막히지 않는다.
  - 기존 문제 예약 1건은 별도 승인 후 운영 DB에서 보정된다.
- Explicit non-goals:
  - 홈페이지 송신부 코드 수정.
  - 홈페이지 → IMS 자동생성 추가.
  - IMS payload 구조 변경.
  - 운영 DB 전체 마이그레이션.
  - Cloudflare/launchd/parser restart 자동 수행.
- Protected targets:
  - `.env*`, secret/token/password, Supabase service role key, launchd, Cloudflare tunnel, 운영 DB, 실제 IMS API write.
- Approval required for:
  - 코드 수정.
  - 운영 DB 보정.
  - parser restart.
  - APK build/release.
  - 실제 홈페이지 예약 end-to-end smoke.
  - commit.

## 1. Current State Evidence
- Repo status:
  - Branch observed: `fix/ops-return-complete-end-at`
  - Last commit observed: `3a9de81 feat: add manual fine notice bundle merge`
  - Working tree observed: untracked `output/`
- Existing implementation:
  - Endpoint: `reservation_ai_parser/src/server.js` `POST /api/integrations/rentcar00/reservation-events`
  - Flow functions:
    - `receiveRentcar00ReservationEvent()`
    - `normalizeReservationCreatedEventPayload()`
    - `storeReservationEvent()`
    - `importReservationCreatedEvent()`
    - `mapHomepageReservationPayload()`
    - `buildHomepageScheduleRow()`
    - `markReservationEventImported()` / `markReservationEventFailed()`
  - Current normalizers:
    - `normalizeIsoDate()` exists for pickup/return timestamps.
    - `normalizePhone()` exists for phone digits.
    - `normalizeAmountText()` exists for amount digits/rounding.
    - No birthdate normalizer in homepage importer path.
- Existing docs/specs:
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`: 홈페이지 예약 이벤트 수신은 OPS 원장/상태/일정 생성 이벤트로 정의됨.
  - `docs/GOAL/rentcar00_OPS-current.md`: 홈페이지 이벤트는 예약 원장/상태/일정 자동 생성, 앱 확인 배지 제공.
- Existing tests/harness:
  - `test/ims_reservation_payload_test.dart`: 앱 IMS payload 검증 기준은 `YYYY-MM-DD` 실제 날짜.
  - 홈페이지 importer 전용 테스트는 확인되지 않음.
  - parser local check: `node src/server.js --check` 문서화되어 있음.
- Known conflicts or drift:
  - 운영 DB에서 홈페이지 예약 `WEB-3207061c-9085-404d-bab1-ee72b6520508`의 `customer_birth_date`가 `19840528`로 저장됨.
  - 앱 상세 수정 화면은 표시 시 `19840528`을 `1984-05-28`처럼 보이게 만들 수 있으나, DB 저장값은 그대로면 IMS추가 검증에서 실패함.
  - 기존 PM 문서 `rentcar00_OPS-homepage-ims-birthdate-payload-pm.md`는 원인 초점이 틀려 삭제됨.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| PM 방향 | IMS payload birthdate 추가 중심 | 홈페이지 importer 정규화 중심 | 실제 장애 원인이 importer raw 저장임 |
| 생년월일 저장 | `firstText(...)` raw 저장 | importer에서 `YYYY-MM-DD` 정규화 | 앱 IMS 검증 기준과 일치 |
| 테스트 | 홈페이지 importer 전용 테스트 없음 | payload mapping/normalization 테스트 추가 | 재발 방지 |
| 운영 보정 | 문제 예약 raw 값 존재 | 별도 승인 후 단건 보정 | 이미 들어온 예약 복구 |
| 모듈 구조 | `server.js` 내부 단일 흐름 | 최소 추출 또는 명확한 importer section 정리 | 유지보수성 확보 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Parser importer | `reservation_ai_parser/src/server.js` | Small/medium | 운영 parser restart 필요 | 코드 검증 후 별도 restart 승인 |
| OPS app IMS flow | 직접 수정 없음 | None | 앱 검증 기준과 importer 기준 불일치 잔존 가능 | 테스트로 같은 기준 고정 |
| DB data | 기존 문제 예약 1건 | Small but protected | 운영 DB write 위험 | 단건 SQL/REST patch 별도 승인 |
| Docs | `docs/PHASE`, 완료 시 `docs/COMPLETED` | Small | 문서와 코드 불일치 | Phase 완료 시 문서 갱신 |
| External systems | 홈페이지 producer, IMS | Not in scope | 실제 payload field variation 미확인 | inbox payload_json 기반 read-only 확인 후 필요 시 field aliases 확장 |

## 4. Execution Policy
- Approval model: 이 문서는 Draft이며 실행 승인 아님. 각 phase 또는 전체 phase 실행은 별도 명시 승인 필요.
- Phase transition rule: Phase 1 확인 후 Phase 2 구현. Phase 3 검증 전 parser restart 금지.
- Review rule: 구현자와 검수자는 역할 분리. subagent 검수 또는 single-agent fallback 검수 기록 필요.
- Commit rule: commit은 사용자가 명시 승인한 경우에만 수행.
- Rollback/compensation rule:
  - 코드: git diff 기준 revert.
  - DB 단건 보정: 기존 값을 기록한 뒤 원복 SQL 준비.
  - parser restart 후 문제 발생 시 이전 commit/파일로 rollback 후 restart.
- Stop conditions:
  - 홈페이지 payload에서 생년월일 의미가 불명확함.
  - 6자리 생년월일 세기 판단 기준이 불명확함.
  - 운영 DB/secret/protected target 수정 필요가 새로 발생함.
  - importer 정규화가 기존 정상 payload를 깨뜨릴 위험 발견.

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1 | 현재 homepage payload와 importer contract 잠금 | Inspector | No | Yes | No |
| 2 | 생년월일/핵심 필드 정규화 구현 | Coder | Code edit | No | Optional |
| 3 | importer 테스트/로컬 검증 | Coder + Reviewer | Test edit/run | No | Optional |
| 4 | 기존 홈페이지 예약 1건 DB 보정안 준비/실행 | Operator | DB write only if approved | After Phase 2 | Separate |
| 5 | parser 운영 반영/restart 및 E2E 확인 | Operator/Reviewer | Runtime restart if approved | No | Separate |
| 6 | 중간서버/임포터 역할 문서 정리 | Documenter | Docs edit | Yes | Optional |
| 7 | 문서 완료 정리/commit | Governor | Docs/commit if approved | No | Yes if approved |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Payload alias audit | Phase 1 | Read homepage event inbox/sample docs and list all birth/date/phone/amount field names. No secret or DB write. | `payload_json`, docs, `server.js` | Field alias list | No protected data exposed |
| Test design | Phase 1 | Inspect parser test structure and propose minimal local tests for `mapHomepageReservationPayload`. | parser files/tests | Test plan | Tests local-only |
| Runtime release checklist | Phase 2/3 | Inspect current launchd/parser docs and prepare restart/check commands without executing. | README, TOOLS, launchd notes | Release checklist | No restart executed |

## 7. Phases

### Phase 1. Importer Contract Lock
Status: PLANNED

Purpose:
정규화 전에 홈페이지 이벤트 payload와 OPS 저장 contract를 정확히 잠근다.

Scope:
- In:
  - `server.js` importer 함수 읽기.
  - 최근 홈페이지 event payload 구조 read-only 확인.
  - OPS 앱 검증 기준 확인.
- Out:
  - 코드 수정 없음.
  - DB write 없음.
  - secret/env 파일 열람 없음.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
- `docs/GOAL/rentcar00_OPS-current.md`
- `lib/features/reservations/detail/data/ims_reservation_payload.dart`

Execution Steps:
1. 홈페이지 payload의 birthdate 후보 필드 확정.
2. OPS 저장 기준 확정: `customer_birth_date = YYYY-MM-DD`.
3. 8자리/6자리/구분자 포함 날짜 처리 기준 확정.
4. 처리 불가 값은 raw 보존 + pending warning으로 둘지 결정.

Verification:
- Static checks: read-only evidence.
- Tests: None.
- Harness/smoke: None.
- Manual review: 사장님에게 contract 보고.

Completion Evidence:
- Code/doc evidence: 함수/필드 목록.
- Test evidence: N/A.
- Runtime/DB/external evidence: read-only row/payload evidence only.

Review Gate:
- Reviewer: Governor or separate verifier.
- Required checks: secret 노출 없음, write 없음.
- Failure handling: field 의미 불명확 시 STOP.

Completion Judgment:
- PASS criteria: 정규화 contract가 한 문장으로 고정됨.
- FAIL criteria: 생년월일 field 의미 또는 세기 판단 불명확.

Commit Gate:
- Stage scope: None.
- Commit message: None.
- Commit only after: N/A.

Next Phase Entry Criteria:
- User approves implementation.

Rollback/Compensation:
- None.

### Phase 2. Homepage Importer Normalization Implementation
Status: PLANNED

Purpose:
홈페이지 예약 importer가 OPS 앱 기준에 맞는 값으로 저장하도록 정규화한다.

Scope:
- In:
  - `normalizeBirthDate()` 또는 importer 전용 birth normalizer 추가.
  - `mapHomepageReservationPayload()`에서 `customerBirthDate` raw 대신 normalized 사용.
  - 필요한 경우 meta_json에 raw value 보존.
  - 기존 phone/amount/date behavior는 유지.
- Out:
  - IMS payload 변경 없음.
  - 홈페이지 송신부 변경 없음.
  - DB 보정 없음.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- Optional: importer helper/test file if Phase 1 decides to extract.

Execution Steps:
1. Birthdate 후보 raw 값을 `firstText(...)`로 수집.
2. `YYYYMMDD` → `YYYY-MM-DD` 변환.
3. `YYYY.MM.DD`, `YYYY/MM/DD`, `YYYY MM DD` → `YYYY-MM-DD` 변환.
4. 6자리 `YYMMDD`는 Phase 1 기준에 따라 변환 또는 pending 처리.
5. 실제 날짜 검증 실패 시 빈값 또는 raw 보존 정책 적용.
6. `meta_json`에 raw payload는 계속 보존.

Verification:
- Static checks: syntax check.
- Tests: Phase 3에서 수행.
- Harness/smoke: No live request.
- Manual review: diff review.

Completion Evidence:
- Code/doc evidence: normalizer diff.
- Test evidence: Phase 3.
- Runtime/DB/external evidence: None.

Review Gate:
- Reviewer: separate verifier.
- Required checks: 기존 정상 값이 변형되지 않음.
- Failure handling: FIX_ONLY.

Completion Judgment:
- PASS criteria: `19840528` maps to `1984-05-28` and invalid dates are not stored as valid.
- FAIL criteria: 정상 date/phone/amount mapping regression.

Commit Gate:
- Stage scope: parser importer code only.
- Commit message: `fix: normalize homepage reservation birthdates`
- Commit only after: explicit user commit approval.

Next Phase Entry Criteria:
- Phase 2 diff ready.

Rollback/Compensation:
- Revert parser code diff.

### Phase 3. Importer Tests and Local Verification
Status: PLANNED

Purpose:
홈페이지 importer 정규화가 재발하지 않게 테스트로 고정한다.

Scope:
- In:
  - `19840528` → `1984-05-28` 테스트.
  - 이미 정상인 `1984-05-28` 유지 테스트.
  - invalid date 처리 테스트.
  - 기존 phone/amount/date mapping smoke.
- Out:
  - Live endpoint call 없음.
  - 운영 DB/IMS call 없음.

Files/Targets:
- Existing parser test location if present.
- If no parser unit structure exists, minimal local test script or exported helper approach must be approved in Phase 2.

Execution Steps:
1. Test harness 위치 확정.
2. Sample homepage event payload fixture 작성.
3. Mapping 결과 assertion 추가.
4. `node src/server.js --check` 또는 targeted test 실행.

Verification:
- Static checks: `node src/server.js --check` if safe.
- Tests: targeted local parser tests.
- Harness/smoke: local-only.
- Manual review: test names and assertions 확인.

Completion Evidence:
- Code/doc evidence: test diff.
- Test evidence: command output.
- Runtime/DB/external evidence: None.

Review Gate:
- Reviewer: separate verifier.
- Required checks: tests do not call IMS/Supabase live.
- Failure handling: FIX_ONLY.

Completion Judgment:
- PASS criteria: local tests pass and cover current bug.
- FAIL criteria: test unavailable or live dependency required.

Commit Gate:
- Stage scope: parser code/tests.
- Commit message: `test: cover homepage reservation importer normalization`
- Commit only after: explicit user commit approval.

Next Phase Entry Criteria:
- Phase 2/3 verified.

Rollback/Compensation:
- Revert test/code diff.

### Phase 4. Existing Reservation Data Correction
Status: PLANNED

Purpose:
이미 운영 DB에 들어온 문제 예약 1건을 앱 검증 기준에 맞게 보정한다.

Scope:
- In:
  - Target: `WEB-3207061c-9085-404d-bab1-ee72b6520508`
  - `customer_birth_date: 19840528 → 1984-05-28`
  - Previous value 기록.
- Out:
  - 전체 DB migration 없음.
  - 다른 예약 일괄 수정 없음 unless separately approved.

Files/Targets:
- Supabase table: `rc00_ops_reservations`

Execution Steps:
1. 현재 row read-only 재확인.
2. 보정 patch/SQL preview 보고.
3. 사용자 승인 후 단건 update.
4. update 결과 read-only 확인.

Verification:
- Static checks: SQL/REST patch preview.
- Tests: N/A.
- Harness/smoke: 앱에서 IMS추가 재시도는 사용자/별도 승인.
- Manual review: before/after 값 확인.

Completion Evidence:
- Code/doc evidence: patch preview.
- Test evidence: N/A.
- Runtime/DB/external evidence: before/after row.

Review Gate:
- Reviewer: Governor.
- Required checks: 단건 reservation_id 일치.
- Failure handling: previous value로 원복.

Completion Judgment:
- PASS criteria: 해당 row가 `1984-05-28`로 저장됨.
- FAIL criteria: row mismatch 또는 update 실패.

Commit Gate:
- Stage scope: No git commit for DB-only unless doc updated.
- Commit message: Optional doc commit only.
- Commit only after: explicit user commit approval.

Next Phase Entry Criteria:
- User approves DB correction.

Rollback/Compensation:
- `customer_birth_date`를 previous value `19840528`로 되돌리는 단건 update.

### Phase 5. Parser Runtime Release and E2E Smoke
Status: PLANNED

Purpose:
수정된 importer를 운영 parser에 반영하고 신규 홈페이지 예약 유입을 검증한다.

Scope:
- In:
  - parser restart command preview.
  - launchd-managed service restart if approved.
  - `/health` 확인.
  - 신규 홈페이지 예약 event 1건으로 OPS 저장값 확인.
- Out:
  - IMS 실제 생성 자동화 없음.
  - 홈페이지 송신부 수정 없음.

Files/Targets:
- launchd service: `ai.otang.reservation-ai-parser`
- Endpoint: `/health`
- Supabase read-only verification after event.

Execution Steps:
1. Current process/service 상태 확인.
2. Restart command preview 보고.
3. 사용자 승인 후 restart.
4. `/health` 확인.
5. 신규 홈페이지 예약 유입 후 row 확인.

Verification:
- Static checks: service status.
- Tests: local tests already passed.
- Harness/smoke: `/health`, 신규 row `customer_birth_date` format.
- Manual review: 앱에서 홈페이지 예약 상세/IMS추가 preflight 확인.

Completion Evidence:
- Code/doc evidence: deployed commit/hash if committed.
- Test evidence: local tests.
- Runtime/DB/external evidence: `/health` + new row readback.

Review Gate:
- Reviewer: separate verifier if available.
- Required checks: parser starts cleanly; no repeated `EADDRINUSE`.
- Failure handling: rollback code + restart previous version.

Completion Judgment:
- PASS criteria: 신규 홈페이지 예약 birthdate normalized and app validation passes.
- FAIL criteria: parser fails, row not created, or birthdate raw persists.

Commit Gate:
- Stage scope: release docs if applicable.
- Commit message: `fix: normalize homepage reservation importer fields`
- Commit only after: explicit user commit approval.

Next Phase Entry Criteria:
- Phase 2/3 complete and user approves runtime release.

Rollback/Compensation:
- Restore previous code and restart service.

### Phase 6. Integration Server Role Documentation
Status: APPROVED / DONE

Purpose:
`reservation_ai_parser`가 현재 AI parser만이 아니라 OPS integration server 역할을 같이 수행한다는 점을 README에 명확히 기록한다.

Scope:
- In:
  - `reservation_ai_parser/README.md` 역할 설명 수정.
  - 홈페이지 importer mapper 위치와 책임 문서화.
  - 역사적 이름과 장기 분리 필요성 문서화.
- Out:
  - 서비스 rename 없음.
  - launchd/Cloudflare/runtime 설정 변경 없음.
  - parser restart 없음.

Files/Targets:
- `reservation_ai_parser/README.md`

Execution Steps:
1. 기존 README의 “앱 전용 AI파서” 설명과 실제 endpoint 목록 충돌 확인.
2. 현재 역할을 Mac mini 중간서버 / OPS integration server로 정리.
3. `src/server.js`, `src/parser-core.js`, `src/homepage-reservation-mapper.js` 책임 분리 기준 추가.
4. 장기 rename/redeploy는 별도 phase로 제한한다고 명시.

Verification:
- Static checks: README 직접 inspection.
- Tests: N/A.
- Harness/smoke: N/A.
- Manual review: 문구가 운영 상태와 충돌하지 않는지 확인.

Completion Evidence:
- Code/doc evidence: README diff.
- Test evidence: N/A.
- Runtime/DB/external evidence: None.

Review Gate:
- Reviewer: Governor.
- Required checks: 문서가 runtime 변경을 암시하지 않음.
- Failure handling: 문구 수정만 수행.

Completion Judgment:
- PASS criteria: README가 현재 중간서버/임포터 역할과 파일 책임을 설명함.
- FAIL criteria: README가 AI parser only처럼 계속 오해를 만듦.

Commit Gate:
- Stage scope: README + PM doc only.
- Commit message: `docs: clarify parser service integration roles`
- Commit only after: explicit user commit approval.

Next Phase Entry Criteria:
- Phase 4/5 or final commit approval.

Rollback/Compensation:
- README/PM doc diff revert.

### Phase 7. Completion Documentation and Commit
Status: PLANNED

Purpose:
작업 결과를 프로젝트 문서 규칙에 맞게 완료 처리한다.

Scope:
- In:
  - `docs/COMPLETED` 완료 기록.
  - PM 문서 상태 업데이트 또는 completed archive 이동.
  - Commit if approved.
- Out:
  - 추가 기능 확장 없음.

Files/Targets:
- `docs/PHASE/rentcar00_OPS-homepage-reservation-importer-normalization-pm.md`
- `docs/COMPLETED/rentcar00_OPS-completed.md` or completed PM copy.

Execution Steps:
1. 완료 증거 정리.
2. 남은 리스크 기록.
3. Commit scope preview.
4. 사용자 승인 후 commit.

Verification:
- Static checks: docs paths and diff.
- Tests: previous phase outputs referenced.
- Harness/smoke: previous phase outputs referenced.
- Manual review: completion report.

Completion Evidence:
- Code/doc evidence: final diff.
- Test evidence: command outputs.
- Runtime/DB/external evidence: if Phase 4/5 approved and executed.

Review Gate:
- Reviewer: Governor.
- Required checks: 문서와 실제 diff 일치.
- Failure handling: docs correction only.

Completion Judgment:
- PASS criteria: docs updated and commit completed if approved.
- FAIL criteria: verification evidence missing.

Commit Gate:
- Stage scope: approved code/tests/docs only.
- Commit message: `fix: normalize homepage reservation importer fields`
- Commit only after: explicit user commit approval.

Next Phase Entry Criteria:
- All approved implementation/release phases done.

Rollback/Compensation:
- Git revert commit if needed.

### Final Completion Report
- Completed phases:
  - Phase 1: importer contract locked. OPS 저장 기준은 `customer_birth_date = YYYY-MM-DD`.
  - Phase 2: homepage mapper separated to `reservation_ai_parser/src/homepage-reservation-mapper.js`; birthdate normalization added.
  - Phase 3: mapper unit tests added and local checks passed.
  - Phase 4: existing reservation `WEB-3207061c-9085-404d-bab1-ee72b6520508` corrected from `19840528` to `1984-05-28`.
  - Phase 5: launchd service `ai.otang.reservation-ai-parser` restarted; local `/health` returned OK.
  - Phase 6: README clarified that `reservation_ai_parser` is currently also an OPS integration server.
  - Phase 7: pending final review and commit.
- Commits: Pending final review.
- Verification summary:
  - `node --test reservation_ai_parser/test/homepage-reservation-mapper.test.js`: PASS, 5 tests.
  - `node --check reservation_ai_parser/src/server.js`: PASS.
  - `node --check reservation_ai_parser/src/homepage-reservation-mapper.js`: PASS.
  - `git diff --check`: PASS.
  - DB readback: target row `customer_birth_date` is `1984-05-28`.
  - Runtime smoke: `GET http://127.0.0.1:43110/health` returned `{\"ok\":true,\"service\":\"reservation_ai_parser\"}`.
- Residual risks:
  - 6자리 생년월일은 세기 판단이 불명확해 이번 normalizer에서는 자동 변환하지 않는다.
  - 신규 실제 홈페이지 예약 E2E는 별도 실제 예약 유입이 필요하다. 운영 DB에 가짜 예약을 만들지 않기 위해 수행하지 않았다.
  - 홈페이지 송신 payload가 추가 필드명을 쓰면 alias 보강이 필요하다.
- Follow-up work:
  - 홈페이지 송신부 contract 문서화.
  - 장기적으로 `reservation_ai_parser`를 `ops_integration_server` 계열로 rename/redeploy하는 별도 PM 검토.
  - 홈페이지 pending UI 문구 개선은 별도 UI phase로 분리 가능.
