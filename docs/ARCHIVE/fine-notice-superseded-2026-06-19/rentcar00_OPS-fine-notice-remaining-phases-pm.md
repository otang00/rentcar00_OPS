# rentcar00_OPS Fine Notice Remaining Phases PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료/주정차/통행료 임차인 변경 후속 자동화
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_intake_policy_and_rollback_pm.md`
- Current status: Archived / Superseded by integrated and next operational PM docs
- Approval scope: 문서 작성과 phase 재분리만 승인됨. 문서 생성 코드, 다운로드 API, 제출 adapter, parser/runtime 변경, DB migration, APK build/upload, commit은 별도 승인 필요.
- Archive target: 완료·검증·커밋 후 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_remaining_phases_pm.md`

## 0. Goal Lock
- Objective: 과태료 MVP foundation 이후 남은 서류 양식 잠금, 문서 패키지 생성, 모바일 다운로드/공유, 제출 정책, 제출 adapter, release readiness를 독립 phase로 실행한다.
- Final success condition: 과태료 원장 1건에서 계약자 확정 후 계약서/신청서/신청차량리스트/합본/제출증빙이 원장별 폴더와 DB metadata로 추적되고, 고지서 profile별 정책에 맞는 제출 흐름으로 진행된다.
- Explicit non-goals:
  - 이미 완료된 MVP foundation phase 재구현
  - 상단 메뉴/API 연결 b51 hotfix
  - 정책표 없이 제출 채널 임의 판단
  - 승인 없는 live 외부 제출
  - Supabase Storage를 공식 보관소로 전환
- Protected targets:
  - Mac mini SSD `storage/fine-notices`
  - 계약서/신청서/제출증빙 원본
  - IMS live 계약서 API
  - fax, 문서24, 기관 사이트 계정/session/credential
  - GDrive APK 폴더
- Approval required for:
  - 문서 template/양식 확정
  - generated document write
  - parser/download endpoint 구현 및 restart
  - external submission adapter 구현
  - live submission
  - APK build/upload
  - commit/push

## 1. Current State Evidence
- Repo status:
  - branch: `fix/ops-return-complete-end-at`
  - HEAD: `05efdba docs: record b50 APK release`
  - app version/build: `1.0.0+51`
  - b51 APK uploaded to GDrive and includes current fine notice MVP work.
- Existing implementation:
  - 과태료 원장 tables: `rc00_ops_fine_notices`, `rc00_ops_fine_notice_files`
  - app feature: `lib/features/fines/`
  - photo parser service code: `fine_notice_ai_parser/`
  - contract matching: IMS normal/insurance candidates through parser domain
  - contract PDF save endpoint/code exists in `reservation_ai_parser/src/server.js`
  - official storage root: project `storage/fine-notices`, actual Mac mini SSD path via symlink/policy
- Existing docs/specs:
  - MVP foundation PM closed in `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
  - b51 UI/parser hotfix PM completed in `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
- Existing tests/harness:
  - `flutter analyze`
  - `flutter test`
  - `npm --prefix reservation_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run check`
  - `git diff --check`
- Known conflicts or drift:
  - b51/b52 hotfix is handled, but actual device photo parsing still needs operational review.
  - intake policy/rollback PM Phase 1-3 is complete; multi-row split/batch model remains as the next gate before document package/submission implementation.
  - contract PDF save code is implemented, but actual confirmed fine notice runtime save still needs one live check.
  - profile별 제출 채널/필요서류 정책 is not locked.
  - generated document template assets are not locked.
  - Non-owned vehicles are guarded by `rc00_ops_cars.car_number`; multi-row notices are not safe to process until split/batch Phase 4+ closes.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Planning scope | MVP and future phases mixed in one large roadmap | MVP foundation closed; remaining phases split here | Reduce scope confusion |
