# rentcar00_OPS IMS Import Rental Type Dispatch Policy PM

## Document Metadata
- Created at: 2026-08-11 KST
- Last updated at: 2026-08-11 KST
- Author/agent: Codex
- Related milestone: OPS reservation add IMS import and dispatch lifecycle policy
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - `docs/COMPLETED/rentcar00_OPS-completed.md`
- Current status: Completed locally / commit pending
- Execution scope: Local code/test/docs implementation completed under `pa all`. Parser restart, APK rollout, DB/data writes, and IMS writes were not executed.
- Execution Mode: `NORMAL (pa all)`
- Archive target: `docs/COMPLETED/rentcar00_OPS_ims_import_rental_type_dispatch_policy_PM_COMPLETE_20260811.md`

## 0. Goal Lock
- Objective:
  - Make reservation-add IMS import handle IMS `daily`, `monthly`, and `insurance` schedules intentionally.
  - On dispatch completion, map imported IMS rental type to OPS vehicle status:
    - `daily` -> `일반`
    - `monthly` -> `장기`
    - `insurance` -> `보험`
- Final success condition:
  - Reservation-add IMS import no longer depends on `rental_type=all` as the only query.
  - Imported IMS rental type is preserved in the OPS external link payload.
  - Dispatch completion uses the preserved rental type to set the car status to `일반`, `장기`, or `보험`.
  - Existing dedicated `배차 > 보험 > IMS 보험배차 가져오기` remains unchanged.
- Explicit non-goals:
  - No DB migration in this PM.
  - No new reservation type column.
  - No change to reservation tabs or reservation status names.
  - No IMS write.
  - No parser restart, APK upload, production rollout, DB data edit, or external service write unless separately approved.
- Protected targets:
  - `.env*`, IMS credentials/tokens, parser runtime restart, launchd, APK deployment/upload, production DB schema/data, external IMS write APIs.
- Execution scope includes:
  - Parser search code for reservation-add IMS import.
  - Flutter reservation-add import metadata handling.
  - Flutter schedule dispatch completion status policy.
  - Focused tests and local static verification.
  - Documentation update after implementation.

## 0-A. Goal/State Check
- Current goal:
  - Prepare implementation so IMS monthly/insurance imports become correct OPS vehicle statuses after dispatch completion.
- Success criteria:
  - `monthly` imported reservation can complete dispatch into car status `장기`.
  - `insurance` imported reservation can complete dispatch into car status `보험`.
  - `daily` and unknown/blank imported reservation types keep existing `일반` behavior.
- Hard boundary:
  - Do not alter reservation ledger schema just to represent long-term reservation type.
  - Treat long-term as a dispatch vehicle-status policy, not as a reservation tab/status model.
- PROJECT_STATE baseline:
  - No project-local `PROJECT_STATE.md` exists.
  - Current baseline is `docs/GOAL/rentcar00_OPS-current.md`.
- PROJECT_STATE affected sections:
  - None directly, unless PA later updates current-state docs after implementation.
- Expected blueprint delta:
  - Reservation-add IMS import supports explicit rental-type policy.
  - Dispatch completion maps IMS rental type to vehicle status.
- Active PM / next action:
  - This PM becomes the approval document for implementation.
- Expected change:
  - Parser returns `daily/monthly/insurance` imported schedule candidates with `reservationType`.
  - Flutter stores and uses that type for dispatch status.
- PROJECT_STATE current-state update expected after PA: NO
- Completed/phase index update expected after PA: YES
- Completed evidence expected: YES
- Judgment:
  - It is safe that the reservation model has no separate `장기` criterion because the required behavior is vehicle status after dispatch, not reservation categorization.

## 0-B. Harness Check
- Required: YES
- Reason:
  - This changes executable API query behavior, Flutter UI flow, persisted external-link payload usage, and lifecycle state updates.
