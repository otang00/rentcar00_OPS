# rentcar00_OPS Owner/Admin UI Access Control PM

## Document Metadata
- Created at: 2026-06-26 07:05 Asia/Seoul
- Last updated at: 2026-06-26 08:55 Asia/Seoul
- Author/agent: OpenClaw rentcar00_ops_developer
- Related milestone: App shell homepage indicator and owner-only access controls
- Related goal/spec docs:
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-importer-normalization-pm.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`
  - `docs/HARNESS/CURRENT_UI_API_BOUNDARY_MAP.md`
  - `docs/HARNESS/CURRENT_GUARDRAIL_LOG.md`
- Current status: Completed
- Approval scope: UI phases 1-4, completion docs, and commit were approved by user with `pa all 커밋까지`. DB/RLS changes, deploy, and runtime restart were not approved and were not executed.
- Archive target: `docs/COMPLETED/rentcar00_OPS_owner_admin_ui_access_control_pm_COMPLETE_<YYYYMMDD>.md`

## 0. Goal Lock
- Objective:
  - Replace the current wide top `홈페이지 N` action with a compact homepage icon + count badge.
  - Restrict `과태료` and `웹/홈페이지 확인` UI entry points so staff cannot use them.
- Final success condition:
  - On small mobile widths, homepage pending UI no longer overlaps the top tab/action area.
  - Staff users cannot see or open the fines layer or homepage pending action from the app shell.
  - Owner/admin user can still access both features.
- Explicit non-goals:
  - No DB/RLS policy change in UI phases.
  - No Supabase migration or production data update unless separately approved.
  - No redesign of reservation/status-board tabs beyond the overlap fix.
- Protected targets:
  - Supabase migrations, RLS policies, production DB state, runtime config, `.env*`, launch/restart/deploy paths.
- Approval required for:
  - Code edits.
  - Test updates.
  - Commits.
  - Any DB/RLS migration or production apply.

## 1. Current State Evidence
- Repo status:
  - Branch: `fix/ops-return-complete-end-at`
  - Current status: clean except untracked `output/`
- Existing implementation:
  - `lib/app/view/app_shell.dart`
    - `TextButton.icon` currently renders `홈페이지 ${homepagePending.length}` in the top action area.
    - `OpsLayer.fines` is included through `OpsLayer.values` and has no role filter.
    - `+` action on fines layer opens `showFineNoticeCreateFlow(...)` with no role gate.
  - `lib/app/domain/ops_layer.dart`
    - `enum OpsLayer { reservations, statusBoard, fines }`
  - `lib/features/reservations/shared/providers/reservation_providers.dart`
    - `homepagePendingReservationsProvider` filters `homepage_review == 'pending'` without authorization logic.
  - `lib/features/fines/presentation/fine_notice_page.dart`
    - Fines page and actions currently have no page-level owner/admin guard.
- Existing docs/specs:
  - Project docs use `docs/GOAL`, `docs/PHASE`, `docs/COMPLETED`, `docs/ARCHIVE`.
  - Homepage pending UI wording improvement is already noted as separable UI work in the homepage importer PM.
- Existing tests/harness:
  - `test/widget_test.dart`
  - `test/fine_notice_models_test.dart`
  - `test/ims_reservation_payload_test.dart`
  - `test/ops_input_formatters_test.dart`
  - `reservation_ai_parser/test/homepage-reservation-mapper.test.js`
  - Harness docs under `docs/HARNESS/`
- Known conflicts or drift:
  - App/DB currently verify `admin` and `staff`; there is no confirmed `owner` role helper.
  - Current DB fine-notice RLS is permissive for authenticated users, so UI-only blocking is not a server-side security boundary.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Homepage pending UI | Wide `홈페이지 N` text button | Compact language icon with numeric badge | Prevent overlap with top tabs/actions |
| Fines tab | Visible/clickable to all active staff | Visible/clickable only to owner/admin role | Staff must not access fines |
| Homepage pending action | Visible/clickable to all active staff when pending exists | Visible/clickable only to owner/admin role | Staff must not access web/homepage confirmation |
| Direct fines page render | No internal guard | Page-level guard for unauthorized users | Prevent future/direct route leaks |
| Role helper | `isAdmin` only | Reusable owner/admin authorization helper, using current supported role model first | Avoid scattered string checks |
| Server auth boundary | Fine notice RLS allows all authenticated users | Separate DB/RLS decision phase only if approved | Avoid mixing UI change with protected DB work |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| App shell UI | `lib/app/view/app_shell.dart` | Small | Badge layout regression | Widget/manual narrow-width check |
| Authorization model | `lib/features/auth/domain/staff_account.dart` | Small | Owner role ambiguity | Treat current `admin` as owner/admin unless DB role expansion is separately approved |
| Fines feature | `lib/features/fines/presentation/fine_notice_page.dart` | Medium | Direct page access remains if only tab hidden | Add page-level guard |
| Tests | `test/widget_test.dart` or new app shell test | Medium | Provider setup complexity | Add focused tests around visible controls where feasible |
| DB/RLS | Supabase migrations/policies | Not in UI scope | UI-only block is not a real data boundary | Separate protected phase and approval |
| Docs | This PM, completion docs after work | Small | Docs drift | Update completed doc only after implementation/verification |

## 4. Execution Policy
- Approval model:
  - This PM is review-only until the user explicitly approves execution.
  - `pa all` or equivalent applies only to UI/test/doc phases unless DB/RLS is explicitly named.
- Phase transition rule:
  - Each phase must finish verification before moving to the next phase.
- Review rule:
  - Implementation and final verification should be separated by role/subagent or by explicit single-agent fallback passes.
- Commit rule:
  - Commit only after verification and only if the user explicitly includes commit approval.
- Rollback/compensation rule:
  - Revert touched files from the phase scope only.
  - Do not modify protected targets for rollback unless separately approved.
- Stop conditions:
  - Actual role model differs from `admin/staff`.
  - Owner role must be introduced in DB.
  - UI change requires runtime config, DB, deploy, or restart.
  - Tests reveal unrelated breakage outside approved phase scope.

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1 | Lock authorization helper | Coder/Executor | Code | No | Optional per approval |
| 2 | App shell icon badge and access filtering | Coder/Executor | Code | No | Optional per approval |
| 3 | Fines page internal guard | Coder/Executor | Code | No | Optional per approval |
| 4 | Tests and verification | Reviewer/Verifier | Test code if needed | Partly | Optional per approval |
| 5 | DB/RLS decision only | Governor/User | Doc or migration plan | Yes, if doc-only | Separate approval required |
| 6 | Completion docs | Governor | Docs | No | Optional per approval |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Test lane | After Phase 1 API shape is known | Inspect existing widget/provider tests and propose minimum tests for owner/admin vs staff UI controls. Do not modify unless assigned. | `test/`, `lib/app/view/app_shell.dart`, auth providers | Test plan or patch report | Main implementation reviewed first |
| DB/RLS lane | UI phases only if user asks for real server security | Inspect Supabase role/RLS policies for fines and propose migration plan. No DB writes. | `supabase/migrations/` | Protected DB phase proposal | Explicit DB approval required |

## 7. Phases

### Phase 1. Permission Contract Lock
Status: PLANNED

Purpose:
- Create one clear app-side authorization contract for owner/admin-only UI.

Scope:
- In:
  - Add or confirm reusable helper in `StaffAccount`, e.g. `canAccessOwnerOnlyOps` or `isOwnerOrAdmin`.
  - Current clean interpretation: existing `admin` role is the owner/admin role for this app until a real `owner` role is approved.
- Out:
  - No DB role migration.
  - No RLS policy change.

Files/Targets:
- `lib/features/auth/domain/staff_account.dart`

Execution Steps:
1. Inspect `StaffAccount` role helper.
2. Add a single reusable helper for restricted operations.
3. Keep role normalization centralized.

Verification:
- Static checks: `flutter analyze`
- Tests: existing auth/model tests if present, otherwise covered through UI tests in Phase 4.
- Harness/smoke: Not required.
- Manual review: Confirm no scattered new raw role string checks.

Completion Evidence:
- Code/doc evidence: helper added or documented.
- Test evidence: analyze/test output.
- Runtime/DB/external evidence, if applicable: Not applicable.

Review Gate:
- Reviewer: Reviewer/Verifier
- Required checks: helper semantics match current `admin/staff` model.
- Failure handling: stop if true `owner` DB role is required.

Completion Judgment:
- PASS criteria: one clean helper exists and does not introduce legacy/fallback role ambiguity.
- FAIL criteria: duplicated role checks or unverified owner role assumption.

Commit Gate:
- Stage scope: `lib/features/auth/domain/staff_account.dart`
- Commit message: `feat: add owner-only ops authorization helper`
- Commit only after: analyze/test pass and commit approval.

Next Phase Entry Criteria:
- Authorization helper is available.

Rollback/Compensation:
- Revert helper changes only.

### Phase 2. App Shell Homepage Badge and Access Filtering
Status: PLANNED

Purpose:
- Fix top overlap and prevent staff from opening homepage/fines from app shell.

Scope:
- In:
  - Replace `홈페이지 N` text button with compact `Icons.language_outlined` icon + numeric badge.
  - Hide or disable homepage pending action for non-owner/admin.
  - Filter or disable `OpsLayer.fines` for non-owner/admin.
  - If selected layer is fines and current user is unauthorized, reset to a safe layer.
  - Ensure `+` cannot launch fine notice creation for unauthorized users.
- Out:
  - No fines page internal refactor beyond app shell routing.

Files/Targets:
- `lib/app/view/app_shell.dart`
- Possibly `lib/app/domain/ops_layer.dart` only if clean metadata is needed.

Execution Steps:
1. Read current staff account from existing auth provider in app shell.
2. Compute `canAccessOwnerOnlyOps` once.
3. Render homepage pending icon badge only when authorized and pending count > 0.
4. Render switcher layers from an allowed layer list, not raw `OpsLayer.values` for staff.
5. Guard add/create action for fines.
6. Add safe selected-layer correction for unauthorized fines state.

Verification:
- Static checks: `flutter analyze`
- Tests: `flutter test`
- Harness/smoke: Manual narrow-width mobile review if available.
- Manual review: Confirm text `홈페이지 N` no longer consumes top width.

Completion Evidence:
- Code/doc evidence: app shell diff.
- Test evidence: analyze/test output.
- Runtime/DB/external evidence, if applicable: Not applicable.

Review Gate:
- Reviewer: Reviewer/Verifier
- Required checks: staff has no clickable fines/homepage action path from shell.
- Failure handling: fix within phase scope only.

Completion Judgment:
- PASS criteria: overlap risk removed and shell access blocked for staff.
- FAIL criteria: staff can still tap fines/homepage action or layout still uses wide homepage text.

Commit Gate:
- Stage scope: `lib/app/view/app_shell.dart`, optional `lib/app/domain/ops_layer.dart`
- Commit message: `fix: compact homepage badge and restrict owner ops tabs`
- Commit only after: analyze/test pass and commit approval.

Next Phase Entry Criteria:
- App shell no longer exposes restricted controls to staff.

Rollback/Compensation:
- Revert app shell changes only.

### Phase 3. Fine Notice Internal Guard
Status: PLANNED

Purpose:
- Prevent direct/future route access to fine notice UI by unauthorized users.

Scope:
- In:
  - Add page-level guard in `FineNoticePage` using the same authorization helper.
  - Ensure create/edit/generate/share affordances do not run for unauthorized users.
- Out:
  - No DB/RLS change.
  - No fine notice data model change.

Files/Targets:
- `lib/features/fines/presentation/fine_notice_page.dart`

Execution Steps:
1. Read current staff account in fines page.
2. If unauthorized, render a short blocked view instead of list/actions.
3. Confirm action callbacks are unreachable when blocked.

Verification:
- Static checks: `flutter analyze`
- Tests: `flutter test`
- Harness/smoke: Not required unless UI route harness exists.
- Manual review: Confirm blocked state is clear and non-destructive.

Completion Evidence:
- Code/doc evidence: fines page guard diff.
- Test evidence: analyze/test output.
- Runtime/DB/external evidence, if applicable: Not applicable.

Review Gate:
- Reviewer: Reviewer/Verifier
- Required checks: no unauthorized UI action path remains inside page.
- Failure handling: fix within fines page only.

Completion Judgment:
- PASS criteria: direct page render is blocked for staff.
- FAIL criteria: staff can still see or trigger fine notice actions.

Commit Gate:
- Stage scope: `lib/features/fines/presentation/fine_notice_page.dart`
- Commit message: `fix: guard fine notice page for owner ops access`
- Commit only after: analyze/test pass and commit approval.

Next Phase Entry Criteria:
- Internal guard exists.

Rollback/Compensation:
- Revert fines page guard only.

### Phase 4. Tests and Verification
Status: PLANNED

Purpose:
- Prove owner/admin and staff UI behavior does not regress.

Scope:
- In:
  - Add/update focused tests where existing test harness supports it.
  - Verify existing tests still pass.
- Out:
  - No broad test architecture rewrite.

Files/Targets:
- `test/widget_test.dart`
- Possible new `test/app_shell_permission_test.dart`

Execution Steps:
1. Add staff case: no fines layer selector, no homepage badge/action.
2. Add admin case: sees homepage icon+badge when pending exists and sees fines layer.
3. Run verification commands.

Verification:
- Static checks: `flutter analyze`
- Tests:
  - `flutter test`
  - `flutter test test/widget_test.dart` if targeted diagnosis is needed.
- Harness/smoke: Manual small-width app shell check if Flutter widget width coverage is insufficient.
- Manual review: Test names clearly describe owner/admin vs staff behavior.

Completion Evidence:
- Code/doc evidence: test diff.
- Test evidence: passing command output.
- Runtime/DB/external evidence, if applicable: Not applicable.

Review Gate:
- Reviewer: Reviewer/Verifier
- Required checks: test failures are not ignored.
- Failure handling: stop or fix within approved scope.

Completion Judgment:
- PASS criteria: analyze and tests pass, or any un-runnable check has a documented blocker.
- FAIL criteria: failing tests or no meaningful verification.

Commit Gate:
- Stage scope: touched test files and previously approved implementation files if one commit is chosen.
- Commit message: `test: cover owner-only app shell controls`
- Commit only after: verification pass and commit approval.

Next Phase Entry Criteria:
- UI behavior is verified.

Rollback/Compensation:
- Revert test changes only if tests are invalid.

### Phase 5. Server/RLS Decision Document or Migration Plan
Status: PLANNED

Purpose:
- Decide whether staff blocking must be a true server-side security boundary.

Scope:
- In:
  - Document current RLS gap.
  - If approved separately, prepare a migration plan restricting fine notice tables to admin/owner role.
- Out:
  - No DB apply under this PM without explicit DB approval.

Files/Targets:
- `supabase/migrations/` only if separately approved.
- Related docs under `docs/PHASE/` or `docs/HARNESS/`.

Execution Steps:
1. Confirm whether UI-only blocking is acceptable.
2. If not, draft DB/RLS phase with rollback plan.
3. Wait for explicit protected-action approval before any migration/apply.

Verification:
- Static checks: migration syntax check if created.
- Tests: project-approved DB verification path.
- Harness/smoke: Supabase local/diff path if configured.
- Manual review: Confirm policy does not block owner/admin.

Completion Evidence:
- Code/doc evidence: doc or migration plan.
- Test evidence: DB verification output if migration approved.
- Runtime/DB/external evidence, if applicable: only after explicit approval.

Review Gate:
- Reviewer: Reviewer/Verifier + user approval for protected action.
- Required checks: clear rollback and impact scope.
- Failure handling: do not apply DB changes.

Completion Judgment:
- PASS criteria: explicit decision recorded.
- FAIL criteria: DB protection is assumed but not implemented/approved.

Commit Gate:
- Stage scope: DB/doc files only if approved.
- Commit message: `docs: record owner-only ops server authorization decision` or migration-specific message.
- Commit only after: explicit DB/commit approval.

Next Phase Entry Criteria:
- User has decided UI-only vs server-side enforcement.

Rollback/Compensation:
- Docs revert for doc-only; DB rollback plan required for migration.

### Phase 6. Completion Docs
Status: PLANNED

Purpose:
- Keep project documentation aligned after implementation.

Scope:
- In:
  - Update completed work summary after verified implementation.
  - Archive this PM after all approved phases are verified/reviewed/committed.
- Out:
  - No unrelated doc cleanup.

Files/Targets:
- `docs/COMPLETED/`
- This PM document under `docs/PHASE/`

Execution Steps:
1. Summarize completed implementation and verification.
2. Record residual risk: UI-only does not replace DB/RLS if server boundary is required.
3. Move/copy PM to completed archive only when completion criteria are met.

Verification:
- Static checks: direct doc review.
- Tests: Not applicable.
- Harness/smoke: Not applicable.
- Manual review: Docs match actual implementation.

Completion Evidence:
- Code/doc evidence: completed doc path.
- Test evidence: implementation phase verification references.
- Runtime/DB/external evidence, if applicable: Not applicable.

Review Gate:
- Reviewer: Governor final review.
- Required checks: completion doc does not overclaim DB security.
- Failure handling: keep PM in PHASE until accurate.

Completion Judgment:
- PASS criteria: docs accurately reflect implementation and residual risks.
- FAIL criteria: docs claim server-side restriction without DB/RLS work.

Commit Gate:
- Stage scope: docs only.
- Commit message: `docs: complete owner ops UI access control plan`
- Commit only after: commit approval.

Next Phase Entry Criteria:
- Implementation and verification are done.

Rollback/Compensation:
- Revert doc changes only.

### Final Completion Report
- Completed phases: Phases 1-4 and Phase 6 completed for the approved UI scope. Phase 5 DB/RLS work was not approved and remains a separate protected decision.
- Commits: Pending at document update time.
- Verification summary: `git diff --check` passed; reviewer reported `flutter analyze`, `flutter test test/widget_test.dart`, and full `flutter test` passed with 23 tests.
- Residual risks:
  - Current confirmed roles are `admin` and `staff`; real `owner` role does not exist yet.
  - UI restriction alone does not enforce Supabase/RLS security.
- Follow-up work:
  - Decide separately whether DB/RLS enforcement is required for a true server-side boundary.
