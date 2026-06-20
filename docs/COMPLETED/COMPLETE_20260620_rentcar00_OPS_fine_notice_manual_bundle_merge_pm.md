# Fine Notice Manual Bundle Merge PM

## Document Metadata
- Created at: 2026-06-20
- Last updated at: 2026-06-20
- Author/agent: Codex
- Related milestone: 과태료 문서 생성 MVP - 수동 묶음 생성
- Related goal/spec docs:
  - `docs/PHASE/rentcar00_OPS-fine-notice-app-document-package-mvp-pm.md`
  - `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_required_fields_gate_pm.md`
  - `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_required_fields_gate_pm.md`
- Current status: Completed
- Execution scope: Add manual fine-notice bundle merge selection UI, server validation/execution API, model/repository wiring, tests, smoke, docs, and final commit.
- Archive target: `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_manual_bundle_merge_pm.md`

## 0. Goal Lock
- Objective:
  - Let the operator manually select multiple fine notice rows and merge them into one document bundle.
  - The bundle then drives the already implemented application/list PDF aggregation policy.
- Final success condition:
  - On the list screen, operator can tap `묶기`, select eligible rows, review a confirmation modal, and save one shared `document_list_group_key`.
  - Server rejects unsafe merges before DB write.
  - Existing document generation uses the resulting bundle without extra manual file handling.
- Explicit non-goals:
  - No automatic bundling algorithm beyond the existing row lookup.
  - No bundle split/unbundle in this PM.
  - No submission/발송완료 workflow.
  - No DB schema migration unless current columns are proven insufficient.
  - No deploy, push, APK build, or external submission.
- Protected targets:
  - `.env*`, launchd/service files, deploy config, secrets, production DB migrations, external submission channels.
- Execution scope includes:
  - Flutter list UX, model/repository/client code, parser server API, tests, local parser restart smoke if approved by `pa all`, docs, commit.

## 0-A. Goal/State Check
- Current goal:
  - Finish fine-notice document package MVP so operators can safely prepare shareable renter-change packages.
- Success criteria:
  - Manual grouping is explicit, validated, reversible by future policy, and does not create unsafe mixed-contract packages.
- Hard boundary:
  - Do not create documents with `확인 필요`; do not merge rows with different confirmed contracts.
- PROJECT_STATE baseline:
  - `GOAL.md`, `PROJECT_STATE.md`, and project-local `EXECUTION_CONTRACT.md` were not found in `projects/rentcar00_OPS`.
  - Current baseline is derived from `docs/PHASE/README.md`, active fine-notice PM docs, current code, and recent completed docs.
- PROJECT_STATE affected sections:
  - 확인 필요. If `PROJECT_STATE.md` is later created/repaired, affected areas are fine-notice state map, UI/API boundary, and document package flow.
- Expected blueprint delta:
  - Add manual bundle merge as an operator-controlled state transition that writes `document_list_group_key`.
- Active PM / next action:
  - This PM is ready for review; execution begins only after `pa` or `pa all`.
- Expected change:
  - UI list selection mode, API validation/write, local model field exposure, tests and docs.
- PROJECT_STATE update expected after PA: 확인 필요
- Completed evidence expected: YES
- Judgment:
  - 진행 가능. Missing anchors are noted; anchor repair is out of this PM unless separately requested.

## 0-B. Harness Check
- Required: YES
- Reason:
  - This changes persisted state (`document_list_group_key`), UI/API boundary, document-generation input grouping, and user-visible workflow.
- Verification target:
  - Dart model/repository/client tests where available, Flutter analyze, parser `node --check`, endpoint dry-run validation, and live smoke with safe sample if available.
- Runtime smoke harness target:
  - `GET /health`
  - `POST /fine-notices/merge-bundle` with `dryRun: true`
  - If explicitly safe sample rows are available, one non-dry-run local smoke may be run after reporting selected IDs.
- Architecture document impact:
  - UI/API boundary and fine-notice state map need follow-up if project anchors are later introduced.
- Judgment:
  - 진행 가능 with DB-write gated by documented endpoint validation and `dryRun` smoke first.

## 1. Current State Evidence
- Repo status:
  - Branch: `fix/ops-return-complete-end-at`
  - Dirty before PM doc creation: untracked `output/` preview folder only.