- Verification target:
  - Node tests for IMS rental-type search list/query behavior.
  - Flutter unit/helper tests for rental-type to car-status mapping.
  - Static analysis for touched Flutter files.
  - Existing relevant app tests if feasible.
- Runtime smoke harness target:
  - Excluded by default. Parser runtime restart and live app smoke require separate approval.
- Architecture document impact:
  - `docs/PHASE/README.md` and completed docs should be updated after PA.
- Judgment:
  - Local tests/static verification are required before completion. Runtime rollout is a separate protected step.

## 1. Current State Evidence
- Repo status at PM creation:
  - Branch: `main`
  - `git status --short --branch`: untracked `docs/PHASE/rentcar00_OPS-realtime-refresh-call-volume-reduction-pm-20260803.md`
  - `docs/GOAL/rentcar00_OPS-current.md` still says branch `fix/ops-return-complete-end-at`; current checked branch is `main`. Treat this as document drift, not implementation authority.
- Existing reservation model:
  - `ReservationRecord` has no `reservationType`, `rentalType`, or long-term field.
  - `rc00_ops_reservations` has no long-term reservation type column.
  - Reservation status is stored through `reservation_status`, and tabs through `rc00_ops_reservation_states.tab_key`.
- Existing vehicle/status-board model:
  - `StatusBoardTab` supports `보험`, `일반`, and `장기`.
  - Vehicle status edit options include `보험`, `일반`, `장기`.
- Existing create path:
  - `createReservationFromVehicle()` creates reservation row + state + `배차`/`반납` schedules.
  - It stores `meta_json.created_via`, but no rental type field.
- Existing IMS import candidate:
  - `ImsReservationImportCandidate` includes `reservationType`.
  - `_saveImportedImsRegistration()` stores `imported.toJson()` in `lastPayloadJson` and `lastResultJson`, so `reservationType` is already available for imported IMS reservations.
- Existing external link constraint:
  - `rc00_ops_external_reservation_links.source_type` allows only `normal_schedule` and `insurance_claim`.
  - Therefore, company-car schedule rows with `reservationType=insurance` should not introduce a new `source_type` without a DB migration.
- Existing dispatch completion:
  - `SupabaseOpsRepository.completeSchedule()` already accepts:
    - `carStatusAfterDispatch = '일반'`
    - `carStatusActionAfterDispatch = '일정완료'`
  - Dedicated `배차 > 보험 > IMS 보험배차 가져오기` already calls `completeSchedule(..., carStatusAfterDispatch: '보험')`.
  - Reservation detail, schedule list, and schedule detail completion call sites currently do not pass policy args, so they default to `일반`.
- IMS read-only probe evidence from 2026-08-11:
  - `rental_type=all` returned mixed `daily`, `monthly`, and `insurance`.
  - `rental_type=daily` returned only `daily`.
  - `rental_type=monthly` returned only `monthly`.
  - `rental_type=insurance` returned only `insurance`.
  - Probe did not print IMS credentials/tokens.
- Existing docs/specs:
  - `docs/GOAL/rentcar00_OPS-current.md` says existing `/ims/search-reservations` is reservation-import only.
  - `docs/PHASE/README.md` says code/DB/parser restart/APK/commit/external submission require explicit approval.
- Existing tests/harness:
  - Parser has Node tests under `reservation_ai_parser/test/*.test.js`.
  - Flutter tests exist under `test/`.
- Known conflicts or drift:
  - Current git branch and `docs/GOAL` branch baseline disagree.
  - There is unrelated untracked PHASE PM doc. It must not be staged unless approved.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| IMS reservation-add search | `rental_type=all` can mix daily/monthly/insurance | Explicitly search/import `daily`, `monthly`, `insurance` candidates | Avoid accidental implicit mixing while keeping all intended IMS schedule types |
