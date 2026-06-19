# rentcar00 OPS Fine Notice Storage Root Correction Micro PM

## Document Metadata
- Created at: 2026-06-19 KST
- Last updated at: 2026-06-19 KST
- Author/agent: Codex
- Related milestone: Fine notice document generation MVP unblock
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
- Current status: Completed
- Execution scope: Correct fine notice runtime storage root, migrate affected files, correct DB file metadata, delete stale abnormal file metadata if found, restart parser, verify storage writes, then resume document generation smoke.
- Archive target: `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_storage_root_correction_micro_pm.md`

## 0. Goal Lock
- Objective: Make all fine notice original/generated files resolve to the official project storage root `storage/fine-notices`, which is symlinked to `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices`.
- Final success condition:
  - `reservation_ai_parser` uses `FINE_NOTICE_STORAGE_ROOT` at runtime.
  - DB `rc00_ops_fine_notice_files.local_path` no longer points to `reservation_ai_parser/storage/fine-notices` for the active test rows.
  - Existing active files are present under the official storage root.
  - Parser restart and smoke checks prove new writes land under the official root.
  - Fine notice document generation can resume without path mismatch.
- Explicit non-goals:
  - No parser architecture refactor beyond storage-root correction.
  - No broad cleanup of unrelated historical fine notice files.
  - No deletion of orphan files until an audit confirms they are not referenced.
  - No change to Supabase schema in this micro PM.
  - No app UI change in this micro PM.
- Protected targets:
  - `reservation_ai_parser/.env`
  - launchd service `ai.otang.reservation-ai-parser`
  - Supabase table `rc00_ops_fine_notice_files`
  - local/SSD file storage under `storage/fine-notices`
- Execution scope includes:
  - Env key addition for storage root.
  - File copy/move for affected fine notice files.
  - DB metadata path correction for affected file rows.
  - Deletion of stale abnormal file metadata only after canonical metadata is confirmed and only when the row is not required by an active approved fine notice.
  - Parser restart and public endpoint smoke.
  - PM/document updates for actual path evidence.

## 1. Current State Evidence
- Repo status:
  - Working tree is dirty before this micro PM.
  - Existing fine notice/document generation work has already modified `reservation_ai_parser/package.json`, `reservation_ai_parser/package-lock.json`, and `reservation_ai_parser/src/server.js`.
  - This micro PM must not revert or stage unrelated dirty files.
- Existing implementation:
  - `reservation_ai_parser/src/parser-core.js` resolves storage root from `env.FINE_NOTICE_STORAGE_ROOT` or falls back to `path.resolve(env.INIT_CWD || process.cwd(), 'storage/fine-notices')`.
  - `fine_notice_ai_parser/src/parser-core.js` has the same fallback pattern.
  - Runtime launchd service runs inside `reservation_ai_parser`, so without `FINE_NOTICE_STORAGE_ROOT`, files land in `reservation_ai_parser/storage/fine-notices`.
  - `reservation_ai_parser/.env.example` contains `FINE_NOTICE_STORAGE_ROOT`, but `reservation_ai_parser/.env` currently does not.