- Existing implementation:
  - Server already has `document_list_group_key`, `source_batch_id`, `resolveFineNoticeBundleContext`, and bundle file paths.
  - Server document generation aggregates bundled rows after commit `64df5ed`.
  - Server blocks incomplete documents after commit `3c6ba0e`.
  - Flutter list exists in `lib/features/fines/presentation/fine_notice_page.dart`.
  - Flutter model/repository exists in `lib/features/fines/domain/fine_notice_models.dart` and `lib/features/fines/data/fine_notice_repository.dart`.
- Existing docs/specs:
  - Bundle folder and package rules are documented in `rentcar00_OPS-fine-notice-app-document-package-mvp-pm.md`.
  - Manual bundle UI is not yet documented as an executable PM.
- Existing tests/harness:
  - `test/fine_notice_models_test.dart`
  - `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
  - `flutter test test/fine_notice_models_test.dart`
  - `node --check reservation_ai_parser/src/server.js`
  - local parser health and API smoke.
- Known conflicts or drift:
  - Active `docs/PHASE/README.md` says phase-specific approvals are preferred, but user can still approve this PM with `pa all`.
  - `output/` is untracked preview output and must not be staged.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Bundle creation | Only automatic/implicit grouping via existing keys or parser source | Operator can explicitly select rows and merge | Real work needs manual control after reviewing list |
| UI entry | Detail modal actions only | List top `묶기` selection mode | Multiple rows are easier to compare in list |
| Validation | Generation later depends on bundle key | Merge endpoint validates before writing key | Prevent mixed contracts/vehicles/issuers |
| DB write | Existing generation may assign group key while generating | Dedicated merge API writes `document_list_group_key` | Make bundle creation explicit and inspectable |
| Verification | Document generation smoke only | Dry-run merge validation + optional live merge smoke | Avoid accidental DB writes during tests |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Flutter UI | `fine_notice_page.dart` | Medium | Mobile list can become crowded | Selection mode only while bundling; compact checkboxes |
| Flutter model/repository | `fine_notice_models.dart`, `fine_notice_repository.dart` | Medium | Missing group field mapping | Add `documentListGroupKey` and tests |
| Parser API | `reservation_ai_parser/src/server.js` | Medium | Unsafe DB write | Validate all selected rows; dry-run support; reject by default on mismatch |
| DB | `rc00_ops_fine_notices.document_list_group_key` | Medium | Wrong rows merged | Server checks same car/issuer/contract/source before update |
| Document generation | Existing generator | Low | Existing generation behavior changes if group key changes | Keep generation API unchanged; only input grouping changes |
| Docs | `docs/PHASE`, `docs/COMPLETED` | Low | PM/doc drift | Final phase updates index and completion doc |

## 4. Execution Policy
- Execution model:
  - Execute phases in order after `pa` or `pa all`.
- Phase transition rule:
  - Do not enter the next phase until current phase compiles/tests or documented inspection passes.
- Review rule:
  - After API and UI are wired, review selected file diff for accidental unrelated changes.
- Commit rule:
  - One final commit after all phases pass, unless a verification failure requires a stop report.
- Rollback/compensation rule:
  - Revert final commit for code/docs. For live DB smoke, record selected row IDs and previous `document_list_group_key` values before write.
- Stop conditions:
  - Selected merge requires schema migration.
  - Different contracts must be merged to satisfy a user flow.
  - Existing dirty changes overlap target files.
  - Runtime/deploy/secret/protected target changes become necessary.
  - Verification cannot prove DB write safety.

## 5. Phase Map
| Phase | Responsibility Unit | Owner | State Change | Scope Lock Summary | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Merge policy/API contract | Codex | docs/code | Server endpoint shape and validation only | No | Final only |
| 2 | Server merge endpoint | Codex | backend + DB write path | `POST /fine-notices/merge-bundle` dry-run/write | No | Final only |
| 3 | Flutter model/repository/client | Codex | app data layer | Expose group key and call merge API | No | Final only |
| 4 | List selection UX | Codex | UI | Top `묶기` selection mode and confirm modal | No | Final only |
| 5 | Verification/smoke | Codex | tests/runtime smoke | Static tests and dry-run endpoint smoke | No | Final only |
| Final | Completion/docs/commit | Codex | docs/git | Completion doc, phase index, final commit | No | Yes |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| None | None | Not used | Current scope is small and stateful | Single-agent implementation | All code reviewed together |

## 7. Phases

### Phase 1. Merge Policy And API Contract
Status: PLANNED

Purpose:
- Lock exactly what can be merged and what the server returns.

Work:
- Define merge endpoint request:
  - `POST /fine-notices/merge-bundle`
  - body: `{ "fineNoticeIds": ["..."], "dryRun": true|false, "forceRebundle": false|true }`
- Define response:
  - `ok`, `dryRun`, `bundleId`, `noticeDate`, `eligible`, `warnings`, `blockedReasons`, `rows`.
- Define merge rules:
  - At least 2 selected rows.
  - Same `car_number`.
  - Same `issuer`.
  - Same confirmed contract source type.
  - Same confirmed contract source id (`ims_contract_id` or `ims_claim_id`).
  - Not `not_our_vehicle`.
  - If rows already belong to different bundles, reject unless `forceRebundle: true`.
  - Different 위반일시 and 위반장소 are allowed.
  - Different document numbers are allowed and later displayed by bundle aggregation.

Reason:
- The merge itself is a persisted state write. Server must be the final authority.

Scope:
- In: API contract and policy comments/docs.
- Out: UI implementation, actual DB write.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `docs/PHASE/rentcar00_OPS-fine-notice-manual-bundle-merge-pm.md`

Scope Lock:
- Modification allowed:
  - Server constants/helpers for validation policy.
- Creation allowed:
  - None.
- Deletion allowed:
  - None.
- Read-only references:
  - existing generation bundle helpers.
- Excluded targets:
  - DB migration files, `.env*`, launchd, deploy config.
- Behaviors not to change:
  - Existing document generation endpoint.
- Outputs:
  - Locked merge validation policy.
- Scope drift criteria:
  - Need to support cross-contract merges.

Execution Steps:
1. Add validation helper plan/code stubs only if needed by Phase 2.
2. Keep existing generation behavior unchanged.

Verification:
- Static checks:
  - `node --check reservation_ai_parser/src/server.js`
- Tests:
  - Not required yet unless code changes.
- Harness/smoke:
  - None in this phase.
- Manual review:
  - Policy matches user-requested manual merge flow.

Completion Evidence:
- Code/doc evidence:
  - Validation rules present.
- Test evidence:
  - Node syntax if code touched.
- Runtime/DB/external evidence:
  - None.

Review Gate:
- Reviewer: Codex before next phase.
- Required checks:
  - No DB write introduced in Phase 1.
- Failure handling:
  - Stop if contract policy is ambiguous.

Completion Judgment:
- PASS criteria:
  - Merge rules are explicit and reject unsafe rows.
- FAIL criteria:
  - Policy allows different contracts without stop.

Commit Gate:
- Stage scope:
  - Final only.
- Commit message:
  - Final only.
- Commit only after:
  - Final phase.

Next Phase Entry Criteria:
- API contract is clear.

Rollback/Compensation:
- Revert server helper changes if any.

### Phase 2. Server Merge Endpoint
Status: PLANNED

Purpose:
- Add a safe backend endpoint that validates selected rows and writes one shared `document_list_group_key`.

Work:
- Add route `POST /fine-notices/merge-bundle`.
- Add payload normalizer.
- Fetch selected rows by IDs.
- Validate all merge rules.
- Generate or reuse bundle ID:
  - If all rows have same `document_list_group_key`, reuse it.
  - Else generate stable bundle ID from sorted IDs and date seed.
- If `dryRun: true`, return validation result without DB update.
- If `dryRun: false`, update selected rows' `document_list_group_key`.
- Return bundle preview data for app confirmation/result.

Reason:
- The app must not write group keys directly without server validation.

Scope:
- In: parser API and helper functions.
- Out: schema migration, generation PDF changes, file deletion.

Files/Targets:
- `reservation_ai_parser/src/server.js`

Scope Lock:
- Modification allowed:
  - route handling, merge payload normalization, row lookup, validation, update helper.
- Creation allowed:
  - helper functions in same file.
- Deletion allowed:
  - None.
- Read-only references:
  - existing `resolveFineNoticeBundleContext`, `buildFineNoticeBundleId`, `updateFineNoticeRows`.
- Excluded targets:
  - Supabase migration files, secrets, runtime config.
- Behaviors not to change:
  - `/fine-notices/generate-documents`, `/fine-notice-file-packages`, download behavior.
- Outputs:
  - API supports dry-run and write mode.
- Scope drift criteria:
  - Endpoint needs new DB columns.

Execution Steps:
1. Add route and payload parser.
2. Implement selected row lookup.
3. Implement merge validation.
4. Implement dry-run response.
5. Implement DB update only after validation.

Verification:
- Static checks:
  - `node --check reservation_ai_parser/src/server.js`
- Tests:
  - If local JS test harness is unavailable, use endpoint dry-run smoke.
- Harness/smoke:
  - `GET /health`
  - `POST /fine-notices/merge-bundle` with `dryRun: true`
- Manual review:
  - Confirm no file generation happens during merge.

Completion Evidence:
- Code/doc evidence:
  - endpoint and helpers exist.
- Test evidence:
  - Node syntax passes.
- Runtime/DB/external evidence:
  - dry-run smoke returns validation result.

Review Gate:
- Reviewer: Codex.
- Required checks:
  - No non-dry-run DB write in verification unless explicit row IDs and previous values are recorded.
- Failure handling:
  - Stop on unexpected DB write need.

Completion Judgment:
- PASS criteria:
  - Unsafe merge returns rejected response; dry-run never writes.
- FAIL criteria:
  - App or endpoint can merge different contracts.

Commit Gate:
- Stage scope:
  - Final only.
- Commit message:
  - Final only.
- Commit only after:
  - Final phase verification.

Next Phase Entry Criteria:
- Server endpoint works in dry-run.

Rollback/Compensation:
- Revert endpoint code. If live write was performed, restore recorded old keys.

### Phase 3. Flutter Model, Repository, And Client Wiring
Status: PLANNED

Purpose:
- Let the app know which rows are already bundled and call the server merge endpoint.

Work:
- Add `documentListGroupKey` and `sourceBatchId` to `FineNoticeCase`.
- Map fields from Supabase row.
- Add parser/client method for merge dry-run/write.
- Add repository or data helper for merge call, keeping Supabase direct row update out of the UI.
- Add tests for model mapping.

Reason:
- UI needs bundle state to show selected/already bundled rows and avoid direct DB writes.

Scope:
- In: Flutter fine-notice model/client/repository tests.
- Out: UI selection mode.

Files/Targets:
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/data/fine_notice_document_client.dart` or new focused client if cleaner
- `lib/features/fines/data/fine_notice_repository.dart`
- `test/fine_notice_models_test.dart`