| Reservation model | No long-term/insurance type field | No DB/model schema change | Required policy is vehicle status, not reservation category |
| Imported IMS metadata | `reservationType` exists in candidate and payload | Keep using link `lastPayloadJson.reservationType` as source of truth | Avoid DB migration and match existing payload storage |
| Dispatch completion | Generic call sites default car status to `일반` | Map link rental type to `일반`/`장기`/`보험` | Monthly should become long-term vehicle status; insurance should become insurance vehicle status |
| Dedicated insurance import | Already creates insurance reservation and dispatches to `보험` | No change | Prevent regression |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Parser IMS search | `reservation_ai_parser/src/server.js`, possibly `ims-existing-reservation-search-strategy.js` | Reservation-add IMS lookup may make multiple read calls | More API reads, duplicate candidates | Schedule-id dedupe and focused Node test |
| Flutter import metadata | `reservation_ai_parser_client.dart`, `status_board_detail_page.dart` | Imported reservations keep current reservation lifecycle | Missing/unknown type defaults to `일반` | Helper-level fallback test |
| Dispatch lifecycle | reservation detail, schedule list, schedule detail call sites | Vehicle status after `배차완료` changes for monthly/insurance imports | Wrong status if type read path is wrong | Shared helper reads link payload/result and tests all mappings |
| DB schema | None | None | Payload-based policy may be less queryable than schema column | Accept as deliberate no-migration scope; schema PM only if later needed |
| Runtime/deploy | Parser restart and APK rollout excluded | No runtime effect until separately deployed | Local pass not visible to staff until rollout | Final report must state rollout requirement |
| Docs | PHASE/COMPLETED docs after PA | Small doc update | Drift if skipped | Completion phase requires index/completed update |

## 4. Execution Policy
- Execution Mode: `NORMAL (pa all)`
- Execution model:
  - One accountable Codex executes the approved local implementation.
- Recommended execution approval:
  - `pa all` for local code/test/docs/commit.
- User-selected execution approval:
  - Pending.
- Phase transition rule:
  - Do not enter runtime restart, APK upload, DB migration, or production data changes without separate explicit approval.
- PROJECT_STATE update rule:
  - No `PROJECT_STATE.md` update expected. Use `docs/GOAL`/`docs/PHASE`/`docs/COMPLETED` if implementation completes.
- Completed index rule:
  - Update `docs/PHASE/README.md` and `docs/COMPLETED/rentcar00_OPS-completed.md` after implementation.
- Review rule:
  - NORMAL final MCG and BIG-M chat verdicts are required before commit.
- Commit rule:
  - Commit only scoped code/tests/docs after verification.
  - Do not stage unrelated `docs/PHASE/rentcar00_OPS-realtime-refresh-call-volume-reduction-pm-20260803.md`.
- Rollback/compensation rule:
  - Revert touched local files. No DB or external compensation expected because no runtime write is in scope.
- Stop conditions:
  - DB migration becomes necessary.
  - Parser restart, APK upload, or production rollout is requested without exact approval.
  - IMS response shape does not reliably expose `reservationType`.
  - Tests fail or behavior cannot be verified locally.

## 4-A. Optional Delegation And Verification

Default execution:
- One accountable Codex may execute this narrow scope directly.
- Keep diff, tests, and completion judgment visible.

Optional delegation:
- Needed: NO by default.
- Use subagents only for separate review if the implementation grows beyond listed files.

Verification separation:
- Completion must be backed by diff, Node tests, Flutter analyze/tests, and final staged-scope review.
- NORMAL has the accountable parent run final MCG and BIG-M as separate verdicts.

Execution evidence table:
| Step | Evidence |
| --- | --- |
| PM document creation/update | PM document diff |
| Approved phase execution | Scoped code/test/doc diff |
| Verification | Node test, Flutter analyze/test output |
| Final completion judgment | MCG PASS + BIG-M GO chat verdict, successful commit trailers |

## 4-B. Execution Mode Approval

Agent Recommendation:
- Recommended option: `NORMAL (pa all)`
- Reason:
  - Scope is bounded to parser read query behavior and Flutter dispatch policy. No DB migration or runtime rollout is included.
- Risk level:
  - Medium: lifecycle vehicle status changes are user-visible.
