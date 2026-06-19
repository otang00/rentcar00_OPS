# rentcar00_OPS b51 UI and Parser Hotfix PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: b51 실기기 확인 후 과태료 MVP 안정화
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
- Current status: Completed / commit pending
- Approval scope: Phase 1-4 실행, parser process restart, b52 APK build/upload 완료. commit/push는 별도 승인 전까지 미승인.
- Archive target: already moved to `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`

## 0. Goal Lock
- Objective: b51 APK에서 확인된 상단 업무 메뉴 폭 깨짐과 과태료 AI parser endpoint 미연결 문제를 최소 범위로 고친다.
- Final success condition: 모바일 상단 메뉴가 폭 360px 전후에서도 깨지지 않고, 과태료 AI파서 연결 확인/사진 파싱이 JSON 응답으로 동작한다.
- Explicit non-goals:
  - 과태료 문서 생성/제출 기능 구현
  - 신규 DB migration
  - 외부 제출/fax/문서24 연동
  - 기존 예약 파서 동작 변경
  - 무승인 APK 재배포
- Protected targets:
  - `.env*`, secret, token
  - Cloudflare tunnel/service routing
  - `reservation_ai_parser` 기존 예약/IMS endpoint
  - GDrive APK 폴더
- Approval required for:
  - Flutter UI 코드 수정
  - parser service route/config 수정
  - parser 프로세스 restart 또는 tunnel 변경
  - APK build/upload
  - commit/push

## 1. Current State Evidence
- Repo status:
  - branch: `fix/ops-return-complete-end-at`
  - HEAD: `05efdba docs: record b50 APK release`
  - current APK: `rentcar00_ops-app-release-arm64-b51-05efdba.apk`
  - dirty tree includes fine notice MVP and b51 document/build changes.
- Existing implementation:
  - Top layer selector is `SegmentedButton<OpsLayer>` in `lib/app/view/app_shell.dart`.
  - Current segment labels are `예약`, `현황판`, `과태료` with icons.
  - Fine parser app client calls `${AI_PARSER_BASE_URL}/health` and `${AI_PARSER_BASE_URL}/parse-fine-notice` in `lib/features/fines/data/fine_notice_ai_parser_client.dart`.
  - `AI_PARSER_BASE_URL` points to `https://parser.00rentcar.com`.
  - `https://parser.00rentcar.com/health` returns `{"ok":true,"service":"reservation_ai_parser"}`.
  - `https://parser.00rentcar.com/parse-fine-notice` returns `404 not_found`.
  - local `fine_notice_ai_parser` port `43120` is not listening.
- Existing docs/specs:
  - completed MVP foundation PM is archived in `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`.
  - fine notice follow-up phases are now consolidated in `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`.
- Existing tests/harness:
  - `flutter analyze`
  - `flutter test`
  - `npm --prefix reservation_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run check`
  - `curl https://parser.00rentcar.com/health`
- Known conflicts or drift:
  - b51 uploaded APK includes current MVP work but not this hotfix.
  - Published parser domain currently exposes reservation parser only.
  - Fine parser has separate service code but is not exposed through the public parser URL.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Top menu | Text-heavy segmented button overflows on phone | Compact icon-first layer switcher | Prevent broken labels on mobile |
| Fine parser routing | App calls `/parse-fine-notice` on reservation parser domain and gets 404 | Public parser route exposes fine parser endpoint or app targets correct fine parser base | AI parser must return JSON, not HTML/404 |
| Error handling | Non-JSON response can surface as `FormatException` | Client validates content/error body before JSON decode | User sees actionable connection error |
| Release | b51 uploaded with issue | b52 candidate only after verification | Avoid repeated broken APK |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| UI | `lib/app/view/app_shell.dart` | Small hotfix | Navigation regression | Keep same selected state/provider, only presentation changes |
| Parser client | `lib/features/fines/data/fine_notice_ai_parser_client.dart` | Small hotfix | Masking real parser errors | Preserve status/message and improve non-JSON guard |
| Parser runtime | `reservation_ai_parser` or `fine_notice_ai_parser` service/tunnel | Needs runtime approval | Existing reservation parser disruption | Prefer additive route/proxy; health smoke before/after |
| Release | APK b52 candidate | Needs approval | Dirty uncommitted build identity | Record exact build/file in docs |