Scope Lock:
- Modification allowed:
  - fine-notice model/repository/client only.
- Creation allowed:
  - Small focused merge response model/client if existing client would become confused.
- Deletion allowed:
  - None.
- Read-only references:
  - existing document client and repository patterns.
- Excluded targets:
  - unrelated reservation/status-board code.
- Behaviors not to change:
  - existing document generation/share/open flows.
- Outputs:
  - App data layer can request merge.
- Scope drift criteria:
  - Need for broad state management rewrite.

Execution Steps:
1. Add model fields.
2. Add merge response model if needed.
3. Add client/repository method.
4. Add tests.

Verification:
- Static checks:
  - `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
- Tests:
  - `flutter test test/fine_notice_models_test.dart`
- Harness/smoke:
  - None in this phase.
- Manual review:
  - Confirm existing document client behavior unchanged.

Completion Evidence:
- Code/doc evidence:
  - fields and client method present.
- Test evidence:
  - model tests pass.
- Runtime/DB/external evidence:
  - None.

Review Gate:
- Reviewer: Codex.
- Required checks:
  - No direct Supabase group-key writes from UI.
- Failure handling:
  - Stop if data layer cannot represent bundle state cleanly.

Completion Judgment:
- PASS criteria:
  - Data layer supports merge API and bundle status.
- FAIL criteria:
  - UI must mutate DB directly.

Commit Gate:
- Stage scope:
  - Final only.
- Commit message:
  - Final only.
- Commit only after:
  - Final phase.

Next Phase Entry Criteria:
- Data layer is available.

Rollback/Compensation:
- Revert model/client/repository changes.

### Phase 4. List Selection UX
Status: PLANNED

Purpose:
- Add operator-facing manual merge flow on the list screen.

Work:
- Add top `묶기` button.
- On tap, enter selection mode:
  - Show checkboxes on rows.
  - Disable document/share actions that conflict with selection mode.
  - Show selected count and `선택 묶기` / `취소`.
- Require at least 2 selected rows.
- On `선택 묶기`, call dry-run validation.
- Show confirmation modal:
  - 차량번호
  - 발송처
  - 계약자/계약 source
  - 위반일시 range
  - 묶음 변경 warning if already grouped
  - blocked reasons if invalid
- On confirm, call non-dry-run merge.
- Refresh list and show success message.

Reason:
- List-level selection is safer than detail-level merge because operator can compare multiple rows at once.

Scope:
- In: fine notice list page UI only.
- Out: detailed unbundle/split workflow.

Files/Targets:
- `lib/features/fines/presentation/fine_notice_page.dart`
- optional small local widgets in same file.

Scope Lock:
- Modification allowed:
  - fine-notice list selection state, buttons, confirmation modal.
- Creation allowed:
  - small private widgets/classes in same file if needed.
- Deletion allowed:
  - None.
- Read-only references:
  - existing list row layout and action button patterns.
- Excluded targets:
  - app navigation, unrelated pages, design system overhaul.
- Behaviors not to change:
  - existing row click/detail modal, document generation, share button.
- Outputs:
  - Manual merge UX.
- Scope drift criteria:
  - Need for a new route/page instead of modal.

Execution Steps:
1. Add selection mode state.
2. Add `묶기` top action and row checkboxes.
3. Add selected action bar.
4. Add dry-run confirmation modal.
5. Add commit merge action and refresh.

Verification:
- Static checks:
  - `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