| Template policy | 신청서/차량리스트 fields unresolved | Phase 1 locks fields/templates | Document generation needs fixed inputs |
| File package | Storage root partially locked | Phase 2 locks generated package behavior | Avoid file sprawl |
| Mobile share | HTTPS route concept only | Phase 3 implements guarded download/share | Phone needs temporary copy, not archive |
| Submission | 제출채널 unknown | Phase 4 locks policy matrix | Prevent arbitrary channel choice |
| Adapter | No submit implementation | Phase 5 implements only locked profiles | Avoid live submission mistakes |
| Release | b51 uploaded but hotfix pending | Phase 6 only after hotfix/remaining checks | Prevent broken release flow |
| Intake policy | Single-case flow and multi-row/non-owned cases mixed | Intake policy/rollback PM precedes this document | Avoid generating documents for wrong vehicle/row |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Templates | docs/template assets, future generation code | Requires 사장님 policy input | Wrong form fields | Lock template before code |
| File storage | `storage/fine-notices`, `rc00_ops_fine_notice_files` | Medium | Missing/overwritten files | version/status policy |
| Download/share | `reservation_ai_parser`, Flutter app | Medium | path exposure | DB metadata lookup and path guard |
| Submission | external adapters | High | duplicate/wrong submission | policy matrix and duplicate guard |
| Release | APK/GDrive | Medium | shipping unresolved parser UI issue | require hotfix PM completion first |

## 4. Execution Policy
- Approval model: `pa` approves only the first planned phase in this document. `pa 1-3` or `pa all` approves documented phases only, but live submission and APK upload still require explicit protected-action approval.
- Phase transition rule: Phase 4 policy matrix must pass before Phase 5 adapter work. Phase 6 release waits for b51 hotfix PM and this document's approved checks.
- Review rule: 사장님 reviews all policy/template/submission decisions.
- Commit rule: per-phase commit gate; do not stage unrelated dirty files.
- Rollback/compensation rule: code revert for app/parser changes; generated files remain unless explicit cleanup approved; live submissions cannot be undone and require compensation procedure.
- Stop conditions:
  - intake policy/rollback PM is not accepted
  - non-owned vehicle guard is not defined
  - multi-row split/batch model is not defined
  - 제출 profile policy is unknown
  - required document template cannot be verified
  - file path guard cannot be proven
  - live submission would run without duplicate guard

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. Renter Change Template Lock | Lock application/list fields and formats | Codex + 사장님 | docs/template assets | No | Required |
| 2. Document Package Generation | Generate/attach contract, application, vehicle list, bundle metadata | Codex | code/files/DB metadata | No | Required |
| 3. Mobile Download and Share | Download/share generated docs from phone | Codex | code/parser endpoint | No | Required |
| 4. Submission Policy Matrix Lock | Lock profile별 channel/doc rules | Codex + 사장님 | docs/policy | Yes after Phase 1 | Required |
| 5. Submission Adapter Implementation | Implement only locked profile channels | Codex | code/external writes possible | No | Required |
| 6. Release Readiness | Verify and optionally build/upload | Codex | docs/build optional | No | Required if release |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Template inventory | Submission policy draft | Inspect known fine notice profiles and draft required template field matrix. No code edits. | sample notices, PM docs | field matrix | 사장님 review |
| Submission policy draft | Template inventory | Draft channel matrix with unknowns clearly marked. Do not implement adapters. | 사장님 policy input | profile/channel matrix | 사장님 locks rows |
| Download security review | Template policy | Review proposed download endpoint path guard. No runtime changes. | parser/server docs | security checklist | primary approval |

## 7. Phases

### Phase 1. Renter Change Template Lock
Status: PLANNED

Purpose:
Lock profile별 임차인 변경 신청서와 신청차량리스트 양식, 자동채움/수동입력 필드, output format.

Scope:
- In:
  - 신청서 field map
  - 신청차량리스트 columns
  - profile별 공통/개별 template 여부
  - PDF/XLSX/JPG output 기준
- Out:
  - generation code
  - external submission
  - electronic stamp auto-composition

Files/Targets:
- New or updated policy doc under `docs/PHASE/`
- optional template asset placeholders if approved

Execution Steps:
1. List known notice profiles.
2. Define application/list fields.
3. Separate auto-filled fields from manual fields.
4. Mark unknown profile/template rows as blocked.

Verification:
- Static checks: `git diff --check`
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 confirms field/template matrix

Completion Evidence:
- Code/doc evidence: template policy doc
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: fields, formats, unknowns marked
- Failure handling: hold affected profile