- Required verification:
  - Node parser tests, Flutter analyze, focused helper tests, relevant existing tests.
- Protected target impact:
  - None during local implementation. Runtime restart/APK rollout are excluded and require separate approval.

User Selection:
- `NORMAL (pa all)`: implement all listed local phases continuously with verification, final MCG/BIG-M, and scoped commit.
- `STRICT (cg7+pa+mcg+bigm)`: use if adding DB migration or broad UI behavior.
- `hold`: pause execution.
- `replan`: rewrite this PM.

## 5. Phase Map
| Phase | Responsibility Unit | State Change | Scope Lock Summary | Optional Delegation | Verification | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 1 | Parser IMS import search policy | Code/test/docs | Replace implicit `all` dependency with explicit intended rental types | NO | Node tests + `node --check` | No per-phase commit |
| Phase 2 | Flutter dispatch status policy | Code/test | Preserve/use imported rental type and map dispatch status | NO | Flutter analyze + helper tests | No per-phase commit |
| Final | Verification/docs/commit | Docs/commit | Completion docs/index and scoped commit only | NO | Final checks + MCG/BIG-M | One final commit |

## 6. Parallel Work Lanes
| Lane | Role | Can Run In Parallel With | Minimal Delegation Instruction | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- | --- |
| None | Single accountable agent | N/A | N/A | N/A | N/A | N/A |

## 7. Phases

### Phase 1. Parser IMS Import Search Policy
Status: COMPLETED

Purpose:
- Make reservation-add IMS import intentionally include `daily`, `monthly`, and `insurance` company-car schedules.

Work:
- Replace single `rental_type=all` lookup in reservation-add import path with explicit intended rental-type lookups.
- Keep schedule-id dedupe.
- Keep `/ims/search-insurance-claims` untouched.
- Preserve `reservationType` in import item output.

Reason:
- `all` mixes intended types, but it is implicit and can hide policy.
- Read-only evidence confirmed `daily`, `monthly`, and `insurance` are valid filters.

Optional Delegation:
- Needed: NO

Execution Scope:
- Approved scope:
  - Parser search code and focused tests.
- Necessary references:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/ims-existing-reservation-search-strategy.js`
  - `reservation_ai_parser/test/ims-existing-reservation-search-strategy.test.js`
  - `reservation_ai_parser/README.md`
- Protected targets:
  - IMS credentials and runtime restart excluded.
- Expected evidence:
  - Diff and Node test output.
- Stop conditions:
  - IMS API requires an undocumented write or token output.
  - Query split causes ambiguous/duplicated results that cannot be deduped.

Scope:
- In:
  - Read-only IMS reservation import query behavior.
- Out:
  - IMS claim endpoint, IMS writes, parser restart.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/src/ims-existing-reservation-search-strategy.js`
- `reservation_ai_parser/test/ims-existing-reservation-search-strategy.test.js`
- `reservation_ai_parser/README.md`

Scope Lock:
- Modification allowed:
  - Parser import lookup and tests/docs only.
- Creation allowed:
  - Focused test helper only if needed.
- Deletion allowed:
  - None.
- Read-only references:
  - IMS API manual and current parser docs.
- Excluded targets:
  - `.env*`, launchd, runtime process, Supabase DB.
- Behaviors not to change:
  - `/ims/search-fine-notice-contracts` still combines normal/insurance contract candidates.
  - `/ims/search-insurance-claims` remains dedicated vehicle-detail insurance dispatch import.
- Outputs:
  - Parser returns candidates with `reservationType`.
- Scope drift criteria:
  - Need for DB schema or runtime restart.

Execution Steps:
1. Add an explicit intended rental-type list: `daily`, `monthly`, `insurance`.
2. Query each type for reservation-add import and dedupe by schedule id.
3. Add final defensive filter so only intended types are returned.
4. Add/adjust Node tests.
5. Update parser README if behavior text changes.