## 4. Execution Policy
- Approval model: `pa` approves Phase 1 only unless a range is specified. Runtime restart/tunnel/API deploy and APK upload remain protected and require explicit approval inside the relevant phase.
- Phase transition rule: UI fix can proceed before runtime routing, but APK upload waits until both UI and parser smoke pass or 사장님 explicitly requests UI-only build.
- Review rule: 실기기 screenshot or narrow-width emulator check is required for the menu.
- Commit rule: commit only after user approval. Do not mix unrelated dirty files outside approved scope.
- Rollback/compensation rule: UI code revert; parser route/restart rollback to previous service; bad APK superseded by next build.
- Stop conditions:
  - parser route requires credential/tunnel changes not visible in repo
  - fine parser cannot be exposed without disrupting reservation parser
  - UI fix requires redesign outside top app shell

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. Mobile Top Menu Compact UI | Fix app shell overflow | Codex | code | No | Required |
| 2. Fine Parser Endpoint Wiring | Make `/parse-fine-notice` reachable or configure dedicated base URL | Codex | code/runtime config possible | No | Required |
| 3. Parser Client Error Guard | Prevent HTML/non-JSON FormatException | Codex | code | Yes with Phase 1 if no shared files | Required |
| 4. Smoke and Release Candidate | Verify and optionally build/upload b52 | Codex | build/upload optional | No | Required if release approved |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| UI narrow-width review | Parser route inspection | Inspect `app_shell.dart` only and propose compact mobile layer selector without changing state model. Do not edit files. | screenshot, `app_shell.dart` | UI recommendation | Primary agent applies |
| Parser route inspection | UI review | Inspect parser services and tunnel docs. Find lowest-risk route for fine parser endpoint. Do not change runtime. | `reservation_ai_parser`, `fine_notice_ai_parser`, docs | route recommendation | 사장님 approval for runtime |

## 7. Phases

### Phase 1. Mobile Top Menu Compact UI
Status: VERIFIED

Purpose:
Make the top 업무 layer switcher fit phone width without broken vertical Korean labels.

Scope:
- In:
  - `lib/app/view/app_shell.dart`
  - icon-first compact selector
  - same `selectedOpsLayerProvider`
  - tooltip/semantic label for `예약`, `일정`, `과태료`
- Out:
  - route/provider redesign
  - bottom navigation redesign
  - unrelated theme changes

Files/Targets:
- `lib/app/view/app_shell.dart`
- optional: `test/widget_test.dart`

Execution Steps:
1. Replace text-heavy segmented button with compact icon buttons or icon-only segmented control.
2. Keep selected color/background visible.
3. Ensure search/+ actions remain reachable.
4. Run narrow-width visual/smoke check.

Verification:
- Static checks: `dart format`, `flutter analyze`, `git diff --check`
- Tests: `flutter test`
- Harness/smoke: narrow phone screenshot or emulator/manual check
- Manual review: 사장님 screenshot confirmation

Completion Evidence:
- Code/doc evidence: app shell diff
- Test evidence: Flutter checks
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: no label break, selected layer obvious, search/+ visible
- Failure handling: adjust spacing/icon-only design

Completion Judgment:
- PASS criteria: 360px-class phone width does not break menu text.
- FAIL criteria: labels still wrap vertically or actions overlap.

Commit Gate:
- Stage scope: `app_shell.dart`, targeted tests/docs only
- Commit message: `fix: compact ops layer navigation`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Menu screenshot/check accepted.

Rollback/Compensation:
Revert `app_shell.dart` to previous segmented button.

### Phase 2. Fine Parser Endpoint Wiring
Status: VERIFIED

Purpose:
Make the fine notice parser endpoint reachable from the app without breaking reservation parser endpoints.

Scope:
- In:
  - expose `GET /health` and `POST /parse-fine-notice` for fine parser path
  - choose one route:
    - additive proxy in `reservation_ai_parser`, or
    - dedicated public base URL/env for `fine_notice_ai_parser`
  - smoke with real public URL
- Out:
  - OpenAI prompt/model retuning
  - DB migration
  - unrelated parser API changes

Files/Targets:
- `reservation_ai_parser/src/server.js` if proxy is chosen
- `fine_notice_ai_parser/src/server.js` if direct service is chosen
- runtime service/tunnel config, only if explicitly approved

Execution Steps:
1. Decide route strategy.
2. Add route or config without changing existing reservation endpoints.
3. Start/restart required parser service only after approval.
4. Verify public endpoint returns JSON.

Verification:
- Static checks: `npm --prefix reservation_ai_parser run check`, `npm --prefix fine_notice_ai_parser run check`
- Tests: parser smoke scripts if available
- Harness/smoke:
  - `curl https://parser.00rentcar.com/health`
  - `curl https://parser.00rentcar.com/parse-fine-notice` with invalid payload returns JSON error, not HTML
  - app AI parser connection indicator
- Manual review: 사장님 app parse attempt

Completion Evidence:
- Code/doc evidence: route/config diff
- Test evidence: npm checks
- Runtime/DB/external evidence, if applicable: public curl output

Review Gate:
- Reviewer: 사장님
- Required checks: reservation parser health remains ok, fine parser endpoint reaches JSON service
- Failure handling: disable new route/proxy and restore previous service

Completion Judgment:
- PASS criteria: app no longer gets 404/HTML for `/parse-fine-notice`.
- FAIL criteria: reservation parser breaks or fine parser remains unreachable.