- Tests:
  - Existing fine notice tests.
- Harness/smoke:
  - Manual app review if runnable; otherwise static and screenshot follow-up.
- Manual review:
  - Mobile width does not become unreadable.

Completion Evidence:
- Code/doc evidence:
  - UI selection mode present.
- Test evidence:
  - Flutter analyze/test pass.
- Runtime/DB/external evidence:
  - Dry-run API called before write.

Review Gate:
- Reviewer: Codex.
- Required checks:
  - UI does not expose merge confirm until dry-run returns eligible.
- Failure handling:
  - Stop if mobile layout overlaps or cannot be verified.

Completion Judgment:
- PASS criteria:
  - Operator can select, validate, confirm, and refresh.
- FAIL criteria:
  - Merge is hidden in detail modal only or no validation is shown.

Commit Gate:
- Stage scope:
  - Final only.
- Commit message:
  - Final only.
- Commit only after:
  - Final phase.

Next Phase Entry Criteria:
- UX compiles and dry-run path is wired.

Rollback/Compensation:
- Revert UI changes.

### Phase 5. Verification And Smoke
Status: PLANNED

Purpose:
- Prove merge policy does not break existing fine-notice flows.

Work:
- Run static checks and tests.
- Restart parser only if executing runtime smoke is approved by `pa all`.
- Run health check.
- Run dry-run merge API with known IDs where available.
- If non-dry-run live merge is requested or clearly safe:
  - record selected IDs
  - record previous group keys
  - execute merge
  - verify list/package behavior
  - do not generate documents if required fields are missing.

