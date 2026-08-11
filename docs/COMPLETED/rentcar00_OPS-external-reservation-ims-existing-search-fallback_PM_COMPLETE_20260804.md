# rentcar00_OPS 외부예약 IMS 기존예약 검색/폴백 보강 PM

## Document Metadata
- Created at: 2026-08-04 KST
- Last updated at: 2026-08-04 KST
- Author/agent: Codex
- Related milestone: 카모아/찜카 paid 신규예약 -> IMS/OPS 자동등록 안정화
- Related goal/spec docs:
  - `/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/docs/PHASE/README.md`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/GOAL.md`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/PROJECT_STATE.md`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/docs/PHASE/2026-07-26_EXTERNAL_RESERVATION_ORCHESTRATION_REBUILD_PM.md`
- Current status: Complete
- Execution scope: OPS parser IMS existing-reservation search/fallback hardening, focused tests, single-target operational apply/recovery plan.
- Execution Mode: `NORMAL (pa all)`
- Completed path: `docs/COMPLETED/rentcar00_OPS-external-reservation-ims-existing-search-fallback_PM_COMPLETE_20260804.md`

## Completion Summary
- Completed at: 2026-08-04 KST
- Execution approval: `pa all`
- Final result:
  - OPS parser existing IMS reservation lookup now tries exact and widened same-day/under-24h search windows with `start_at` and `end_at`.
  - The previous unfiltered 120-page schedule list fallback was removed from the existing-reservation lookup path.
  - Parser service was restarted from PID `53630` to PID `54807`; `/health` returned OK.
  - Target `carmore/2172_2026080301000` recovered by reusing existing IMS schedule `4431253`; no new IMS reservation was created.
  - OPS event status is `imported`, OPS reservation exists, two schedules exist, IMS link is `linked`, and booking-system intake is `completed/linked`.
- Verification:
  - `node --check reservation_ai_parser/src/server.js` PASS.
  - `node --test reservation_ai_parser/test/*.test.js` PASS, 28 tests.
  - `git diff --check` PASS.
  - Live read-only IMS check confirmed exact same-day search 0 results and widened search finding `4431253`.
  - Live readback confirmed target OPS/intake linked state.
- Protected targets used:
  - Parser restart: YES.
  - Targeted DB/OPS recovery write: YES, one target only.
  - `.env`, launchd plist, DB schema, external provider write: NOT changed.

## 0. Goal Lock
- Objective: 카모아/찜카 외부예약 handoff에서 IMS에 이미 존재하는 동일 예약을 빠르고 정확하게 재사용하도록 고치고, 동일일/1일미만 예약이 120페이지 전체 폴백과 5초 handoff timeout으로 실패하지 않게 한다.
- Final success condition:
  - 동일 차량/고객/전화/대여시각/반납시각의 기존 IMS 예약이 있으면 `reusedExisting=true`와 IMS schedule id로 linked 처리된다.
  - 동일일/1일미만 예약 검색이 IMS 동일일 API 0건에 막히지 않고 확장 검색으로 후보를 찾는다.
  - 기존 120페이지 무필터 폴백은 제거되거나 작은 시간/페이지 budget 안에서만 작동한다.
  - 이번 카모아 건 `2172_2026080301000`은 IMS `4431253` 재사용 기준으로 OPS/intake terminal 상태까지 복구된다.
- Explicit non-goals:
  - 외부 provider block save-run 구현/실행.
  - IMS lifecycle 자동 배차/반납 완료 구현.
  - `.env*`, launchd plist, Cloudflare, runtime config 변경.
  - 카모아/찜카 외부 write.
  - 과거 전체 intake backfill 또는 광범위 DB 정정.
  - 5초 timeout 값을 늘려서 증상만 숨기는 변경.
- Protected targets:
  - Parser restart: `ai.otang.reservation-ai-parser` 또는 동등 launchd/service restart.
  - Live DB write: booking-system Supabase `external_provider_reservation_intake`, OPS Supabase `rc00_ops_*`.
  - External API write: OPS event POST, IMS schedule create/update/delete.
  - These are approved only if the user later selects the execution approval for this PM.
- Execution scope includes:
  - OPS parser code/test/doc changes.
  - Read-only IMS/OPS/booking-system verification.
  - One targeted runtime restart after local verification.
  - One targeted recovery/reprocess for `provider=carmore`, `external_reservation_id=2172_2026080301000`, with strict stop conditions.

## 0-A. Goal/State Check
- Current goal: 라이브 운영 안정화와 근거 기반 개선.
- Success criteria: 신규 외부예약 발생 시 감지, OPS HMAC handoff, IMS exact create/reuse, OPS 예약/state/schedule 생성, exact binding, intake terminal 상태가 근거와 함께 남는다.
- Hard boundary: 승인 없는 코드, DB, restart, deploy, runtime config, external write 금지.
- PROJECT_STATE baseline:
  - booking-system은 2026-07-27 기준 카모아/찜카 paid `register-new` launchd 운영 상태다.
  - 목표 계약은 provider intake, OPS HMAC handoff, OPS parser의 IMS 생성/정확 재사용, OPS 예약/state/배차·반납 일정, exact binding, intake terminal까지다.
- PROJECT_STATE affected sections:
  - booking-system `Sync Orchestrator Safety Gate 운영 상태`
  - booking-system `다음 작업 방식`
  - OPS `docs/PHASE/README.md` 비과태료/외부예약 PM 목록
- Expected blueprint delta:
  - 동일일/1일미만 IMS existing-reservation search window와 fallback budget 기준이 current 기준으로 추가된다.
  - 5초 timeout은 sender 보호장치이며, parser가 handoff request 안에서 오래 막히지 않게 하는 것이 primary fix로 기록된다.
- Active PM / next action: 이 PM 승인 후 `pa all` 또는 보수 모드 선택.
- Expected change:
  - OPS parser existing IMS reservation lookup helper/logic.
  - OPS parser focused Node tests.
  - Completion docs/index updates.
- PROJECT_STATE current-state update expected after PA: YES
- Completed/phase index update expected after PA: YES
- Completed evidence expected: YES
- Judgment: 현재 장애는 코드/데이터/운영상태 증거가 충분하므로 작은 PM으로 진행 가능하다.

## 0-B. Harness Check
- Required: YES
- Reason: executable behavior, state/event flow, DB handoff state, external IMS read/write boundary, parser runtime loop에 영향을 준다.
- Verification target:
  - Local static: `node --check src/server.js`
  - Focused tests: new or updated Node tests for IMS existing-reservation search/fallback.
  - Existing tests: `node --test test/homepage-reservation-mapper.test.js` plus any extracted helper test.
  - Read-only live check: target reservation and IMS schedule detail lookup without PII output.
  - Runtime smoke after restart: parser `/health`, target route behavior by controlled reprocess/read-only evidence.
- Runtime smoke harness target:
  - `GET http://127.0.0.1:43110/health`
  - targeted event/reprocess only after local checks pass.
- Architecture document impact:
  - OPS phase index and completed record.
  - booking-system PROJECT_STATE concise current-state delta after PA.
- Judgment: harness required. Verification failure stops before restart/recovery.

## 1. Current State Evidence
- Repo status:
  - OPS repo branch: `fix/ops-return-complete-end-at`.
  - OPS repo has an unrelated untracked phase doc: `docs/PHASE/rentcar00_OPS-realtime-refresh-call-volume-reduction-pm-20260803.md`.
  - booking-system branch: `dev`.
  - booking-system has unrelated dirty work in `scripts/ims-sync/*`, `scripts/no-write-smoke.test.js`, and draft PM/index files.
- Existing implementation:
  - OPS parser route `/api/integrations/rentcar00/reservation-events` handles event storage and import synchronously.
  - `createImsReservationDirect(payload, { allowExistingLink: true })` searches existing IMS reservations before creating a new IMS schedule.
  - `findCreatedImsReservationByApi()` attempts search up to 4 times, then calls `findImsReservationsByListApi()` with `maxPages=120`.
  - `findImsReservationsBySearchApi()` uses `date_option=start_at`, `start=<pickup date>`, `end=<return date>`, and `option=car_identity`.
  - booking-system sender default timeout is 5000ms and uses `AbortController`.
- Existing docs/specs:
  - booking-system orchestration PM states that 외부예약 완료 is OPS reservation id + schedules + linked IMS external id, not just intake or HTTP 200.
  - OPS parser README documents homepage/external reservation event receiver and IMS create endpoint.
- Existing tests/harness:
  - OPS parser has Node tests for homepage mapper, insurance claim import item, and IMS using-car snapshot diff.
  - No direct focused test currently covers same-day/under-24h IMS existing reservation reuse.
- Known conflicts or drift:
  - booking-system `EXECUTION_CONTRACT.md` was not present at the checked path.
  - OPS parser current runtime PID was confirmed running in the earlier investigation, but PM execution must re-check before restart.
  - Previous stderr had historical restart failures; runtime restart remains protected and must happen only after local checks pass.

### Investigation Evidence To Preserve
- Target reservation:
  - Provider: `carmore`
  - External reservation id: `2172_2026080301000`
  - Car: `142호5773`
  - Window: `2026-08-08 10:00` to `2026-08-08 20:00` KST, 10 hours.
- Observed state:
  - booking-system intake: `ops_handoff_status=failed_final`, attempt count `3`, error message `This operation was aborted`, IMS id null.
  - OPS event: status `failed`, error `available car not found: 142호5773`.
  - IMS: exact schedule `4431253` exists for the same car/time/customer identity.
- Reproduction:
  - IMS same-day reservation search `start=2026-08-08&end=2026-08-08&date_option=start_at&search=142호5773` returned 0.
  - Widened search around the date returned schedule `4431253`.
  - One fallback list scan of 120 pages took about 26 seconds; actual handoff gap was about 111 seconds.
- Git/history:
  - 5s sender timeout dates to `2026-05-24`.
  - IMS existing-search/list fallback dates mostly to `2026-05-20`.
  - External reservation auto OPS/IMS handoff path was connected on `2026-07-26~27`.
  - `2026-07-31` OPS parser commit touched insurance expected-return read logic, not this search path.
- Data distribution:
  - Since `2026-07-26`, 카모아 intake had 24 rows.
  - Under-24h/same-day 카모아 rows: 1, the target row.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Same-day existing IMS search | Exact same-day `start=end` search can return 0 | Search uses exact plus widened date window for same-day/under-24h reservations | IMS search API can omit same-day schedules under exact date window |
| Date option | `date_option=start_at` only | Try `start_at` and `end_at`, dedupe by schedule id | Schedules may be indexed/filtered differently |
| Match confirmation | Search candidates then detail match | Keep detail match as final authority: car/time/customer/phone/address | Avoid false positive IMS reuse |
| Fallback | 120 unfiltered pages, repeated up to 4 attempts | Remove or cap to small filtered/budgeted fallback | Prevent handoff timeout and broad live API scan |
| Retry loop | Can spend 100s+ before returning | Bounded existing lookup path | Sender timeout remains a protection, not the main control |
| Tests | No same-day/under-24h coverage | Add focused unit tests around helper/search strategy | Prevent recurrence |
| Target recovery | Row stuck `failed_final` | Single-target reprocess/recovery after fix and restart | Restore live data without broad backfill |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| OPS parser IMS create/reuse | `reservation_ai_parser/src/server.js` or extracted helper | Immediate runtime behavior after restart | Existing helper is in a large server file | Keep changes narrow; extract only if needed for tests |
| External reservation handoff | booking-system sender/read-only status only | Should complete faster | Reprocess may write OPS/booking states | Single target, strict expected ids, stop on mismatch |
| IMS API usage | IMS reservation search/detail endpoints | Fewer broad list calls | API parameter behavior may vary | Test with mocked responses and read-only live checks |
| Runtime | parser launchd process | Requires restart after code change | Restart failure affects parser endpoints | `node --check`, focused tests, health smoke before/after |
| Documentation | OPS and booking-system docs | Current-state delta after PA | Drift if PM completes without docs | Final phase includes index/completed/current-state update |

## 4. Execution Policy
- Execution Mode: `NORMAL (pa all)`
- Execution model:
  - One accountable Codex executes approved scope directly.
  - No subagent required by default.
  - Stop before any new DB table/migration/config/deploy/external provider write.
- Recommended execution approval: `NORMAL (pa all)`
- User-selected execution approval: Pending.
- Phase transition rule: Each phase must report changed files and verification. Failed or inconclusive verification stops the PM.
- PROJECT_STATE update rule: current-state/baseline deltas only; no completed-PM ledger entries.
- Completed index rule:
  - On completion, move or copy final PM record to OPS `docs/COMPLETED/`.
  - Update OPS `docs/PHASE/README.md`.
  - Update booking-system `docs/PHASE/README.md` or `PROJECT_STATE.md` only if PA actually changes live handoff behavior or target row status.
- Review rule:
  - NORMAL requires final MCG-style review and BIG-M-style completion judgment in chat.
  - No separate gate-result document is required.
- Commit rule:
  - Commit only after code/tests/docs/recovery evidence are complete and staged scope excludes unrelated dirty files.
  - If user excludes commit, report `커밋 제외`.
- Rollback/compensation rule:
  - Code rollback: revert only PM-owned code changes.
  - Runtime rollback: restart previous checked-out code only with explicit approval.
  - DB compensation: do not broad-update; if target reprocess writes a wrong state, stop and report exact row ids/status for separate recovery approval.
- Stop conditions:
  - New protected target appears.
  - Same-day widened search returns multiple exact matches.
  - Target IMS id differs from expected `4431253`.
  - Local tests/check fail.
  - Parser health fails after restart.
  - Reprocess would create a new IMS schedule instead of reusing existing IMS schedule.
  - Any command would expose secrets or PII in output.

## 4-A. Optional Delegation And Verification

Default execution:
- One accountable Codex may execute the approved scope directly.
- Keep scope, implementation notes, verification evidence, and completion judgment visible.
- Do not force fixed multi-role ownership into the PM.

Optional delegation:
- Needed: NO by default.
- Use only if a separate read-only live verification lane is helpful after local code/test pass.
- Delegation does not expand approved scope.

Verification separation:
- Implementation evidence: diff of code/tests/docs.
- Static evidence: `node --check`.
- Test evidence: focused Node tests and existing mapper tests.
- Runtime evidence: parser health before/after restart.
- Live data evidence: read-only target row, OPS event, IMS detail, then targeted reprocess result if approved.

Execution evidence table:

| Step | Evidence |
| --- | --- |
| PM document creation/update | PM document diff and OPS PHASE index diff |
| Approved phase execution | changed files, command output, implementation notes |
| Verification | PASS/FIX/STOP evidence from checks selected by risk |
| Final completion judgment | chat verdict plus actual successful commit trailer if commit is included |

## 4-B. Execution Mode Approval

Agent Recommendation:
- Recommended option: `NORMAL (pa all)`
- Reason: Scope is narrow and evidence is already strong; protected operations are limited to one parser restart and one target recovery after local verification.
- Risk level: Medium because live runtime restart and targeted DB/OPS writes are included after code verification.
- Required verification: local static/tests, read-only live checks, parser health, single-target result check.
- Protected target impact: YES, but exact and bounded.

User Selection:
- `NORMAL (pa all)`: lock this PM once, run all phases continuously with phase-specific verification, then final MCG and BIG-M judgments.
- `STRICT (cg7+pa+mcg+bigm)`: run CG7 before and MCG after every phase, then final BIG-M.
- `hold`: pause execution.
- `replan`: rewrite the PM before execution.

## 5. Phase Map
| Phase | Responsibility Unit | State Change | Scope Lock Summary | Optional Delegation | Verification | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 1 | Local OPS parser search/fallback hardening | Code/test only | Same-day/under-24h widened search, `start_at`/`end_at`, bounded fallback | No | `node --check`, focused tests | No intermediate commit |
| Phase 2 | Read-only validation | No writes | Confirm target IMS/search behavior without PII | Optional read-only check only | command evidence, no secret/PII output | No |
| Phase 3 | Runtime apply and target recovery | Protected restart/targeted DB+OPS writes | Parser restart, one target reprocess/recovery | No | health, target row linked/completed evidence | No intermediate commit |
| Final | Review/docs/archive/commit | Docs/commit | Completed record, indexes/current-state delta, staged-scope commit if approved | No | final review/BIG-M, git status | Commit if included |

## 6. Parallel Work Lanes
| Lane | Role | Can Run In Parallel With | Minimal Delegation Instruction | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- | --- |
| A | Implementation | None by default | N/A | server code and tests | local diff | local tests pass |
| B | Read-only live check | After Phase 1 local checks | Query target state without PII/secrets | target external id and IMS id | compact status evidence | no writes and expected ids match |

## 7. Phases

### Phase 1. OPS Parser Existing IMS Search/Fallback Hardening
Status: PLANNED

Purpose:
동일일/1일미만 예약이 IMS 기존예약 검색에서 누락되지 않게 하고, 전체 120페이지 scan 때문에 handoff가 timeout되는 경로를 제거한다.

Work:
- Refactor or extract the existing IMS reservation search strategy into a testable helper if needed.
- Add search attempts:
  - exact date window.
  - same-day/under-24h expanded window: `startDate - 1`, `endDate + 1`.
  - `date_option=start_at` and `date_option=end_at`.
- Dedupe candidate schedules by schedule id.
- Keep final match authority in detail verification:
  - car identity
  - rental/return minute
  - customer name
  - customer phone digits
  - address only when both sides have a comparable address.
- Replace 120-page unfiltered fallback with bounded behavior:
  - Prefer no list scan after widened filtered search.
  - If a list scan remains necessary, cap max pages and time budget tightly and record why.
- Prevent repeated 4-attempt fallback from exceeding sender timeout by design.

Reason:
The existing code treats the same-day IMS search 0 result as absence and falls into a slow broad fallback. This is the direct cause of the observed abort.

Optional Delegation:
- Needed: NO
- Delegated scope: N/A
- Inputs: N/A
- Allowed actions: N/A
- Expected output: N/A
- Merge point: N/A

Execution Scope:
- Approved scope:
  - `/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/reservation_ai_parser/src/server.js`
  - Optional new helper under `/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/reservation_ai_parser/src/`
  - Optional new tests under `/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/reservation_ai_parser/test/`
- Necessary references:
  - Existing `createImsReservationDirect`, `findCreatedImsReservationByApi`, `findImsReservationsBySearchApi`, `findImsReservationsByListApi`.
- Protected targets:
  - None in this phase.
- Expected evidence:
  - Diff.
  - `node --check src/server.js`.
  - Focused Node tests pass.
- Stop conditions:
  - Helper extraction requires broad rename/rearchitecture beyond this PM.
  - Test harness cannot isolate behavior without starting live server or writing to IMS/DB.

Scope:
- In:
  - Search/fallback code.
  - Tests for same-day/under-24h existing IMS reservation reuse.
  - Tests for ambiguity and no-match bounded behavior.
- Out:
  - Sender timeout env/config change.
  - Event queue/asynchronous processing redesign.
  - DB schema/migration.
  - OPS app UI changes.

Files/Targets:
- Code: `reservation_ai_parser/src/server.js` or a small extracted helper.
- Tests: `reservation_ai_parser/test/*`.

Scope Lock:
- Modification allowed: listed code/tests only.
- Creation allowed: one helper module and one focused test file if needed.
- Deletion allowed: no file deletion; removing or replacing the unbounded fallback block is allowed inside modified code.
- Read-only references: booking-system sender/orchestrator code.
- Excluded targets: `.env*`, launchd plist, Supabase schema, OPS app Flutter code.
- Behaviors not to change:
  - HMAC auth for `/api/integrations/rentcar00/reservation-events`.
  - Existing homepage reservation mapping.
  - IMS create payload semantics except existing-match search before create.
- Outputs:
  - Code/test diff and local PASS evidence.
- Scope drift criteria:
  - Need to change public endpoint contract or DB schema.

Execution Steps:
1. Add or extract testable IMS existing-reservation lookup strategy.
2. Implement widened filtered search and candidate dedupe.
3. Bound or remove unfiltered list fallback.
4. Add focused tests for the target class of failure.
5. Run local static/tests.

Verification:
- Static checks:
  - `node --check src/server.js`
- Tests:
  - `node --test test/homepage-reservation-mapper.test.js`
  - `node --test <new-focused-test-file>`
- Harness/smoke:
  - Not in this phase.
- Manual review:
  - Review diff for secret/PII logging and broad fallback removal.
- Additional review/gates, if selected:
  - STRICT mode would add CG7/MCG around this phase.

Completion Evidence:
- Code/doc evidence: diff.
- Test evidence: command outputs with exit code 0.
- Runtime/DB/external evidence: none in this phase.
- Review/gate evidence: chat verdict.

Review Gate:
- Required checks: static + focused tests.
- Failure handling: stop and report failure with line-level cause.

Completion Judgment:
- PASS criteria: same-day/under-24h lookup is covered by tests and unbounded fallback no longer exists.
- FAIL criteria: lookup can still scan broadly or lacks exact-match verification.
- Final PASS basis: evidence is sufficient and residual risk is acceptable.

Commit Gate:
- Stage scope: none yet.
- Commit message: reserved for final.
- Commit only after: final phase.
- staged-scope check: final phase.

Next Phase Entry Criteria:
- Phase 1 checks pass.

Rollback/Compensation:
- Revert PM-owned code/test diff only.

### Phase 2. Read-Only Live Validation
Status: PLANNED

Purpose:
Local fix assumptions match live IMS/API behavior before runtime restart or target recovery.

Work:
- Re-check parser syntax and current process before touching runtime.
- Run read-only IMS search/detail checks for the target class:
  - exact same-day search behavior.
  - widened date search behavior.
  - IMS detail for expected schedule id `4431253`.
- Re-check booking-system intake and OPS event state for target without printing PII.

Reason:
The bug depends on IMS API date filtering behavior. The fix must be validated against the same API behavior without writing.

Optional Delegation:
- Needed: NO
- Delegated scope: Optional read-only verification only.
- Inputs: target provider/external id, car, time window, expected IMS id.
- Allowed actions: read-only commands only.
- Expected output: compact evidence with no PII/secrets.
- Merge point: before restart.

Execution Scope:
- Approved scope:
  - Read-only commands against IMS and Supabase.
- Necessary references:
  - `.env` may be sourced only to use existing configured clients; values must not be printed.
- Protected targets:
  - No write/restart/config in this phase.
- Expected evidence:
  - Target IMS id still present.
  - No unexpected multiple exact matches.
- Stop conditions:
  - Multiple exact IMS matches.
  - Expected IMS id missing.
  - Commands would expose secrets/PII.

Scope:
- In:
  - Read-only IMS/API/DB verification.
- Out:
  - DB update.
  - OPS event POST.
  - IMS create/update/delete.

Files/Targets:
- No file changes.

Scope Lock:
- Modification allowed: none.
- Creation allowed: none.
- Deletion allowed: none.
- Read-only references: live target rows and IMS detail.
- Excluded targets: all writes.
- Behaviors not to change: N/A.
- Outputs: compact evidence.
- Scope drift criteria: any required write before restart/recovery.

Execution Steps:
1. Check current parser code with `node --check`.
2. Read target intake/OPS event/IMS detail state.
3. Confirm widened search can find expected target and exact match is unique.

Verification:
- Static checks:
  - `node --check src/server.js`
- Tests:
  - Phase 1 tests remain passing.
- Harness/smoke:
  - None.
- Manual review:
  - Confirm no PII/secrets in output.
- Additional review/gates, if selected:
  - STRICT mode only.

Completion Evidence:
- Code/doc evidence: none.
- Test evidence: static/test commands still pass if rerun.
- Runtime/DB/external evidence: read-only evidence.
- Review/gate evidence: chat verdict.

Review Gate:
- Required checks: unique expected IMS match.
- Failure handling: stop before restart.

Completion Judgment:
- PASS criteria: expected IMS match can be found by intended strategy.
- FAIL criteria: live data contradicts local assumptions.
- Final PASS basis: live read-only evidence supports runtime apply.

Commit Gate:
- Stage scope: none.
- Commit message: reserved for final.
- Commit only after: final phase.
- staged-scope check: final phase.

Next Phase Entry Criteria:
- Phase 1 and Phase 2 pass.

Rollback/Compensation:
- No state changed.

### Phase 3. Runtime Apply And Single-Target Recovery
Status: PLANNED

Purpose:
Verified code를 live parser에 적용하고, stuck target row를 broad backfill 없이 한 건만 회복한다.

Work:
- Restart parser service after local/static/read-only checks pass.
- Confirm parser `/health`.
- Reprocess or recover only:
  - provider: `carmore`
  - external reservation id: `2172_2026080301000`
  - expected IMS schedule id: `4431253`
- If using orchestrator reprocess:
  - handle `failed_final` eligibility explicitly for this target only.
  - expected result: `ims.reused=true` or equivalent, `externalReservationId=4431253`, OPS reservation/schedules completed, intake `ops_handoff_status=completed`.
- If event reprocess cannot be safely used because of eligibility/dedupe constraints, stop and present a DB recovery mini-plan rather than improvising.

Reason:
Code fix alone does not repair the existing stuck row. Recovery must be exact and bounded.

Optional Delegation:
- Needed: NO
- Delegated scope: N/A
- Inputs: N/A
- Allowed actions: N/A
- Expected output: N/A
- Merge point: N/A

Execution Scope:
- Approved scope:
  - Parser restart only for the existing parser service.
  - One target reprocess/recovery only.
- Necessary references:
  - Current launchd/service status.
  - booking-system external reservation orchestrator/retry logic.
  - OPS parser event status behavior.
- Protected targets:
  - Parser runtime restart.
  - Supabase DB writes for the one target.
  - OPS event POST for the one target.
  - Possible IMS write path must be guarded: expected behavior is reuse existing IMS, not create new IMS.
- Expected evidence:
  - Restart succeeded and `/health` OK.
  - Target intake becomes completed/linked with IMS id `4431253`.
  - OPS event imported or equivalent OPS reservation/schedules/link exist.
- Stop conditions:
  - Restart fails or health fails.
  - Reprocess would create a new IMS schedule instead of reusing `4431253`.
  - New target row count exceeds one.
  - Expected target identity mismatches.
  - Existing event status/dedupe prevents safe reprocess and requires direct DB recovery not already specified.

Scope:
- In:
  - Runtime restart.
  - Single target recovery.
- Out:
  - Broad retry of all failed rows.
  - Provider block/external mall writes.
  - DB schema changes.
  - `.env*` changes.

Files/Targets:
- Runtime: existing parser process/service.
- Data:
  - booking-system target `external_provider_reservation_intake` row.
  - OPS target event/reservation/schedule/link rows.

Scope Lock:
- Modification allowed: one target DB/event state only.
- Creation allowed: only missing OPS reservation/state/schedule/link rows for target if reprocess creates them normally.
- Deletion allowed: none.
- Read-only references: IMS schedule detail `4431253`.
- Excluded targets: other provider reservations, provider block rows, external provider APIs.
- Behaviors not to change: no config/secret/runtime plist changes.
- Outputs: recovery result report.
- Scope drift criteria: direct DB repair script or SQL not already reviewed, multi-row changes, migration requirement.

Execution Steps:
1. Confirm working tree and command plan before restart.
2. Restart parser service with approved method.
3. Verify `/health`.
4. Run targeted reprocess/recovery.
5. Read back booking-system/OPS/IMS state.
6. Stop and report if any expected id/status mismatches.

Verification:
- Static checks:
  - Already passed before restart.
- Tests:
  - Already passed before restart.
- Harness/smoke:
  - Parser health.
  - Target reprocess result.
- Manual review:
  - Confirm only target row changed.
- Additional review/gates, if selected:
  - STRICT mode only.

Completion Evidence:
- Code/doc evidence: none new.
- Test evidence: pre-restart tests.
- Runtime/DB/external evidence: health and target readback.
- Review/gate evidence: chat verdict.

Review Gate:
- Required checks: health + target exact linked state.
- Failure handling: stop and report exact state; no broad recovery.

Completion Judgment:
- PASS criteria: parser running, target recovered, no unexpected extra writes.
- FAIL criteria: target still failed, duplicate IMS/OPS created, or runtime unhealthy.
- Final PASS basis: live evidence is sufficient and residual risk is acceptable.

Commit Gate:
- Stage scope: none yet.
- Commit message: reserved for final.
- Commit only after: final phase.
- staged-scope check: final phase.

Next Phase Entry Criteria:
- Runtime and target recovery pass.

Rollback/Compensation:
- Runtime rollback requires separate approval.
- DB compensation requires separate exact recovery approval if target state is wrong.

### Final Completion Report
Status: PLANNED

Purpose:
검수, 문서 정리, 완료 판정, commit을 PM scope 기준으로 닫는다.

Work:
- Review diff and final state.
- Update OPS PHASE index and completed record.
- Update booking-system PROJECT_STATE/PHASE index only if PA changed live operational state.
- Move/record this PM as complete using `_complete-20260804` convention.
- Commit PM-owned code/tests/docs if commit is included and staged scope is clean.

Reason:
Operational fixes must leave current-state evidence and not drift from docs.

Optional Delegation:
- Needed: NO
- Delegated scope: N/A
- Inputs: N/A
- Allowed actions: N/A
- Expected output: N/A
- Merge point: N/A

Execution Scope:
- Approved scope:
  - PM-owned docs/index/completed record.
  - Commit of PM-owned files only, if not excluded.
- Necessary references:
  - OPS docs rules and booking-system documentation rules.
- Protected targets:
  - Commit if selected by user.
- Expected evidence:
  - Final git status showing only expected staged/unstaged state.
  - Verification summary.
  - Commit hash if committed.
- Stop conditions:
  - Unrelated dirty files would be staged.
  - Completion evidence is incomplete.

Scope:
- In:
  - Completion doc/index/current-state updates.
  - PM-owned commit.
- Out:
  - unrelated dirty work.

Files/Targets:
- OPS docs:
  - `docs/PHASE/README.md`
  - `docs/COMPLETED/*`
- booking-system docs if live state changed:
  - `PROJECT_STATE.md`
  - `docs/PHASE/README.md`

Scope Lock:
- Modification allowed: PM-owned docs only.
- Creation allowed: completed record.
- Deletion allowed: do not delete; move/rename PM only if done carefully.
- Read-only references: git status/diff/log.
- Excluded targets: unrelated existing dirty files.
- Behaviors not to change: N/A.
- Outputs: final chat report.
- Scope drift criteria: docs restructuring beyond this PM.

Execution Steps:
1. Run final review of code/tests/docs.
2. Update completion docs/current-state as needed.
3. Run final relevant checks.
4. Stage PM-owned files only.
5. Commit if included.
6. Report verification, residual risk, and follow-up.

Verification:
- Static checks:
  - final `node --check src/server.js`
- Tests:
  - focused tests and existing mapper test.
- Harness/smoke:
  - if runtime apply occurred, parser health and target readback.
- Manual review:
  - staged scope.
- Additional review/gates, if selected:
  - final MCG and BIG-M judgments in chat.

Completion Evidence:
- Code/doc evidence: final diff.
- Test evidence: PASS commands.
- Runtime/DB/external evidence, if applicable: target recovered evidence.
- Review/gate evidence, if applicable: final chat judgments.

Review Gate:
- Required checks: staged scope, tests, docs, target state if live applied.
- Failure handling: do not commit; report blocker.

Completion Judgment:
- PASS criteria:
  - All phases done or explicitly excluded by user.
  - Verification sufficient.
  - Docs/index current.
  - Commit complete or explicitly excluded.
- FAIL criteria:
  - Any verification inconclusive.
  - Runtime/target state mismatches.
  - Unrelated changes mixed into stage.
- Final PASS basis: evidence is sufficient and residual risk is acceptable.

Commit Gate:
- Stage scope:
  - PM-owned OPS parser code/tests/docs.
  - PM-owned booking-system docs only if updated.
- Commit message:
  - `fix: harden external reservation IMS existing search`
- Commit only after:
  - tests/static/runtime checks pass.
  - staged-scope check.
- staged-scope check:
  - `git status --short`
  - `git diff --cached --name-only`

Next Phase Entry Criteria:
- N/A.

Rollback/Compensation:
- If commit excluded, leave clear uncommitted diff summary.
- If commit included and later rollback needed, use a normal revert commit after approval.

## Approval Surface
- Recommended execution approval: `NORMAL (pa all)`
- Alternative: `STRICT (cg7+pa+mcg+bigm)` if 사장님 wants phase-by-phase gates around runtime/recovery.
- `pa all` approves only the scope in this PM:
  - OPS parser search/fallback code and tests.
  - read-only validation.
  - parser restart.
  - single target recovery for `2172_2026080301000`.
  - PM-owned docs and commit.
- Anything outside this list requires stop and new approval.