Verification:
- Static checks:
  - `node --check reservation_ai_parser/src/server.js`
- Tests:
  - `node --test reservation_ai_parser/test/ims-existing-reservation-search-strategy.test.js`
  - `node --test reservation_ai_parser/test/*.test.js`
- Harness/smoke:
  - No live runtime smoke unless separately approved.
- Manual review:
  - Confirm no `/v2/rencar-claims` call was added to reservation-add import path.

Completion Evidence:
- Code/doc evidence:
  - Diff showing explicit rental types.
- Test evidence:
  - Node tests pass.
- Runtime/DB/external evidence:
  - None required.

Review Gate:
- Required checks:
  - Node test output and diff review.
- Failure handling:
  - Stop and report exact failing type or response shape.

Completion Judgment:
- PASS criteria:
  - `daily/monthly/insurance` are explicit, deduped, and preserved.
- FAIL criteria:
  - Insurance claim endpoint is mixed into reservation-add import.

Commit Gate:
- Stage scope:
  - Parser files and parser docs/tests only.
- Commit message:
  - Included in final combined commit.
- Commit only after:
  - Final phase verification.
- staged-scope check:
  - `git diff --cached --name-only`.

Next Phase Entry Criteria:
- Parser tests pass or failures are documented and corrected.

Rollback/Compensation:
- Revert parser search/test/doc changes.

### Phase 2. Flutter IMS Rental Type Dispatch Policy
Status: COMPLETED

Purpose:
- Use imported IMS rental type to choose car status when the linked `배차` schedule is completed.

Work:
- Add a shared helper for IMS rental-type dispatch policy:
  - `insurance_claim` source type -> `보험`
  - link payload/result `reservationType=insurance` -> `보험`
  - link payload/result `reservationType=monthly` -> `장기`
  - `daily`, blank, unknown -> `일반`
- Apply helper at dispatch completion call sites:
  - Reservation detail lifecycle completion.
  - Status-board schedule list completion.
  - Status-board schedule detail completion.
- Update confirmation text where it currently hardcodes `일반`.
- Keep dedicated insurance dispatch import behavior unchanged.

Reason:
- Reservation ledger has no long-term type, and that is acceptable for this requirement.
- The actual needed distinction is vehicle status after dispatch completion.

Optional Delegation:
- Needed: NO

Execution Scope:
- Approved scope:
  - Flutter helper, call sites, focused tests.
- Necessary references:
  - `lib/data/models/external_reservation_link.dart`
  - `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
  - `lib/features/status_board/list/presentation/status_board_tab_page.dart`
  - `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
  - `lib/data/repositories/supabase_ops_repository.dart`
- Protected targets:
  - APK build/upload excluded unless separately approved.
- Expected evidence:
  - Flutter analyze/test output.
- Stop conditions:
  - Need for DB migration or new reservation type column.

Scope:
- In:
  - Dispatch vehicle status policy.
- Out:
  - Reservation tab model, DB schema, IMS writes, dedicated insurance claim import flow.

Files/Targets:
- Likely:
  - `lib/data/models/external_reservation_link.dart` or a new shared domain helper file.
  - `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
  - `lib/features/status_board/list/presentation/status_board_tab_page.dart`
  - `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
  - Focused test under `test/`.

Scope Lock:
- Modification allowed:
  - Helper and three dispatch call sites.
- Creation allowed:
  - Shared helper/test file if it removes duplication.
- Deletion allowed:
  - None.
- Read-only references:
  - `completeSchedule()` implementation.
- Excluded targets:
  - Supabase migrations, parser runtime, APK upload.
- Behaviors not to change:
  - Return completion still resets car to `대기중`.
  - Non-linked or unknown-type dispatch still defaults to `일반`.
  - Dedicated insurance import remains `보험`.
- Outputs:
  - Car status after dispatch matches imported IMS rental type.
- Scope drift criteria:
  - UI redesign, new DB column, or changing reservation tabs.