Commit Gate:
- Stage scope: approved parser route/config files only
- Commit message: `fix: expose fine notice parser endpoint`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Public parser smoke passes.

Rollback/Compensation:
Revert route/config; restart previous parser service if changed.

### Phase 3. Parser Client Error Guard
Status: VERIFIED

Purpose:
Prevent raw `FormatException` when server returns HTML, 404, or other non-JSON content.

Scope:
- In:
  - `FineNoticeAiParserClient`
  - content-type/body-safe JSON parsing
  - actionable Korean error message
- Out:
  - parser model changes
  - UI redesign

Files/Targets:
- `lib/features/fines/data/fine_notice_ai_parser_client.dart`

Execution Steps:
1. Parse response body defensively.
2. If non-JSON, throw `FineNoticeAiParserException` with status and short message.
3. Keep successful JSON path unchanged.

Verification:
- Static checks: `dart format`, `flutter analyze`, `git diff --check`
- Tests: add small client parse/error test if practical
- Harness/smoke: force bad endpoint and confirm user-friendly snackbar
- Manual review: 사장님 confirms no raw `FormatException`

Completion Evidence:
- Code/doc evidence: client guard diff
- Test evidence: Flutter checks
- Runtime/DB/external evidence, if applicable: none

Review Gate:
- Reviewer: 사장님
- Required checks: error message is understandable
- Failure handling: simplify error handling without changing API contract

Completion Judgment:
- PASS criteria: non-JSON response does not surface as raw decoder exception.
- FAIL criteria: same `Unexpected character <html>` appears.

Commit Gate:
- Stage scope: parser client/test docs only
- Commit message: `fix: guard fine parser error responses`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Client error guard verified.

Rollback/Compensation:
Revert client file.

### Phase 4. Smoke and Release Candidate
Status: VERIFIED

Purpose:
Verify the hotfix and optionally produce the next APK.

Scope:
- In:
  - full static/test checks
  - public parser smoke
  - b52 APK build/upload only if explicitly approved
- Out:
  - unapproved release upload
  - unrelated feature additions

Files/Targets:
- `pubspec.yaml` only if build number is bumped
- `build/releases/*` if APK build approved
- GDrive `rentcar00_OPS/apk/` only if upload approved

Execution Steps:
1. Run checks.
2. Confirm UI screenshot/manual phone state.
3. Confirm parser public endpoint.
4. If approved, build b52 and upload to GDrive latest-only folder.
5. Update docs.

Verification:
- Static checks: `flutter analyze`, parser checks, `git diff --check`
- Tests: `flutter test`
- Harness/smoke: public parser curl, APK listing if uploaded
- Manual review: 사장님 installation check

Completion Evidence:
- Code/doc evidence: completed docs
- Test evidence: command results
- Runtime/DB/external evidence, if applicable: GDrive listing

Review Gate:
- Reviewer: 사장님
- Required checks: UI and parser both fixed before release
- Failure handling: skip APK upload and keep local candidate only

Completion Judgment:
- PASS criteria: hotfix verified and release decision documented.
- FAIL criteria: one issue remains but release is attempted.

Commit Gate:
- Stage scope: approved hotfix/release docs only
- Commit message: `fix: stabilize fine notice b51 hotfix`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Hotfix deployed or consciously held.

Rollback/Compensation:
If APK is bad, upload superseding build and document b51/b52 status.

### Final Completion Report
- Completed phases:
  - Phase 1 Mobile Top Menu Compact UI
  - Phase 2 Fine Parser Endpoint Wiring
  - Phase 3 Parser Client Error Guard
  - Phase 4 Smoke and Release Candidate
- Commits: none
- Verification summary:
  - `npm --prefix reservation_ai_parser run check` passed
  - `npm --prefix fine_notice_ai_parser run check` passed
  - `flutter analyze` passed
  - `flutter test` passed
  - `git diff --check` passed
  - local route smoke on `127.0.0.1:43111` passed
  - public `https://parser.00rentcar.com/health` passed
  - public `POST https://parser.00rentcar.com/parse-fine-notice` fixture smoke passed
  - invalid image payload now returns JSON error, not HTML
  - b52 APK build/upload passed
- Runtime/Release:
  - restarted local `reservation_ai_parser` process on `127.0.0.1:43110`
  - uploaded `rentcar00_ops-app-release-arm64-b52-05efdba.apk`
  - GDrive `rentcar00_OPS/apk/` now contains b52 only
- Residual risks:
  - 실기기에서 상단 메뉴 icon-first UI 최종 육안 확인 필요
  - 실제 고지서 사진 1장으로 OpenAI parse runtime 확인 필요
- Follow-up work:
  - 사장님 실기기 설치 후 과태료 탭, AI파서 연결, 사진 파싱 확인
