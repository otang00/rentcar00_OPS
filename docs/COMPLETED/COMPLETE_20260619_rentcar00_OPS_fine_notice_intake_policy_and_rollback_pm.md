# rentcar00_OPS Fine Notice Intake Policy and Rollback PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료/주정차/통행료 임차인 변경 intake 정책 재잠금
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_gangnam_multi_parser_micro_pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
- Current status: Completed / Superseded by integrated PM
- Approval scope: 완료된 정책 기준 문서. 후속 실행은 `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md` 기준으로 승인 필요.
- Archive target: already archived in `docs/COMPLETED/`

## 0. Goal Lock
- Objective: b52 기준 과태료 intake가 복잡해지기 전에 소유차량 판정, 다중 row 고지서, 납부기한 제거, profile별 핵심정보 차이, 롤백 기준을 먼저 잠근다.
- Final success condition: 고지서 사진 1장 또는 수동 입력 1건이 `처리 대상 여부`와 `처리건 단위`로 분리되고, 계약검색/문서생성은 우리 관리 차량의 row-level 처리건에서만 진행된다.
- Explicit non-goals:
  - 즉시 문서 생성/제출 구현
  - 정책 없이 profile별 제출 채널 자동 판단
  - AI 파서 결과만으로 계약자 확정
  - DB drop 또는 과거 데이터 삭제
  - b52 이후 추가 APK 업로드
- Protected targets:
  - Supabase production DB and existing fine notice rows
  - Mac mini SSD `storage/fine-notices`
  - IMS live APIs
  - parser public URL `https://parser.00rentcar.com`
  - GDrive APK folder
- Approval required for:
  - DB schema/migration for multi-row split/batch grouping
  - existing fine notice data migration
  - app/parser code changes
  - parser restart/deploy
  - APK build/upload
  - rollback to b50 or feature hide
  - commit/push

## 1. Current State Evidence
- Repo status:
  - branch: `fix/ops-return-complete-end-at`
  - HEAD: `05efdba docs: record b50 APK release`
  - app version/build in working tree: `1.0.0+52`
  - GDrive latest APK: `rentcar00_ops-app-release-arm64-b52-05efdba.apk`
  - current worktree is dirty and includes fine notice MVP, b52 hotfix, docs, migration, parser, and app files.
- Existing implementation:
  - fine notice case is currently mostly one case = one processing unit.
  - `FineNoticeCase` includes `dueDate`.
  - fine notice list previously displayed `납기`; Phase 2에서 제거됨.
  - create dialog previously included `납부기한`; Phase 2에서 제거됨.
  - parser still preserves raw `dueDate`, but Phase 2부터 `dueDate_missing`을 경고하지 않음.
  - parser prompt already asks for `items[]` on multi-row toll notices, but app/DB flow does not yet split rows into separate fine notice ledger entries.
  - ownership/managed-car guard is implemented against `rc00_ops_cars.car_number` before save/contract search.
- Existing docs/specs:
  - MVP foundation PM closed at `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`.
  - next operational gate PM exists at `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`.
  - b51/b52 hotfix PM is completed at `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`.
- Existing tests/harness:
  - `flutter analyze`
  - `flutter test`
  - `npm --prefix reservation_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run check`
  - public parser fixture smoke
- Known conflicts or drift:
  - Multi-row notices such as 강남순환도로/우면산 can contain multiple usage rows in one notice image.
  - Row dates can be missing or misread, which blocks correct contract matching.
  - 2026-06-19 강남순환도로 4건 실사진 public parser smoke: row count/차량번호/장소/금액은 잡았지만 row별 `occurredAt`이 전부 `null`로 나와 Phase 5에서 보강 필요.
  - 납부기한 is not a core processing field and currently creates noise in UI/parser warnings.
  - Some vehicle numbers can be branch/external vehicles, which must not enter our renter-change workflow.

## 2. Locked Policy Draft

### 2.1 Processing Ownership
- AI parser is only an assistant.
- Human confirmation remains mandatory before contract search/document generation/submission.
- Contract search must use row-level `carNumber + occurredAt`.
- `dueDate` is not a required field for intake, contract search, document generation, or submission routing.