Execution Steps:
1. Add shared mapping helper.
2. Use helper at all schedule completion call sites that can see `ExternalReservationLink`.
3. Make confirmation text dynamic where practical.
4. Add focused tests for `daily/monthly/insurance/insurance_claim/unknown`.
5. Run Flutter verification.

Verification:
- Static checks:
  - `flutter analyze` or targeted `flutter analyze <touched files>`.
- Tests:
  - Focused helper test.
  - Existing relevant Flutter tests where feasible.
- Harness/smoke:
  - No device smoke unless APK build/installation is separately approved.
- Manual review:
  - Confirm `completeSchedule()` args are passed only for `배차`, not `반납`.

Completion Evidence:
- Code evidence:
  - Helper and call-site diff.
- Test evidence:
  - Flutter analyze/test output.
- Runtime/DB/external evidence:
  - None required.

Review Gate:
- Required checks:
  - Mapping test and call-site inspection.
- Failure handling:
  - Stop and report type mapping failure.

Completion Judgment:
- PASS criteria:
  - Imported monthly dispatch completes to `장기`.
  - Imported insurance dispatch completes to `보험`.
  - Daily/unknown remain `일반`.
- FAIL criteria:
  - Reservation tabs/statuses are changed, or return completion behavior changes.

Commit Gate:
- Stage scope:
  - Touched Flutter helper/call-site/test files.
- Commit message:
  - Included in final combined commit.
- Commit only after:
  - Final phase verification.
- staged-scope check:
  - `git diff --cached --name-only`.

Next Phase Entry Criteria:
- Flutter checks pass or failures are corrected.

Rollback/Compensation:
- Revert helper and call-site changes.

### Final Phase. Completion Judgment / Documentation Cleanup / Commit
Status: COMPLETED LOCALLY / COMMIT PENDING

Purpose:
- Verify local implementation, update documentation, and commit scoped changes.

Work:
- Review all phase outputs.
- NORMAL: have the accountable parent run final MCG and BIG-M as separate verdicts.
- Make completion judgment.
- Run final Goal/State Check.
- Run final Harness Check.
- Update or create phase/completed index.
- Archive completed PM to `docs/COMPLETED/` with `_PM_COMPLETE_20260811`.
- Commit scoped changes.

Reason:
- The change affects executable parser/API behavior and Flutter lifecycle state; completion needs documented evidence.

Optional Delegation:
- Needed: NO

Execution Scope:
- Approved final scope:
  - Verification, docs update, PM archive, commit.
- Necessary references:
  - This PM document.
  - `docs/PHASE/README.md`
  - `docs/COMPLETED/rentcar00_OPS-completed.md`
- Expected evidence:
  - Test outputs, git diff/status, doc update diff, commit hash.
- Stop conditions:
  - Verification fails or staged scope includes unrelated files.

Scope Lock:
- Modification allowed:
  - This PM archive path, phase/completed indexes, completed ledger.
- Creation allowed:
  - Completed PM archive file.
- Deletion allowed:
  - Move/remove the PHASE PM only when archiving after completion.
- Read-only references:
  - Goal/current docs.
- Excluded targets:
  - Unrelated PM docs, `.env*`, runtime/deploy config.
- Behaviors not to change:
  - No runtime rollout in this final phase.
- Outputs:
  - Scoped commit and completion report.
- Scope drift criteria:
  - Need for APK deployment, parser restart, or DB migration.

Verification:
- Execution Mode evidence:
  - NORMAL final MCG and BIG-M chat verdicts.
- MCG chat verdict and command/diff evidence:
  - Diff scope, tests, no protected changes.
- BIG-M chat verdict and bundle evidence:
  - Parser + Flutter + docs alignment.
- Successful commit trailers for gates actually performed:
  - `Gate-MCG: PASS`
  - `Gate-BIGM: GO`
- Review evidence:
  - `git diff --check`
- Test/build/harness evidence:
  - Node tests, Flutter analyze/tests.