Completion Judgment:
- PASS criteria: implementation can generate docs without guessing fields.
- FAIL criteria: required fields/template formats remain ambiguous.

Commit Gate:
- Stage scope: approved docs/template placeholders
- Commit message: `docs: lock fine notice renter change templates`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Template policy accepted.

Rollback/Compensation:
Document revert.

### Phase 2. Document Package Generation
Status: PLANNED

Purpose:
Generate and attach the submission document package for a fine notice case.

Scope:
- In:
  - contract file role checks
  - `contract_with_stamps` manual attachment path
  - `renter_change_application.pdf`
  - `vehicle_application_list.xlsx/pdf`
  - optional `submission_bundle.pdf`
  - `manifest.json`
  - DB file metadata
- Out:
  - external submission
  - Supabase Storage
  - uncontrolled overwrite of finalized/submitted files

Files/Targets:
- `lib/features/fines/*`
- `reservation_ai_parser` only if server-side generation is selected
- `storage/fine-notices/cases/{fine_notice_id}/...`
- `rc00_ops_fine_notice_files`

Execution Steps:
1. Choose client/server generation boundary.
2. Implement document package status view.
3. Generate or attach approved documents.
4. Write files under case folder and metadata rows.
5. Refuse overwrite of finalized/submitted files.

Verification:
- Static checks: `flutter analyze`, parser checks if touched, `git diff --check`
- Tests: file role/status mapping tests
- Harness/smoke: create package for test case folder
- Manual review: 사장님 opens generated docs

Completion Evidence:
- Code/doc evidence: generator and metadata logic
- Test evidence: static/tests
- Runtime/DB/external evidence, if applicable: local case folder manifest

Review Gate:
- Reviewer: 사장님
- Required checks: generated docs open and match fields
- Failure handling: mark package `documents_needed`

Completion Judgment:
- PASS criteria: required docs are generated/attached and metadata tracked.
- FAIL criteria: files are detached from fine_notice_id or overwritten unsafely.

Commit Gate:
- Stage scope: approved generation/app/parser/test/docs files
- Commit message: `feat: generate fine notice document packages`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Package generation verified.

Rollback/Compensation:
Code revert. Generated local files/DB metadata cleanup only with explicit approval.

### Phase 3. Mobile Download and Share
Status: PLANNED

Purpose:
Allow phone app to download/share generated package files through guarded HTTPS.

Scope:
- In:
  - `GET /fine-notices/{fine_notice_id}/files/{file_role}/download`
  - DB metadata lookup
  - path guard under official storage root
  - Flutter download/share buttons