### 2.1.1 Intake Route Policy
- Manual input is the base route.
- If the user enters values manually and taps save, the app creates the fine notice ledger entry from those values.
- The AI parser is an auto-fill helper, not the final decision maker.
- If AI parser output satisfies the required data contract:
  - single-row notice: fill and create one ledger candidate/entry.
  - multi-row notice: create one independent ledger candidate/entry per row.
  - each generated row still follows ownership guard and row-level contract search rules.
- If AI parser output does not satisfy the required data contract:
  - define the result as `parse_failed`.
  - keep any extracted values in the manual input modal.
  - show the user that parsing failed and manual confirmation/input is required.
  - do not auto-create split ledger entries.
  - continue through the manual input route.
- AI parse failure is not a dead end; it is a prefilled manual form state.

### 2.2 Vehicle Ownership Guard
- Every parsed/manual row must be checked against OPS managed vehicle data before contract search.
- If the vehicle is not our managed vehicle:
  - show message: `우리 소유/관리 차량이 아닙니다. 지사/외부 차량 처리 대상입니다.`
  - mark the processing item as `not_our_vehicle` or equivalent.
  - do not run IMS contract search.
  - do not generate renter-change documents.
  - keep the original notice/photo metadata only for audit if the case was saved.
- This guard must be DB/vehicle-master based, not AI-based.

### 2.3 Multi-row Split and Optional Batch Group
- Do not create a required parent notice ledger/table for the original notice image.
- Each visible violation/toll/parking row becomes its own `rc00_ops_fine_notices` ledger entry.
- Single-row notices create one ledger entry.
- Multi-row notices create one ledger entry per visible row.
- Each split ledger entry owns its own contract search, renter confirmation, document generation, status, and submission state.
- The original photo/file metadata can be duplicated or referenced per ledger entry as needed for audit.
- If later submission requires sending multiple split rows together, use an optional `batch/group` key to group entries for one bundled submission.
- The batch/group is only a submission convenience, not the source of truth for contract/document state.

### 2.4 Required Row-Level Fields
- Required for contract search:
  - `noticeProfile`
  - `carNumber`
  - `occurredAt` or `passAt`
- Required for review/display:
  - `issuer` or source/profile label when visible
  - `location` when visible
  - `amount` or `totalAmount` when visible
- Optional/raw only:
  - `dueDate`
  - payment account/OCR/payment number
  - original document number / batch key
- If row-level date is missing:
  - AI parser result is `parse_failed` for auto-add purposes.
  - parser must try profile-specific second-pass reinforcement when the profile supports it.
  - if second-pass still fails, the UI keeps extracted values in the modal and asks for manual date entry.
  - no IMS contract search is allowed for that row.

### 2.4.1 Parser Reinforcement Policy
- First pass reads the full notice image.
- If first pass is complete, the parser can return split ledger candidates.
- If first pass identifies a multi-row toll profile but row-level dates are missing, run second-pass reinforcement before app save/search.
- For 강남순환도로, second pass must focus on the toll table and force the columns:
  - `번호`
  - `통행일시`
  - `통행료`
  - `부가통행료`
  - `통행장소`
- Second-pass output may fill missing row fields, but must not infer invisible dates or years.
- If second pass still leaves missing row dates, return `parse_failed` / `manual_row_review_required`; do not auto split-save and do not run IMS contract search.

### 2.5 Due Date Removal
- Remove `납부기한` from the primary line/card display.
- Remove `납부기한` from the required manual intake path.
- Parser may keep due date in raw JSON for reference, but must not warn on `dueDate_missing`.
- Existing DB column can remain for compatibility unless a later cleanup phase explicitly approves removal.

### 2.6 Profile-Specific Complexity
- Each notice profile can require different important fields, document outputs, and submission channels.
- Profile policy must be closed one by one.
- Unknown profiles stay in `policy_needed` or equivalent state.
- Do not implement a generic submit-all path.

### 2.7 Rollback Baseline
- First stable rollback point:
  - Git commit: `05efdba docs: record b50 APK release`
  - APK baseline: `rentcar00_ops-app-release-arm64-b50-74649e2.apk`
  - Meaning: pre-fine-MVP stable operating baseline.
- Runtime parser rollback:
  - return `reservation_ai_parser` to reservation-only behavior if fine parser route causes instability.
  - must preserve existing reservation/IMS endpoints.
- Data rollback:
  - do not drop `rc00_ops_fine_notices` or `rc00_ops_fine_notice_files` without separate approval.
  - safest rollback is feature hide/disable, leaving rows dormant.