- Existing docs/specs:
  - Project docs define official storage as project `storage/fine-notices`.
  - `storage` is currently a symlink to `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage`.
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md` currently records a smoke output path under `reservation_ai_parser/storage/fine-notices`, which is drift from policy.
- Existing tests/harness:
  - `npm --prefix reservation_ai_parser run check`
  - public parser endpoints:
    - `GET /health`
    - `POST /parse-fine-notice`
    - `POST /fine-notices/save-contract-pdf`
    - `POST /fine-notices/generate-documents` after generator route is live
  - Supabase REST read/update checks for `rc00_ops_fine_notice_files`.
- Known conflicts or drift:
  - Official root exists: `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices`.
  - Project path exists through symlink: `storage/fine-notices`.
  - Runtime drift root exists: `reservation_ai_parser/storage/fine-notices`.
  - DB currently has 3 file metadata rows whose `local_path` points to the runtime drift root:
    - `1d87e153-5e94-4231-a812-c755651da894` role `contract_original`, fine notice `5ec6b200-d553-443c-85f6-03ba1e99b738`
    - `d203aa44-84d4-4ba5-935a-2b9eba351e10` role `notice_original`, fine notice `5ec6b200-d553-443c-85f6-03ba1e99b738`
    - `5e2583fc-d519-466b-adae-eb4381edb909` role `notice_original`, fine notice `01747ecf-d9f7-4764-bc75-239532b4f639`
  - Disk also contains additional incoming images under `reservation_ai_parser/storage/fine-notices/incoming/20260619/`; these must be audited before deletion.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Runtime storage root | Parser falls back to `reservation_ai_parser/storage/fine-notices` because runtime `.env` lacks `FINE_NOTICE_STORAGE_ROOT`. | Runtime `.env` explicitly points to project/SSD fine notice root. | Prevent future files from being saved outside the documented storage policy. |
| Active file bytes | Active smoke files exist under runtime drift root. | Active files exist under official storage root with the same relative paths. | Keep DB metadata and filesystem policy aligned. |
| DB file metadata | 3 active file rows point to `reservation_ai_parser/storage/fine-notices`. | Those rows point to official `storage/fine-notices`/SSD paths; any leftover abnormal stale metadata is deleted only if not required by active rows. | App/backend file access and generated document flow must read the canonical path and must not retain stale drift metadata. |
| Document generation PM evidence | Existing smoke evidence records drift path. | Evidence updated to show corrected path and correction PM reference. | Avoid future agents following stale path evidence. |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Runtime config | `reservation_ai_parser/.env` | Short blocker before generator smoke | Wrong env path could send files to a non-mounted or unintended path | Verify directory exists before restart; smoke write after restart |
| File storage | `reservation_ai_parser/storage/fine-notices`, `storage/fine-notices`, SSD root | Required before continuing Phase 7 | Copy/move mistakes, duplicate files, stale files | Hash/size check before and after; do not delete unreferenced files during first pass |
| DB metadata | `rc00_ops_fine_notice_files` | Required for active test rows | Incorrect path update/delete could detach files from rows | Update only rows with known IDs; delete only stale abnormal rows after re-query proves they are not active; re-query after PATCH/DELETE |
| Parser service | launchd label `ai.otang.reservation-ai-parser` | Requires restart | Existing route changes go live together with config correction | Run `npm check` before restart; smoke known public endpoints after restart |
| Docs | Phase PM docs | Low | Stale path evidence can mislead later phases | Update only affected PM evidence sections |
| App/UI | Not in scope | None | None verified | Excluded |

## 4. Execution Policy
- Execution model:
  - This is a micro PM that blocks document generation continuation.
  - If approved with `pa all`, execute every phase in order without asking for per-phase approval again.
- Phase transition rule:
  - Continue from one phase to the next only after its verification passes.
  - Stop if a new storage root, DB row, service label, or file role appears outside this document.
- Review rule:
  - Each phase must record exact evidence without printing secrets or raw sensitive renter/customer data.
- Commit rule:
  - One final commit is allowed only after all phases verify and docs match implementation.
  - Do not stage unrelated dirty work unless it is explicitly part of this PM or prior approved fine notice PM scope.
- Rollback/compensation rule:
  - Env change can be reverted to previous `.env` line set.
  - DB path updates must record old path before patching and can be patched back if verification fails.
  - File moves should be implemented as copy plus hash/size verification first; deletion is deferred.
- Stop conditions:
  - `storage` symlink target changes or SSD path is not mounted.
  - `.env` contains a different intended storage root that contradicts project docs.
  - DB query finds more active referenced rows under drift root than the 3 listed above.
  - Official root is not writable.
  - Restarted parser fails health/smoke checks.
  - Generated/stored file path escapes official storage root.

## 5. Phase Map
| Phase | Responsibility Unit | Owner | State Change | Scope Lock Summary | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Preflight and target lock | Codex | No | Read-only env key, symlink, DB/file inventory | No | No |
| 2 | Runtime config correction | Codex | Yes | Add storage root env key only | No | Final only |
| 3 | Active file migration | Codex | Yes | Copy active referenced files to official root | No | Final only |
| 4 | DB metadata correction and stale cleanup | Codex | Yes | Patch known affected rows; delete only stale abnormal metadata not required by active rows | No | Final only |
| 5 | Parser restart and storage smoke | Codex | Yes | Restart parser, verify public endpoints and new path | No | Final only |
| 6 | Resume document generation smoke | Codex | Yes | Run approved generator smoke for active fine notice rows | No | Final only |
| Final | Completion judgment / docs / commit | Codex | Yes | Update docs, review, commit scoped files | No | Yes |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| None | Not applicable | Not applicable | Not applicable | Not applicable | Storage config, file movement, DB metadata, and restart all depend on sequential evidence and should not be parallelized. |

## 7. Phases

### Phase 1. Preflight and Target Lock
Status: PLANNED

Purpose:
Lock exact current storage, DB, runtime, and file evidence before any state change.

Work:
1. Verify `reservation_ai_parser/.env` contains no `FINE_NOTICE_STORAGE_ROOT` value without printing secrets.
2. Verify `storage -> /Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage` symlink.
3. Verify official root exists and is writable.
4. Query DB rows whose `local_path` contains `reservation_ai_parser/storage/fine-notices`.
5. Inventory runtime drift files under `reservation_ai_parser/storage/fine-notices`.

Reason:
Avoid moving or patching the wrong files and avoid expanding scope silently.

Scope:
- In: read-only env key names, symlink metadata, file list, DB metadata rows.
- Out: env write, DB write, file move, restart.

Files/Targets:
- `reservation_ai_parser/.env`
- `storage`
- `storage/fine-notices`
- `reservation_ai_parser/storage/fine-notices`
- `rc00_ops_fine_notice_files`

Scope Lock:
- Modification allowed: none
- Creation allowed: none
- Deletion allowed: none
- Read-only references: listed files/targets only
- Excluded targets: app UI, Supabase schema, unrelated storage folders
- Behaviors not to change: parser runtime, DB data, file bytes
- Outputs: preflight evidence summary
- Scope drift criteria: DB finds additional active rows or official root is not writable

Verification:
- Static checks: command outputs show expected key absence/presence and symlink target.
- Tests: not applicable.
- Harness/smoke: not applicable.
- Manual review: confirm row IDs match known affected rows or stop.

Completion Evidence:
- Env key presence report redacted.
- `ls -ld` or equivalent symlink/root report.
- DB affected row list.
- Runtime drift file inventory.

Review Gate:
- Reviewer: Codex
- Required checks: no unexpected active DB rows.
- Failure handling: stop and report new row count/path drift.

Completion Judgment:
- PASS criteria: all affected targets are known and match this document.
- FAIL criteria: new unknown root, missing SSD, or unexpected DB references.

Commit Gate:
- Stage scope: none
- Commit message: none
- Commit only after: final phase

Next Phase Entry Criteria:
- Official root exists and affected DB rows are locked.

Rollback/Compensation:
- No state change.

### Phase 2. Runtime Config Correction
Status: PLANNED

Purpose:
Make parser runtime resolve fine notice storage to the official project/SSD root.

Work:
1. Add `FINE_NOTICE_STORAGE_ROOT=/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/storage/fine-notices` to `reservation_ai_parser/.env`, or use the equivalent verified absolute SSD path if project symlink resolution proves safer.
2. Keep secret values unchanged.
3. Do not change unrelated env keys.

Reason:
The code already supports `FINE_NOTICE_STORAGE_ROOT`; the failure is runtime configuration drift, not a parser architecture problem.

Scope:
- In: one env key in `reservation_ai_parser/.env`.
- Out: code refactor, schema change, UI change, unrelated `.env` values.

Files/Targets:
- `reservation_ai_parser/.env`
- Read-only reference: `reservation_ai_parser/.env.example`

Scope Lock:
- Modification allowed: `reservation_ai_parser/.env` only, storage root key only
- Creation allowed: none
- Deletion allowed: none
- Read-only references: `.env.example`, parser-core config code
- Excluded targets: `fine_notice_ai_parser/.env` unless preflight proves that service is active for this flow
- Behaviors not to change: host, port, Supabase credentials, OpenAI keys, IMS config
- Outputs: corrected env key
- Scope drift criteria: existing env contains a conflicting documented root

Verification:
- Static checks: key exists after edit, value is not printed in full in logs.
- Tests: not applicable.
- Harness/smoke: performed after restart in Phase 5.
- Manual review: confirm only intended env line changed.

Completion Evidence:
- Redacted env-key check shows `FINE_NOTICE_STORAGE_ROOT=REDACTED`.

Review Gate:
- Reviewer: Codex
- Required checks: no secret leakage, no unrelated env changes.
- Failure handling: revert env line and stop.

Completion Judgment:
- PASS criteria: storage root key exists and points to official root.
- FAIL criteria: env key absent, typo, or unrelated env mutation.

Commit Gate:
- Stage scope: final only; include `.env` only if project policy permits committing this file. If `.env` is intentionally untracked/ignored, document runtime config change instead of staging it.
- Commit message: final phase decides.
- Commit only after: Phase 6 verifies.

Next Phase Entry Criteria:
- Corrected env key present.

Rollback/Compensation:
- Remove or restore only the added env line.

### Phase 3. Active File Migration
Status: PLANNED

Purpose:
Place active referenced file bytes under official storage while preserving relative paths.

Work:
1. For the 3 affected DB rows, derive relative paths after `fine-notices/`.
2. Copy these files from runtime drift root to official root:
   - `incoming/20260619/99430ad0-a42b-47b0-b64d-0e1ddc4ebbca.jpg`
   - `cases/5ec6b200-d553-443c-85f6-03ba1e99b738/contract/contract_original.pdf`
3. Verify size and SHA-256 before and after copy.
4. Leave extra orphan incoming files in place until they are audited.

Reason:
DB metadata should only be updated after bytes are safely available at the canonical location.

Scope:
- In: active referenced files for rows listed in this document.
- Out: deleting orphan files, mass migration of unknown files, image/PDF content edits.

Files/Targets:
- `reservation_ai_parser/storage/fine-notices/incoming/20260619/99430ad0-a42b-47b0-b64d-0e1ddc4ebbca.jpg`
- `reservation_ai_parser/storage/fine-notices/cases/5ec6b200-d553-443c-85f6-03ba1e99b738/contract/contract_original.pdf`
- `storage/fine-notices/incoming/20260619/99430ad0-a42b-47b0-b64d-0e1ddc4ebbca.jpg`
- `storage/fine-notices/cases/5ec6b200-d553-443c-85f6-03ba1e99b738/contract/contract_original.pdf`

Scope Lock:
- Modification allowed: create/copy only the target canonical files
- Creation allowed: missing parent directories under official root for listed relative paths
- Deletion allowed: none
- Read-only references: runtime drift source files
- Excluded targets: unreferenced incoming images, unrelated cases
- Behaviors not to change: file contents
- Outputs: canonical copies with matching hash/size
- Scope drift criteria: source file missing or destination has different existing content

Verification:
- Static checks: source and destination paths exist.
- Tests: not applicable.
- Harness/smoke: PDF file opens/identifies as PDF; image file identifies as JPEG.
- Manual review: hash/size comparison.

Completion Evidence:
- SHA-256 and size match for each copied file.

Review Gate:
- Reviewer: Codex
- Required checks: no overwrite with mismatched content.
- Failure handling: do not update DB; report exact file conflict.

Completion Judgment:
- PASS criteria: all active referenced files exist under official root with matching bytes.
- FAIL criteria: missing source, mismatched hash, or unsafe overwrite.

Commit Gate:
- Stage scope: runtime file bytes are not expected in git.
- Commit message: final phase decides.
- Commit only after: Phase 6 verifies.

Next Phase Entry Criteria:
- Canonical file bytes verified.

Rollback/Compensation:
- If DB was not patched yet, simply leave copied files as harmless duplicates; no deletion during failure handling.

### Phase 4. DB Metadata Correction and Stale Cleanup
Status: PLANNED

Purpose:
Point active file metadata rows to canonical storage paths and remove abnormal stale metadata that remains outside active canonical records.

Work:
1. Patch only these known row IDs:
   - `1d87e153-5e94-4231-a812-c755651da894`
   - `d203aa44-84d4-4ba5-935a-2b9eba351e10`
   - `5e2583fc-d519-466b-adae-eb4381edb909`
2. Replace old prefix:
   - `/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/reservation_ai_parser/storage/fine-notices`
3. With canonical project path:
   - `/Users/otang_server/.openclaw/workspace-rentcar00_ops_developer/projects/rentcar00_OPS/storage/fine-notices`
4. Re-query rows after patch.
5. Delete abnormal metadata only when all of the following are true:
   - the row still points to `reservation_ai_parser/storage/fine-notices` or a missing/non-canonical local path,
   - the row is not one of the active required rows listed in this PM,
   - the row is not the only metadata record for an approved active fine notice/file role,
   - the file bytes have either been copied to canonical storage or the row is proven orphaned.

Reason:
Application/backend file resolution should follow documented canonical storage, not service working-directory fallback, and stale drift metadata must not remain as a second source of truth.

Scope:
- In: `local_path` field for the 3 listed file rows; deletion of stale abnormal metadata only when it passes the explicit cleanup criteria above.
- Out: active required metadata deletion, fine notice status changes, schema changes, renter/customer data.

Files/Targets:
- Supabase table `rc00_ops_fine_notice_files`

Scope Lock:
- Modification allowed: `local_path` only for listed IDs; delete only stale abnormal rows that are not active required records
- Creation allowed: none
- Deletion allowed: stale abnormal `rc00_ops_fine_notice_files` rows only after canonical replacement/active-row safety check
- Read-only references: `rc00_ops_fine_notices` row IDs for sanity
- Excluded targets: all other tables/columns
- Behaviors not to change: file roles, sha256, size, mime type, source metadata
- Outputs: corrected metadata rows and zero stale abnormal metadata rows for the active correction scope
- Scope drift criteria: row has changed role/path since preflight

Verification:
- Static checks: re-query rows and confirm canonical prefix; query old drift prefix and missing/non-canonical metadata after cleanup.
- Tests: not applicable.
- Harness/smoke: later route access/generation reads corrected files.
- Manual review: row IDs and file roles match plan.

Completion Evidence:
- Re-query output with canonical paths and no old prefix for active rows.
- Deletion count for stale abnormal metadata, or explicit `0 deleted` if no safe stale rows exist.

Review Gate:
- Reviewer: Codex
- Required checks: exact row ID match.
- Failure handling: patch old path back from preflight record if verification fails.

Completion Judgment:
- PASS criteria: all 3 rows point to canonical existing files and no safe-to-delete stale abnormal metadata remains in the correction scope.
- FAIL criteria: any active row points to missing/old path, or an abnormal row cannot be classified safely.

Commit Gate:
- Stage scope: DB change is external; document in final report.
- Commit message: final phase decides.
- Commit only after: Phase 6 verifies.

Next Phase Entry Criteria:
- DB metadata points to canonical files.

Rollback/Compensation:
- Patch affected `local_path` values back to preflight old paths if needed.

### Phase 5. Parser Restart and Storage Smoke
Status: PLANNED

Purpose:
Load corrected env into the parser service and prove new operations use official storage.

Work:
1. Run `npm --prefix reservation_ai_parser run check`.
2. Restart launchd service `ai.otang.reservation-ai-parser`.
3. Verify PID/listening port.
4. Smoke:
   - `GET /health`
   - invalid `POST /parse-fine-notice` returns structured JSON failure, not HTML/crash
   - `POST /fine-notices/save-contract-pdf` with missing row returns JSON 404
5. If a safe parse smoke is run, confirm newly saved incoming path uses official root.

Reason:
Env changes do not affect a running launchd process until restart.

Scope:
- In: parser service restart and public route smoke.
- Out: app restart, deploy, Supabase schema, mass ingestion.

Files/Targets:
- launchd service `ai.otang.reservation-ai-parser`
- `reservation_ai_parser/src/server.js`
- public parser base URL
- official storage root

Scope Lock:
- Modification allowed: none beyond service process state
- Creation allowed: only smoke-generated fine notice input file if parse smoke is run
- Deletion allowed: none
- Read-only references: service logs if needed
- Excluded targets: Flutter app, production deploys, DB schema
- Behaviors not to change: API contracts except generator route already approved in parent PM
- Outputs: restarted service and smoke evidence
- Scope drift criteria: service label differs, port differs unexpectedly, or smoke creates files outside official root

Verification:
- Static checks: `npm check`.
- Tests: parser check command.
- Harness/smoke: health and route smoke.
- Manual review: new file path root if generated.

Completion Evidence:
- Check pass.
- Health pass.
- JSON smoke responses.
- Storage root evidence.

Review Gate:
- Reviewer: Codex
- Required checks: service healthy and public routes reachable.
- Failure handling: inspect logs; if due env path, restore previous env and report.

Completion Judgment:
- PASS criteria: service runs with corrected storage root and smokes pass.
- FAIL criteria: service fails, routes fail, or storage root remains drifted.

Commit Gate:
- Stage scope: final only.
- Commit message: final phase decides.
- Commit only after: Phase 6 verifies.

Next Phase Entry Criteria:
- Parser healthy with canonical storage root.

Rollback/Compensation:
- Restore previous env, restart parser, report failure and preserve copied files.

### Phase 6. Resume Document Generation Smoke
Status: PLANNED

Purpose:
Resume the blocked document generation MVP using corrected canonical storage.

Work:
1. Re-run or continue `POST /fine-notices/generate-documents` for the approved active fine notice row(s).
2. Verify generated files are written under official storage:
   - `contract_with_stamps`
   - `renter_change_application`
   - `vehicle_application_list` if required by multi-row group policy
3. Verify file metadata rows point to canonical path.
4. Verify PDF opens/renders at least first page.
5. Record warnings if renter identity/address fields are missing rather than fabricating them.

Reason:
The generator should only be validated after storage root is correct, otherwise it would create more drift.

Scope:
- In: approved fine notice rows from current Gangnam toll test:
  - `5ec6b200-d553-443c-85f6-03ba1e99b738`
  - `01747ecf-d9f7-4764-bc75-239532b4f639`
- Out: app UI integration, additional notice intake, unrelated fine notices.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- official `storage/fine-notices/cases/...`
- `rc00_ops_fine_notice_files`
- `rc00_ops_fine_notices`

Scope Lock:
- Modification allowed: generated files and file metadata for approved rows only
- Creation allowed: generated document files under approved case folders
- Deletion allowed: replace same file role for same fine notice only if generator route intentionally supersedes old generated output
- Read-only references: contract original PDF, notice original image, renter snapshot/IMS candidate data
- Excluded targets: unrelated rows, app UI, schema migrations
- Behaviors not to change: contract search status, confirmed contract source, notice parsed fields
- Outputs: generated PDFs and metadata
- Scope drift criteria: generator needs fields not available from approved data and cannot produce safe warnings

Verification:
- Static checks: `npm --prefix reservation_ai_parser run check`.
- Tests: existing parser check.
- Harness/smoke: generator endpoint response, DB metadata query, PDF identify/render.
- Manual review: no raw sensitive data in logs/docs.

Completion Evidence:
- Generated role list and canonical paths.
- PDF open/render evidence.
- Warning list for missing renter fields, if any.

Review Gate:
- Reviewer: Codex
- Required checks: no generated file outside official root.
- Failure handling: stop before app UI work; document missing data or route bug.

Completion Judgment:
- PASS criteria: generated documents and metadata are canonical and readable.
- FAIL criteria: missing files, wrong paths, unreadable PDFs, or unsafe sensitive-data handling.

Commit Gate:
- Stage scope: code/docs/package changes approved by parent PM and this micro PM.
- Commit message: final phase decides.
- Commit only after: final review.

Next Phase Entry Criteria:
- Document generation smoke passes and no storage drift remains for active rows.

Rollback/Compensation:
- Remove or supersede generated metadata rows only for generated roles if they are wrong; preserve originals and contract originals.

### Final Phase. Completion Judgment / Documentation Cleanup / Commit
Status: PLANNED

Purpose:
Close the micro PM cleanly and make the parent document generation work safe to continue.

Work:
- Review all phase outputs:
  - Env storage root.
  - File copy/hash evidence.
  - DB metadata path evidence.
  - Parser restart/smoke.
  - Generator smoke output.
- Make completion judgment:
  - PASS only if active rows no longer depend on runtime drift storage and generator uses canonical root.
- Update or archive completion documents:
  - Update `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md` path evidence.
  - Update this PM status and archive to `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_storage_root_correction_micro_pm.md` when complete.
- Commit:
  - Commit only scoped code/package/docs changes and allowed config tracking.

Reason:
The storage root fix is a prerequisite correction, not an open-ended cleanup.

Scope Lock:
- Modification allowed:
  - this PM document
  - affected parent PM evidence section
  - scoped parser/generator files already in approved parent PM if needed
  - package files required for generator dependencies
- Creation allowed:
  - completed PM archive
- Deletion allowed:
  - none, except moving this PM from `docs/PHASE` to `docs/COMPLETED` after completion if project doc rules require it
- Read-only references:
  - git status/diff
  - DB/file verification evidence
- Excluded targets:
  - unrelated dirty app UI files
  - unrelated docs
  - unrelated storage orphan deletion
  - deploy
- Behaviors not to change:
  - no new feature scope beyond storage correction and blocked generator smoke
- Outputs:
  - completion report
  - archived PM document
  - optional commit hash
- Scope drift criteria:
  - commit would include unrelated dirty files or undocumented runtime/DB changes

Verification:
- Review evidence: phase evidence complete.
- Test/build/harness evidence:
  - `npm --prefix reservation_ai_parser run check`
  - parser public smoke
  - generator route smoke
  - DB metadata query
  - PDF identify/render
- Documentation evidence:
  - parent PM no longer records drift path as accepted final evidence.
- Git status evidence:
  - scoped changes identified before commit.

Completion Judgment:
- PASS criteria:
  - Canonical root is used by runtime, DB metadata, and generated outputs.
  - No active referenced file row remains under `reservation_ai_parser/storage/fine-notices`.
  - Parent document generation can proceed.
- FAIL criteria:
  - Any active referenced file row or new generated output still uses runtime drift root.
  - Parser cannot restart cleanly.
  - Generated PDFs are unreadable or path-unsafe.

Commit Gate:
- Stage scope:
  - this PM/completion archive
  - parent PM evidence update
  - approved parser/package changes when included in parent execution scope
- Commit message:
  - `fix: align fine notice storage root`
- Commit only after:
  - all phases pass and unrelated dirty files are excluded.

Rollback/Compensation:
- Revert env line.
- Patch DB rows back to preflight paths only if canonical files/routes fail.
- Preserve copied files and report for manual cleanup; do not delete originals automatically.

## 8. Approval Semantics
- `pa` meaning:
  - Approves this current micro PM as documented. Execute phases in order without asking for each phase again.
- `pa all` meaning:
  - Approves every phase in this micro PM, including env edit, file copy, DB metadata path update, parser restart, smoke checks, generator smoke resume, docs update, and scoped commit.
  - Do not pause between phases for internal approvals.
- Still stop immediately when:
  - a stop condition is hit,
  - work leaves documented scope,
  - a protected target appears that is not listed here,
  - a destructive action such as deleting orphan files becomes necessary.

## 9. Residual Risks
- Additional orphan incoming images may remain under `reservation_ai_parser/storage/fine-notices`; this PM preserves them and defers deletion to a separate audited cleanup.
- If another process uses `fine_notice_ai_parser`, it may need the same env key later; this PM only changes it if preflight proves it participates in the current flow.
- Existing dirty files from prior approved work must be kept separate during commit.
- Generated documents may still expose missing renter identity/address as warnings; this PM must not invent those fields.

## Final Completion Report
- Completed phases:
  - Phase 1 Preflight and Target Lock: VERIFIED
  - Phase 2 Runtime Config Correction: VERIFIED
  - Phase 3 Active File Migration: VERIFIED
  - Phase 4 DB Metadata Correction and Stale Cleanup: VERIFIED
  - Phase 5 Parser Restart and Storage Smoke: VERIFIED
  - Phase 6 Resume Document Generation Smoke: VERIFIED
  - Final Phase Completion Judgment / Documentation Cleanup / Commit: REVIEWED
- Commits:
  - Pending final scoped git decision because the working tree contains unrelated dirty files from prior work. Do not stage unrelated files.
- Verification summary:
  - `reservation_ai_parser/.env` now has `FINE_NOTICE_STORAGE_ROOT`.
  - `npm --prefix reservation_ai_parser run check`: PASS.
  - Official root `storage/fine-notices` exists and is writable through the project symlink to Mac mini SSD.
  - Active image and contract PDF were copied to canonical storage with matching SHA-256 and size.
  - The 3 active `rc00_ops_fine_notice_files.local_path` rows were patched to canonical paths and each file exists.
  - Old drift metadata query for `reservation_ai_parser/storage`: `0` rows.
  - Stale abnormal metadata deleted: `0` rows because no safe stale rows remained after path correction.
  - Parser restart succeeded; `/health`, invalid parse JSON failure, missing-row contract PDF JSON 404, and actual image parse storage smoke passed.
  - Generated `contract_with_stamps`, `renter_change_application`, and `vehicle_application_list` under canonical storage.
  - Generated PDF page checks passed: 2 pages, 1 page, 1 page.
- Residual risks:
  - Orphan incoming image files remain under `reservation_ai_parser/storage/fine-notices/incoming/20260619`; they were not deleted because this PM only deletes safe abnormal metadata, not unaudited file bytes.
  - The second toll row shares the same notice image and is represented in the generated vehicle application list, but its own row status remains `contract_confirmed` unless a later phase chooses to mark group-level document readiness.
  - `.env` is runtime config and may be ignored by git; final commit may not contain that local env change.
- Follow-up work:
  - Continue app file access/share MVP after confirming group-level document readiness policy for the second toll row.