Reason:
- Merge is a persisted state operation and must be verified conservatively.

Scope:
- In: local checks, dry-run smoke, optional documented live smoke.
- Out: deployment, APK build, push.

Files/Targets:
- No planned code edits unless fixing in-scope verification defects.

Scope Lock:
- Modification allowed:
  - In-scope fixes only.
- Creation allowed:
  - Temporary local test output under `tmp/` if needed.
- Deletion allowed:
  - Temporary files only.
- Read-only references:
  - DB rows for selected smoke IDs unless non-dry-run is explicitly performed.
- Excluded targets:
  - production deploy, external send/share.
- Behaviors not to change:
  - document generation required-field gate.
- Outputs:
  - Verification evidence.
- Scope drift criteria:
  - Need to bypass validation to create a bundle.

Verification:
- Static checks:
  - `node --check reservation_ai_parser/src/server.js`
  - `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
- Tests:
  - `flutter test test/fine_notice_models_test.dart`
- Harness/smoke:
  - `GET /health`
  - `POST /fine-notices/merge-bundle` dry-run
- Manual review:
  - List selection UX in app or screenshot if available.

Completion Evidence:
- Code/doc evidence:
  - no unrelated dirty files.
- Test evidence:
  - all required checks passed.
- Runtime/DB/external evidence:
  - dry-run or live merge smoke result.

Review Gate:
- Reviewer: Codex.
- Required checks:
  - `output/` must not be staged.
- Failure handling:
  - Stop and report broken checkpoint.

Completion Judgment:
- PASS criteria:
  - Tests pass and dry-run/live smoke proves validation.
- FAIL criteria:
  - Merge can write unsafe bundle key.

Commit Gate:
- Stage scope:
  - Final only.
- Commit message:
  - Final only.
- Commit only after:
  - Final phase.

Next Phase Entry Criteria:
- Verification evidence gathered.

Rollback/Compensation:
- Revert in-scope fixes; restore group keys if live write occurred.

### Final Phase. Completion Judgment / Documentation Cleanup / Commit
Status: PLANNED

Purpose:
- Close the PM with verified code, docs, and a clean commit.

Work:
- Review all phase outputs:
  - API validation
  - UI selection flow
  - tests/smoke
  - docs
- Make completion judgment:
  - PASS only if unsafe merge is blocked and UI cannot write directly.
- Run final Goal/State Check:
  - Report missing anchors and whether PROJECT_STATE follow-up remains needed.
- Run final Harness Check when applicable:
  - Report checkpoints and any broken step.
- Update PROJECT_STATE.md if approved blueprint deltas were completed:
  - If still missing, report follow-up rather than creating anchors unless explicitly approved.
- Update or create phase folder index:
  - Update `docs/PHASE/README.md`.
- Update or archive completion documents:
  - Add `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_manual_bundle_merge_pm.md`.
  - Archive/move this PM only after completion if following the project rule.
- Commit:
  - Stage only relevant code/docs/tests.
  - Do not stage `output/`.

Reason:
- This feature changes persisted grouping behavior and must leave traceable docs.

Scope Lock:
- Modification allowed:
  - This PM doc, completion doc, phase index, touched code/tests.
- Creation allowed:
  - Completion doc under `docs/COMPLETED/`.
- Deletion allowed:
  - Only temporary files under `tmp/`.
- Read-only references:
  - prior completed docs.
- Excluded targets:
  - `output/`, `.env*`, deployment/runtime config, DB migrations unless separately approved.
- Behaviors not to change:
  - existing document package generation, required-field gate, share package file roles.
- Outputs:
  - final commit and final chat report.
- Scope drift criteria:
  - Need to change deployment or schema.

Verification:
- Review evidence:
  - git diff and status.
- Test/build/harness evidence:
  - node check, flutter analyze, flutter test, dry-run smoke.
- Documentation evidence:
  - completion doc exists.
- Phase index evidence:
  - `docs/PHASE/README.md` updated.
- Git status evidence:
  - only allowed untracked preview outputs remain, or worktree clean.

Completion Judgment:
- PASS criteria:
  - Manual bundle merge is implemented, validated, documented, and committed.
- FAIL criteria:
  - Any unsafe merge path remains or verification fails.

Commit Gate:
- Stage scope:
  - `reservation_ai_parser/src/server.js`
  - `lib/features/fines/**`
  - `test/fine_notice_models_test.dart`
  - relevant `docs/PHASE/**`
  - relevant `docs/COMPLETED/**`
- Commit message:
  - `feat: add manual fine notice bundle merge`
- Commit only after:
  - all verification and docs pass.

Rollback/Compensation:
- Revert final commit.
- If live DB smoke wrote group keys, restore recorded previous values.

### Final Completion Report
- Completed phases:
  - Phase 1: merge policy/API contract
  - Phase 2: server merge endpoint
  - Phase 3: Flutter model/client wiring
  - Phase 4: list selection UX
  - Phase 5: verification/smoke
  - Final: docs/index/commit prep
- Commits:
  - Recorded in the commit that includes this completed PM document.
- Verification summary:
  - `node --check reservation_ai_parser/src/server.js`
  - `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
  - `flutter test test/fine_notice_models_test.dart`
  - `git diff --check`
  - `GET /health`
  - `POST /fine-notices/merge-bundle` dry-run with rows `5ec6b200-d553-443c-85f6-03ba1e99b738`, `01747ecf-d9f7-4764-bc75-239532b4f639`
- Residual risks:
  - Non-dry-run merge was not executed in smoke because dry-run proved eligibility without DB write.
  - Unbundle/split is explicitly out of scope.
- Follow-up work:
  - Add unbundle/split PM after manual merge is proven.