- Release rollback:
  - upload a superseding APK based on b50 baseline or feature-hidden build only after explicit approval.
- Stop condition:
  - if multi-row split/batch handling and ownership guard make the flow too large, stop and choose between `feature hide`, `single-row manual mode`, or `full rollback to b50 baseline`.

## 3. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Vehicle ownership | Contract search can start from parsed car number | Managed-car guard before contract search | Branch/external vehicles are not our workflow |
| Multi-row notices | One notice case acts like one processing unit | Split visible rows into separate ledger entries, with optional batch group | One image can contain rows for different renters, but each row is processed independently |
| AI parser route | Parser success/failure mixed with manual save | Parser success auto-fills/adds; parser failure pre-fills manual modal only | Keep AI helpful without making bad ledgers |
| Missing date | Parser result can save without row date | Missing row date means parse_failed for auto-add and manual route continues | Contract matching depends on date |
| Due date | Displayed and warned as missing | Raw-only/non-critical, removed from primary line | Not needed for renter-change workflow |
| Complexity control | Feature keeps expanding | Rollback baseline and stop choices locked | Avoid unbounded MVP growth |

## 4. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Data model | `rc00_ops_fine_notices`, possible batch/group fields | Medium | Schema may need grouping fields, but parent table is not required | PM first; no schema write without approval |
| Parser | `fine_notice_ai_parser/src/parser-core.js`, fixtures | Medium | multi-row date misses | profile fixtures and row validation |
| App UI | `lib/features/fines/*` | High | user confusion | review modal and row-level status |
| Contract matching | IMS candidate search | Medium | wrong renter if parent-level only | row-level guard |
| Rollback | APK/parser/feature visibility | Medium | data left behind | feature hide and no DB drop |

## 5. Execution Policy
- Approval model: `pa` approves only Phase 1 unless a phase range is specified.
- Phase transition rule: no DB migration before Phase 1 policy review is accepted.
- Review rule: each notice profile is closed independently with sample evidence.
- Commit rule: no commit without explicit approval.
- Rollback/compensation rule:
  - code/app rollback via revert or feature hide.
  - DB tables remain dormant unless cleanup is explicitly approved.
  - uploaded APK rollback is done by superseding APK, not deleting history blindly.
- Stop conditions:
  - row-level model requires ambiguous DB migration
  - vehicle ownership source cannot be verified
  - parser cannot reliably extract row dates for a profile
  - submission documents differ by profile but policy is unknown

## 6. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. Policy Close and Rollback Gate | Lock ownership/multi-row/dueDate/rollback policy | Codex + 사장님 | docs | No | Required |
| 2. Due Date De-scope | Remove due date from primary UI/required warnings | Codex | code/parser | Yes after Phase 1 | Required |
| 3. Ownership Guard Design | Identify managed vehicle source and block non-owned rows | Codex | code possibly | No | Required |
| 4. Multi-row Split/Batch Model PM | Decide schema/migration for row split and optional bundled submission | Codex | docs/DB plan | No | Required before DB |
| 5. Parser Row Fixture Validation | Validate profile별 row extraction, especially dates | Codex | parser fixtures/tests | Yes after Phase 4 plan | Required |
| 6. Multi-row Review UI MVP | Let user confirm each row before saving/search | Codex | code/DB if approved | No | Required |
| 7. Rollback or Continue Review | Decide whether to continue, feature-hide, or rollback | Codex + 사장님 | docs/release optional | No | Required |

## 7. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Vehicle source audit | Parser fixture validation | Find current OPS managed vehicle source/table and how to test ownership by car number. No writes. | repository, Supabase access pattern | ownership source report | primary review |
| Profile field matrix | Vehicle source audit | Draft profile별 required row fields and document outputs. No code. | sample notices, PM docs | matrix | 사장님 review |
| Parser fixture review | Profile field matrix | Inspect fixtures for 우면산/강남순환도로 and list missing row date risks. No code. | `fine_notice_ai_parser/src/fixtures` | parser risk report | primary review |

## 8. Phases

### Phase 1. Policy Close and Rollback Gate
Status: COMPLETED

Purpose:
Close the intake policy before changing code or DB.

Scope:
- In:
  - managed vehicle guard rule
  - row split / optional batch grouping rule
  - row-level required fields
  - due date de-scope
  - rollback baseline and stop conditions