- Documentation evidence:
  - PM completed archive, completed ledger, phase index.
- Git status evidence:
  - Clean for scoped files, unrelated dirty preserved.
- Staged-scope evidence:
  - `git diff --cached --name-only`
- Completion evidence:
  - Final chat report.

Gate evidence rule:
- Do not create standalone CG7/MCG/BIG-M artifacts.
- NORMAL successful commit: `Gate-MCG: PASS`, `Gate-BIGM: GO`; no CG7 trailer.
- Non-success gate verdicts stop in chat/PM state without a success commit.

Completion Judgment:
- PASS criteria:
  - Parser and Flutter checks pass.
  - Docs are updated.
  - Commit is scoped.
- FAIL criteria:
  - Unverified runtime behavior is claimed as deployed.
  - Protected target is touched without approval.
- Final PASS basis:
  - Evidence is sufficient and residual rollout risk is stated.

Commit Gate:
- Stage scope:
  - Touched parser, Flutter, tests, docs only.
- Commit message:
  - `feat: map IMS import rental types to dispatch status`
- Commit only after:
  - Verification passes, MCG PASS, BIG-M GO.
- staged-scope check:
  - `git diff --cached --name-only`

Rollback/Compensation:
- Revert final commit if needed.

### Final Completion Report
- Completed phases:
  - Phase 1 parser explicit rental-type search policy completed.
  - Phase 2 Flutter dispatch-status mapping policy completed.
  - Final documentation cleanup completed; scoped commit follows final staged-scope check.
- Commits:
  - Pending at document update time. Final chat reports the created commit hash.
- Verification summary:
  - `node --check reservation_ai_parser/src/server.js` passed.
  - `node --test reservation_ai_parser/test/ims-existing-reservation-search-strategy.test.js` passed: 7 tests.
  - `node --test reservation_ai_parser/test/*.test.js` passed: 31 tests.
  - `flutter analyze lib/features/reservations/shared/domain/ims_dispatch_policy.dart lib/features/reservations/detail/presentation/reservation_detail_page.dart lib/features/status_board/list/presentation/status_board_tab_page.dart lib/features/status_board/detail/presentation/status_board_detail_page.dart` passed.
  - `flutter test test/ims_dispatch_policy_test.dart` passed: 6 tests.
  - `flutter test` passed: 30 tests.
  - `git diff --check` passed.
- MCG verdict:
  - PASS. Diff scope matches approved parser/Flutter/docs targets, tests passed, no protected target was touched.
- BIG-M verdict:
  - GO. Parser query policy, Flutter dispatch policy, tests, and docs are aligned for local completion.
- Harness result:
  - PASS by local code/test/static verification. Runtime smoke is intentionally excluded because parser restart and APK rollout require separate approval.
- Architecture Ledger:
  - Not updated because this repo has no `ARCHITECTURE_LEDGER` or `TEST_REFERENCES` file.
- Residual risks:
  - Parser restart and APK rollout were completed by follow-up approval on 2026-08-11.
  - Existing historical links without `reservationType` will default to `일반` unless separately backfilled.
- Follow-up work:
  - b60 device smoke for IMS reservation-add candidate search and dispatch status transition.

### Rollout Follow-up
- Approval:
  - 사장님 approved commit/restart/push/build/deploy after local PM completion.
- Parser runtime:
  - `ai.otang.reservation-ai-parser` restarted with `launchctl kickstart -k`.
  - PID changed `15145 -> 47478`.
  - Local `/health` and public `/health` both returned OK.
- APK release:
  - Version/build: `1.0.0+60`.
  - Release build commit: `7e52610 chore: bump OPS app build to b60`.
  - APK: `build/releases/rentcar00_ops-app-release-arm64-b60-7e52610.apk`.
  - Google Drive: `rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b60-7e52610.apk`.
  - Size: `20,702,419 bytes`.
  - SHA-256: `60733d9a19a1705480be1639d30ecff8b5cbc193e33f4655bf73cc921418fb9e`.