- Out:
  - permanent public URLs
  - Supabase Storage
  - phone gallery as official archive

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/*`
- `pubspec.yaml` if share/open dependency needed

Execution Steps:
1. Add guarded download endpoint.
2. Stream only DB-registered paths.
3. Add app file list download/share UI.
4. Verify phone temporary download and OS share sheet.

Verification:
- Static checks: `npm --prefix reservation_ai_parser run check`, `flutter analyze`, `git diff --check`
- Tests: path traversal deny, missing file, role mapping
- Harness/smoke: public HTTPS download for fixture file
- Manual review: phone download/share confirmation

Completion Evidence:
- Code/doc evidence: endpoint and UI
- Test evidence: static/tests/smoke
- Runtime/DB/external evidence, if applicable: public download smoke

Review Gate:
- Reviewer: 사장님
- Required checks: no arbitrary path, file opens on phone
- Failure handling: disable endpoint

Completion Judgment:
- PASS criteria: registered file roles can be shared; arbitrary paths cannot.
- FAIL criteria: endpoint exposes raw paths or permanent public URLs.

Commit Gate:
- Stage scope: endpoint/app/tests/docs
- Commit message: `feat: share fine notice documents`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Mobile share path verified.

Rollback/Compensation:
Revert endpoint/app code; restart previous service if needed.

### Phase 4. Submission Policy Matrix Lock
Status: PLANNED

Purpose:
Lock profile별 제출 채널, 필요서류, 제출양식, 제출대상.

Scope:
- In:
  - fax/document24/login site/file upload channel matrix
  - required docs per profile
  - submission target and contact/URL
  - receipt evidence requirement
- Out:
  - adapter implementation
  - live submission
  - credential changes

Files/Targets:
- new/update submission policy doc under `docs/PHASE/`

Execution Steps:
1. Create policy matrix with known/unknown rows.
2. Fill rows from 사장님 instructions.
3. Define missing document checks.
4. Define receipt/evidence rules.

Verification:
- Static checks: `git diff --check`
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 locks matrix

Completion Evidence:
- Code/doc evidence: submission policy matrix
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: each profile has channel/docs/target or explicit unknown
- Failure handling: unknown profiles stay blocked

Completion Judgment:
- PASS criteria: adapter can route without guessing.
- FAIL criteria: profile channel is inferred without policy.

Commit Gate:
- Stage scope: policy docs
- Commit message: `docs: lock fine notice submission matrix`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
At least one profile row locked for implementation.

Rollback/Compensation:
Document revert.

### Phase 5. Submission Adapter Implementation
Status: PLANNED

Purpose:
Implement submission flow only for locked profiles.

Scope:
- In:
  - pre-submit checklist
  - missing document guard
  - duplicate submission guard
  - manual-ready/dry-run first
  - live submit only with explicit sample approval
- Out:
  - unknown profile submission
  - credential/session changes without approval

Files/Targets:
- `lib/features/fines/*`
- submission adapter modules
- external channel integrations only if approved

Execution Steps:
1. Implement submission state machine.
2. Add missing/duplicate guards.
3. Implement manual-ready/dry-run.
4. Add locked channel adapter.
5. Record receipt/evidence.

Verification:
- Static checks: `flutter analyze`, `git diff --check`
- Tests: state machine, duplicate guard, missing docs
- Harness/smoke: dry-run/manual-ready profile
- Manual review: 사장님 approves live sample if needed

Completion Evidence:
- Code/doc evidence: adapter/guards/UI
- Test evidence: state tests
- Runtime/DB/external evidence, if applicable: approved sample only

Review Gate:
- Reviewer: 사장님
- Required checks: live submit approval and evidence
- Failure handling: set case `on_hold`, use manual fallback

Completion Judgment:
- PASS criteria: locked profiles submit or prepare safely with evidence.
- FAIL criteria: unknown/missing docs can submit.

Commit Gate:
- Stage scope: approved adapter/tests/docs
- Commit message: `feat: implement fine notice submission`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Submission flow verified for locked profile.

Rollback/Compensation:
Code revert. Live submissions require external correction process.

### Phase 6. Release Readiness
Status: PLANNED

Purpose:
Prepare verified functionality for operating APK/release.

Scope:
- In:
  - full checks
  - docs completion update
  - APK build/upload only if approved
  - b51 hotfix dependency check
- Out:
  - release with unresolved parser/menu issue
  - unapproved upload

Files/Targets:
- docs current/completed
- `pubspec.yaml` only if build approved
- GDrive only if upload approved

Execution Steps:
1. Verify b51 hotfix PM completion.
2. Run full checks.
3. Run end-to-end smoke from fine notice intake to submission-ready.
4. If approved, build/upload next APK.
5. Update completed/current docs.

Verification:
- Static checks: `flutter analyze`, parser checks, `git diff --check`
- Tests: `flutter test`
- Harness/smoke: fine notice E2E, public parser/download smoke
- Manual review: 사장님 실기기 확인

Completion Evidence:
- Code/doc evidence: release docs
- Test evidence: command results
- Runtime/DB/external evidence, if applicable: GDrive listing

Review Gate:
- Reviewer: 사장님
- Required checks: no known blocker remains
- Failure handling: release hold

Completion Judgment:
- PASS criteria: verified, documented, and release decision clear.
- FAIL criteria: APK uploaded with known blocking issue.

Commit Gate:
- Stage scope: approved release docs/build number only
- Commit message: `chore: prepare fine notice release`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
None.

Rollback/Compensation:
Supersede bad APK with next build; document status.

### Final Completion Report
- Completed phases: none in this continuation document
- Commits: none
- Verification summary: document split only
- Residual risks: template/submission policy still needs 사장님 input; b51 hotfix should precede release reliance
- Follow-up work: approve Phase 1 after b51 hotfix plan is handled