- Out:
  - code changes
  - DB migration
  - parser restart/deploy
  - APK build/upload

Files/Targets:
- this PM document
- `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
- `docs/GOAL/rentcar00_OPS-current.md`

Execution Steps:
1. Review this policy with 사장님.
2. Mark accepted/rejected points.
3. If accepted, update remaining phase PM dependencies.
4. If rejected, choose rollback/feature hide path.

Verification:
- Static checks: `git diff --check` pending after doc/code finalization
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 approved execution with `pa 1-3`.

Completion Evidence:
- Code/doc evidence: accepted policy doc; rollback baseline locked to `05efdba` / b50 APK
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: rollback point, ownership guard, multi-row model, dueDate removal
- Failure handling: stop and choose rollback/feature hide

Completion Judgment:
- PASS criteria: no implementation ambiguity remains for next phase.
- FAIL criteria: ownership source or split/batch model remains unclear.

Commit Gate:
- Stage scope: policy docs only
- Commit message: `docs: lock fine notice intake policy`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Policy accepted.

Rollback/Compensation:
Document revert.

### Phase 2. Due Date De-scope
Status: COMPLETED

Purpose:
Remove due date from the primary workflow so it no longer distracts from contract matching.

Scope:
- In:
  - remove due date chip from list/card
  - remove due date manual field from primary dialog
  - stop parser warning `dueDate_missing`
  - keep raw value if returned
- Out:
  - DB column removal
  - historical data cleanup

Files/Targets:
- `lib/features/fines/presentation/fine_notice_page.dart`
- `fine_notice_ai_parser/src/parser-core.js`
- fixtures/tests if needed

Execution Steps:
1. Remove due date from main UI line.
2. Remove due date from required/manual intake surface.
3. Stop dueDate missing warnings.
4. Keep backward-compatible model field until schema cleanup is approved.

Verification:
- Static checks: `dart format`, `flutter analyze`, parser check, `git diff --check`
- Tests: `flutter test`
- Harness/smoke: parse fixture without dueDate warning
- Manual review: UI no longer highlights 납부기한

Completion Evidence:
- Code/doc evidence:
  - `lib/features/fines/presentation/fine_notice_page.dart`
  - `fine_notice_ai_parser/src/parser-core.js`
- Test evidence:
  - `flutter analyze`
  - `flutter test test/fine_notice_models_test.dart`
  - `npm --prefix fine_notice_ai_parser run check`
  - ESM parser smoke confirmed warnings `[]` when `dueDate` is absent.
- Runtime/DB/external evidence:
  - `reservation_ai_parser` restarted so public `/parse-fine-notice` reflects the warning policy.
  - public fixture smoke confirmed no `dueDate_missing`.

Review Gate:
- Reviewer: 사장님
- Required checks: 납부기한 no longer primary
- Failure handling: revert dueDate de-scope

Completion Judgment:
- PASS criteria: dueDate is raw-only/non-blocking.
- FAIL criteria: dueDate still blocks/requires review.

Commit Gate:
- Stage scope: approved UI/parser/test docs
- Commit message: `fix: de-scope fine notice due dates`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Due date no longer blocks intake.

Rollback/Compensation:
Revert UI/parser changes.

### Phase 3. Ownership Guard Design
Status: COMPLETED

Purpose:
Prevent non-owned/branch/external vehicles from entering our renter-change workflow.

Scope:
- In:
  - identify managed vehicle source
  - car number normalization
  - non-owned status/message
  - block contract search/doc generation
- Out:
  - deleting external vehicle notices
  - AI-based ownership judgement

Files/Targets:
- `lib/features/fines/*`
- vehicle repository/provider source after audit
- tests

Execution Steps:
1. Found existing vehicle master query path: `rc00_ops_cars.car_number`.
2. Implemented lookup before save and before contract search.
3. Marked non-owned rows as `not_our_vehicle` and display message.
4. Kept DB schema unchanged; no multi-row split/batch migration in this phase.

Verification:
- Static checks: `flutter analyze`, `git diff --check`
- Tests: `flutter test test/fine_notice_models_test.dart`
- Harness/smoke: manually input external car number and confirm block
- Manual review: 사장님 confirms message

Completion Evidence:
- Code/doc evidence:
  - `lib/features/fines/data/fine_notice_repository.dart`
  - `lib/features/fines/domain/fine_notice_models.dart`
  - `lib/features/fines/presentation/fine_notice_page.dart`
- Test evidence:
  - `flutter analyze`
  - `flutter test test/fine_notice_models_test.dart`
- Runtime/DB/external evidence:
  - no DB migration.
  - guard uses existing Supabase table `rc00_ops_cars`.

Review Gate:
- Reviewer: 사장님
- Required checks: correct source and message
- Failure handling: keep notice in `review_needed`

Completion Judgment:
- PASS criteria: non-owned vehicles cannot proceed to contract search.
- FAIL criteria: AI or manual typo can bypass ownership guard.

Commit Gate:
- Stage scope: guard code/tests/docs
- Commit message: `feat: guard non-owned fine notice vehicles`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Ownership source verified.

Rollback/Compensation:
Disable guard or revert; no data deletion.

### Phase 4. Multi-row Split/Batch Model PM
Status: PLANNED

Purpose:
Decide the DB/app model for splitting multi-row notices into separate ledger entries before implementation.

Scope:
- In:
  - split row -> independent fine notice ledger decision
  - optional batch/group key for bundled submission
  - migration/backfill strategy if grouping fields are needed
  - status ownership per ledger entry
  - file metadata duplication/reference strategy
- Out:
  - migration execution
  - UI implementation

Files/Targets:
- this PM or new DB PM
- `supabase/migrations/*` only after later approval

Execution Steps:
1. Decide whether current `rc00_ops_fine_notices` can represent every split row directly.
2. Decide optional group fields such as `source_batch_id`, `source_row_index`, and shared original document metadata.
3. Define file metadata handling when one photo produces multiple ledger entries.
4. Define migration/backfill from existing one-case rows only if needed.
5. Define rollback/feature-hide behavior.

Verification:
- Static checks: document review, `git diff --check`
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 approves DB direction

Completion Evidence:
- Code/doc evidence: DB phase PM
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: schema direction, optional bundled submission grouping, and rollback
- Failure handling: stay in single-row manual mode

Completion Judgment:
- PASS criteria: migration implementer can proceed without guessing.
- FAIL criteria: row/status ownership or batch grouping remains ambiguous.

Commit Gate:
- Stage scope: DB PM docs only
- Commit message: `docs: plan fine notice multi-row split schema`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
DB migration approval only if split/batch fields are needed.

Rollback/Compensation:
Document revert.

### Phase 5. Parser Row Fixture Validation
Status: PLANNED

Purpose:
Validate that each known notice profile produces reliable row-level items before app UI relies on it.

Entry Gate:
- 강남순환도로 4건 실사진은 먼저 `docs/PHASE/rentcar00_OPS-fine-notice-gangnam-multi-parser-micro-pm.md`에서 연속 5회 성공 기준을 통과해야 한다.

Scope:
- In:
  - 강남순환도로 multi-row
  - 우면산 multi-row/single-row
  - row date extraction
  - missing date warnings
  - profile-specific required fields
- Out:
  - app DB changes
  - contract search

Files/Targets:
- `fine_notice_ai_parser/src/fixtures/*`
- `fine_notice_ai_parser/src/fixtures/images/gangnam_sunhwan_4rows_20260506_20260512.jpg`
- `fine_notice_ai_parser/src/fixture-check.js`
- parser tests/simulate docs

Execution Steps:
1. Keep the 4-row 강남순환도로 real-photo fixture as the baseline sample.
2. Define expected split ledger candidates:
   - `142호2673`
   - 4 rows
   - `2026-05-06 09:45:25 / 금천 / 1900`
   - `2026-05-06 15:49:59 / 금천 / 1900`
   - `2026-05-06 15:59:50 / 선암 / 1900`
   - `2026-05-12 13:09:43 / 선암 / 1900`
3. Run fixture assertion check.
4. Run real-photo parser smoke.
5. Mark profile blocked if row dates fail.
6. Only after row dates pass, move to split ledger save UI.

Verification:
- Static checks: `npm --prefix fine_notice_ai_parser run check`
- Tests: `npm --prefix fine_notice_ai_parser run fixture-check`
- Harness/smoke:
  - public parser real-photo smoke
  - expected: 4 items with row-level dates
  - current baseline: 4 items returned, but row-level dates are missing
- Manual review: 사장님 checks profile evidence

Completion Evidence:
- Code/doc evidence: fixtures/expected output
- Test evidence: parser checks
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: row count/date/amount/car number
- Failure handling: require manual row entry for that profile

Completion Judgment:
- PASS criteria: known profiles produce usable row-level data or clear manual-required state.
- FAIL criteria: multi-row notices collapse into one item or miss row dates silently.

Commit Gate:
- Stage scope: parser fixtures/tests/docs
- Commit message: `test: validate fine notice multi-row parsing`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Known multi-row profiles validated.

Rollback/Compensation:
Revert parser fixture/test changes.

### Phase 6. Multi-row Review UI MVP
Status: PLANNED

Purpose:
Let the user review and confirm each parsed row before saving or contract search.

Scope:
- In:
  - original notice preview
  - row list review modal
  - row-level manual date/car/amount edit
  - row-level save/search readiness
- Out:
  - document generation
  - external submission

Files/Targets:
- `lib/features/fines/*`
- DB repository after Phase 4 migration approval

Execution Steps:
1. Show parser rows before save.
2. Require row date for contract-ready rows.
3. Save one ledger entry per visible row.
4. Allow contract search per ledger entry only.

Verification:
- Static checks: `flutter analyze`, `git diff --check`
- Tests: row review state tests
- Harness/smoke: fixture with 4 rows creates 4 review rows
- Manual review: 사장님 validates UI with 강남순환도로/우면산 sample

Completion Evidence:
- Code/doc evidence: UI/repository diff
- Test evidence: Flutter tests
- Runtime/DB/external evidence, if applicable: approved DB smoke

Review Gate:
- Reviewer: 사장님
- Required checks: row count, date entry, ownership guard, per-row contract search
- Failure handling: revert to manual single-row intake

Completion Judgment:
- PASS criteria: one notice image can create multiple independently processable ledger entries.
- FAIL criteria: rows are merged into one renter workflow.

Commit Gate:
- Stage scope: approved UI/DB/repository/tests/docs
- Commit message: `feat: review multi-row fine notices`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Multi-row review accepted.

Rollback/Compensation:
Feature hide or revert; generated rows remain dormant unless cleanup approved.

### Phase 7. Rollback or Continue Review
Status: PLANNED

Purpose:
Decide whether the expanded fine notice flow remains worth continuing or should be rolled back/hidden.

Scope:
- In:
  - complexity review
  - b50 rollback feasibility
  - feature-hide option
  - continue criteria
- Out:
  - unapproved rollback APK
  - DB deletion

Files/Targets:
- docs/current/completed
- APK only if explicitly approved

Execution Steps:
1. Review implementation complexity after phases 1-6.
2. If too complex, choose:
   - hide fine notice tab,
   - single-row manual mode,
   - rollback APK to b50 baseline.
3. If continuing, proceed to remaining phases PM.

Verification:
- Static checks: document review
- Tests: only if code path selected
- Harness/smoke: only if feature hide/release selected
- Manual review: 사장님 decision

Completion Evidence:
- Code/doc evidence: decision record
- Test evidence: as applicable
- Runtime/DB/external evidence, if applicable: APK/GDrive listing if rollback release approved

Review Gate:
- Reviewer: 사장님
- Required checks: complexity, operational usefulness, rollback cost
- Failure handling: freeze fine notice feature

Completion Judgment:
- PASS criteria: continue/rollback decision is explicit.
- FAIL criteria: feature keeps expanding without decision.

Commit Gate:
- Stage scope: approved decision/code/docs
- Commit message: `docs: decide fine notice continuation`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Decision complete.

Rollback/Compensation:
Use first stable rollback point: commit `05efdba`, APK b50, parser reservation-only route, DB dormant.

### Final Completion Report
- Completed phases: Phase 1, Phase 2, Phase 3
- Commits: none
- Verification summary:
  - policy document updated from b52 runtime findings and 사장님 decisions
  - due date removed from primary 과태료 UI and parser required warning
  - non-managed vehicles are blocked from contract search with message
  - public parser route restarted and smoke-tested
- Residual risks:
  - ownership guard is exact `rc00_ops_cars.car_number` matching; OCR spacing/typos still require manual correction
  - split/batch schema may require DB migration
  - known multi-row profiles still need fixture validation
  - APK has not been rebuilt/uploaded after Phase 1-3 source changes
- Follow-up work:
  - Phase 4 split/batch DB PM before any multi-row implementation
  - then profile fixture validation for 강남순환도로/우면산 row dates
