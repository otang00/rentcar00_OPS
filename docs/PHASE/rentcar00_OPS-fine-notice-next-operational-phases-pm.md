# rentcar00_OPS Fine Notice Next Operational Phases PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료/주정차/통행료 실전 MVP 운영 반영 및 문서생성 진입
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-mvp-handoff-20260619.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
- Current status: In Review
- Approval scope: This document creation only. Execution is not approved until 사장님 says `pa all` or a specific phase approval phrase. In this PM, `pa all` means approval to execute every listed phase, including DB apply, parser restart, runtime file write, code implementation, APK build/upload, commit, and push if the phase reaches that step. Stop only when a documented stop condition or newly discovered anomaly appears.
- Archive target: `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_next_operational_phases_pm.md`

## 0. Goal Lock
- Objective: 남은 과태료 MVP 작업을 운영 반영 전 게이트, 실제 PDF 저장 확인, 문서생성 정책 잠금, manual-ready 패키지 구현 순서로 재정렬한다.
- Final success condition:
  - b52 앱/공개 parser/DB status가 같은 정책을 사용한다.
  - `not_our_vehicle` 상태가 remote Supabase constraint와 앱 저장 정책에서 충돌하지 않는다.
  - 운영 parser가 현재 코드와 같은 endpoint 정책을 제공한다.
  - 실제 확정 계약 원장 1건으로 `contract_original.pdf` 저장이 검증된다.
  - 계약자 구조화 schema, 민감정보 저장/표시 정책, 도장 asset 위치, 신청/통보 문서 template이 잠긴 뒤에만 문서 생성 구현으로 넘어간다.
  - 모든 단계에서 이상한 점, 문서/코드 불일치, 운영 영향 확대, 민감정보 노출 가능성이 보이면 즉시 중단하고 사장님에게 물어본다.
- Explicit non-goals:
  - 정책 없는 전체 자동 제출
  - 문서24/fax/email/기관 사이트 live submission
  - 과태료 계약검색을 `/ims/search-reservations`에 다시 섞는 변경
  - PDF 저장용 별도 내부 비밀번호/토큰 가드 재도입
  - 회사 인감/원본대조필 이미지 원본을 git에 추가
  - 계약자 주민번호/면허번호/주소/전화번호 raw 값을 docs/log에 기록
  - 가격 정책 구현
  - unrelated dirty files 정리 또는 revert
- Protected targets:
  - Supabase production DB
  - `supabase/migrations/*`
  - parser runtime process, launchd/cloudflared/service routing
  - `reservation_ai_parser/.env*`
  - Mac mini SSD `storage/fine-notices`
  - IMS live APIs
  - 회사 인감/도장 이미지 파일
  - 계약자 민감정보
  - GDrive APK folder
  - commit/push/PR
- Approval required for:
  - DB migration remote apply
  - parser restart or deploy
  - runtime smoke that writes DB or files
  - code edits beyond PM/document planning
  - stamp/seal asset registration or copying
  - APK build/upload
  - external submission
  - commit/push

## 1. Current State Evidence
- Repo status:
  - Branch: `fix/ops-return-complete-end-at`
  - HEAD: `05efdba docs: record b50 APK release`
  - Working tree is dirty with fine notice MVP, parser, docs, version/build, and migration changes.
  - App version in working tree: `1.0.0+52`
  - New PM/doc/code files are untracked; do not assume they are committed.
- Existing implementation:
  - Fine notice tab, manual intake, AI parser client, repository, and UI exist under `lib/features/fines/`.
  - Public parser route code exists in `reservation_ai_parser/src/server.js` for:
    - `POST /parse-fine-notice`
    - `POST /ims/search-fine-notice-contracts`
    - `POST /fine-notices/save-contract-pdf`
  - App fine notice contract search client calls `/ims/search-fine-notice-contracts`.
  - App/repository write `not_our_vehicle` for non-owned/non-managed vehicles.
  - Pending migration file: `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql`.
  - Fine notice base migration defines file roles including `contract_original`, `contract_with_stamps`, `renter_change_application`, `vehicle_application_list`, `submission_bundle_pdf`, and `submission_receipt`.
- Existing docs/specs:
  - MVP foundation Phase 1-10 is completed.
  - Integrated intake Phase 1-3 is completed and later phase map is paused by real MVP mode.
  - Workflow integrity correction Phase 1-5 is locally verified, but remote DB apply, parser restart, APK build/upload, commit are not done.
  - Document generation PM says next step is contract original PDF runtime smoke.
  - Submission policy mapping is Draft/Research Baseline; profile policies are not yet LOCKED.
  - Police name-change template is a candidate and needs legal wording/current company info review.
- Existing tests/harness:
  - `flutter analyze`
  - `flutter test`
  - `flutter test test/fine_notice_models_test.dart`
  - `npm --prefix reservation_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run fixture-check`
  - `npm --prefix fine_notice_ai_parser run gangnam-multi-policy-check`
  - `npm --prefix fine_notice_ai_parser run gangnam-multi-smoke`
  - `npm --prefix fine_notice_ai_parser run file-save-smoke`
  - `git diff --check`
- Known conflicts or drift:
  - HEAD is b50, while docs and working tree record b52 changes.
  - b52 APK is documented as uploaded, but 실기기 confirmation is still needed.
  - `not_our_vehicle` is used by app code, but remote DB constraint may not yet allow it.
  - Parser code has been changed locally, but operating public parser may not be restarted on the current code.
  - Actual `contract_original.pdf` saving has not been verified against a real confirmed fine notice row.
  - Insurance-contract candidate hit coverage is weaker than normal-contract smoke.
  - Document-generation schema contains 민감정보 fields; storage/display policy is not locked.
  - Submission profiles remain `UNKNOWN` or `CANDIDATE`; automatic external submission must not start.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Next work plan | Several active PMs each pointed to next steps | Single operational gate PM orders the next phases | Avoid jumping into document generation before DB/runtime/PDF smoke are proven |
| Approval model | Draft initially blocked broad `pa all` and required phase-specific protected approvals | `pa all` now approves every listed phase and protected action in this PM | Match 사장님 execution rule; only anomaly stop can interrupt |
| Runtime readiness | Local implementation verified but not fully reflected in public runtime | Parser restart and public smoke are explicit phases | Prevent assuming local code is live |
| DB status policy | App uses `not_our_vehicle`; remote DB may reject it | Remote migration apply is an explicit protected phase | Remove known save-risk before field use |
| PDF save | Route exists and missing-row smoke passed locally | Real confirmed row runtime smoke is required before generator work | Avoid building stamped/application docs on unverified source PDF flow |
| Document generation | PM has proposed schema/templates | Schema, 민감정보 policy, stamp assets, and template lock precede implementation | Prevent leaking data or producing invalid submission docs |
| Stop behavior | Stop rules spread across PMs | Every phase includes anomaly stop checks | Existing 이상한점 발견 시 중단하고 질문하도록 enforce |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Flutter UI/client | `lib/features/fines/*`, `lib/app/view/app_shell.dart` | Medium | b52 device issue or client/runtime mismatch | device/public smoke before new implementation |
| Parser backend | `reservation_ai_parser/src/server.js`, `fine_notice_ai_parser/*` | High if restarted | Reservation parser regression or public route mismatch | health checks before/after, reservation endpoint smoke, rollback command prepared before restart |
| Supabase DB | `rc00_ops_fine_notices`, `rc00_ops_fine_notice_files`, migrations | High | Bad constraint or rejected fine notice saves | inspect migration, remote apply under `pa all` or phase approval, verify with constrained status check |
| File storage | Mac mini SSD `storage/fine-notices` | High during PDF smoke/generation | wrong file path, duplicate files, sensitive data exposure | one approved test row, no raw sensitive values in logs/docs, file role metadata check |
| IMS API | normal contract/insurance PDF endpoints | Medium | wrong contract PDF, PDF id mismatch, rate/live dependency | one confirmed row, source id check before save, stop on mismatch |
| Docs/specs | Current/PHASE/COMPLETED docs | Medium | stale PMs keep misleading future agents | update docs only after verified phases, archive completed PM later |
| Tests/harness | Flutter tests, node checks, parser smoke scripts | Medium | local tests pass but runtime fails | separate local checks from public/runtime smoke |
| External submission | document24/fax/email/site | Not in scope | accidental live submission | hard non-goal until profile policy is LOCKED |
| Commit/release | git staging, APK, GDrive | Medium | dirty unrelated files staged or bad APK uploaded | explicit stage scope and commit/build/upload gates |

## 4. Execution Policy
- Approval model:
  - `pa all`: approves execution of Phase 0 through Phase 10 in order, including DB migration remote apply, parser restart, runtime PDF/file writes, code edits, APK build/upload, docs update, commit, and push if each step reaches its phase gate. Do not ask for separate approval in the middle unless a stop condition or new anomaly appears.
  - `pa fine-notice-next-p0`: Phase 0 read-only baseline/anomaly audit only.
  - `pa fine-notice-next-p1`: Phase 1 b52 device/public runtime verification only. No restart.
  - `pa fine-notice-next-db-apply`: Phase 2 remote DB migration apply only.
  - `pa fine-notice-next-parser-restart`: Phase 3 parser restart and public smoke only.
  - `pa fine-notice-next-contract-pdf-smoke`: Phase 4 one-row `contract_original.pdf` runtime smoke only.
  - `pa fine-notice-next-doc-policy`: Phase 5 document schema/policy lock only.
  - `pa fine-notice-next-stamp-template`: Phase 6 stamp/template lock only.
  - `pa fine-notice-next-generator`: Phase 7 backend document generator implementation only, after Phase 4-6 pass.
  - `pa fine-notice-next-app-files`: Phase 8 app/API download/share UI only, after Phase 7 pass.
  - `pa fine-notice-next-release`: Phase 9 release candidate build/upload only.
  - `pa fine-notice-next-commit`: Phase 10 staging/commit only.
- Phase transition rule:
  - Phase 0 must run before any DB/runtime/file/code/release action, including under `pa all`.
  - Phase 2 and Phase 3 can be ordered after Phase 0, but Phase 4 requires both DB status compatibility and parser runtime alignment.
  - Phase 7 cannot start until Phase 4 proves `contract_original.pdf` and Phase 5-6 lock schema/assets/templates.
  - Phase 8 cannot start until generated files exist and path/auth policy is locked.
  - Phase 9 cannot start until all intended app/backend changes are verified.
  - Phase 10 cannot stage unrelated dirty files.
  - Under `pa all`, continue phase-by-phase without asking again when the previous phase passes.
- Review rule:
  - At the start of every phase, re-check relevant current files/docs because the working tree is dirty.
  - If code and PM docs disagree, trust verified code for diagnosis, stop before implementation, and ask 사장님 which policy wins.
  - Do not hide or smooth over 이상한점. Report exact conflict, impact, and choices.
- Commit rule:
- Commit is allowed when Phase 10 is reached under `pa all`, or when `pa fine-notice-next-commit` / direct commit approval is given.
  - Each commit must stage only files belonging to the verified scope.
- Protected files such as `.env*`, runtime service configs, and secret/stamp assets must not be staged unless they are explicitly listed in this PM phase scope or 사장님 separately names them.
- Rollback/compensation rule:
  - For DB migration, prepare reverse migration/constraint restore notes before apply.
  - For parser restart, record current process/health and rollback restart path before action.
  - For runtime PDF smoke, use one known row and record generated file path/metadata so manual cleanup can be requested if needed.
  - For code changes, revert only files touched by the approved phase; do not touch unrelated dirty changes.
- Stop conditions:
  - Any endpoint route points fine notice contract search back to `/ims/search-reservations`.
  - PDF save requires or reintroduces a separate internal password/token guard.
  - App status value is outside DB constraint.
  - Runtime parser version cannot be linked to current code.
  - A required `.env`, secret, service config, launchd/cloudflared setting, or protected asset must be changed but is not explicitly listed in this PM.
  - Actual test row identity/contract source is unclear.
  - Generated document would expose raw 주민번호/면허번호/주소/전화번호 in docs/logs.
  - Submission channel/profile is not `LOCKED` but implementation attempts live submission.
  - Verification fails for unknown reasons.
  - Existing unrelated dirty changes would need to be reverted or overwritten.

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 0. Baseline and Anomaly Audit | Reconfirm dirty tree, current PMs, endpoint/status/schema policy before action | Codex | read-only | No | No |
| 1. b52 Device and Public Runtime Verification | Confirm uploaded APK and public parser match expected user flow | Codex + 사장님 | read/public smoke only | Yes with policy research | No |
| 2. Remote DB Status Migration Apply | Apply `not_our_vehicle` status constraint to remote Supabase | Codex | DB write | No | No |
| 3. Parser Runtime Restart and Public Smoke | Restart parser runtime and verify public endpoints | Codex | runtime restart | No | No |
| 4. Contract Original PDF Runtime Smoke | Save `contract_original.pdf` for one confirmed fine notice row | Codex + 사장님 | DB/file write | No | No |
| 5. Document Data Policy and Schema Lock | Lock renter data columns, masking, batch fields, document number policy | Codex + 사장님 | docs/migration draft only | Yes after Phase 4 | Optional docs commit later |
| 6. Stamp Asset and Template Lock | Lock stamp/seal asset path, usage rules, template variables and layout | Codex + 사장님 | docs/policy, no asset copy unless approved | Yes after Phase 4 | Optional docs commit later |
| 7. Backend Document Generator MVP | Generate stamped contract and renter change application package | Codex | code/local files/DB metadata | No | Required after verify |
| 8. App File Access and Share MVP | Add app/manual-ready file status, download/share API and guarded UI | Codex | code/API | No | Required after verify |
| 9. Release Candidate Verification | Build and upload APK only after checks pass | Codex | build/upload | No | No or separate release commit |
| 10. Completion Docs and Commit | Update docs, stage exact files, commit approved scope | Codex | docs/git commit | No | Yes |

## 5.1 Phase-by-Phase Concrete Work and Risks
| Phase | What This Phase Actually Does | Concrete Files/Targets | Verification | Main Risks | Stop / Ask 사장님 When |
| --- | --- | --- | --- | --- | --- |
| 0. Baseline and Anomaly Audit | 현재 dirty tree, PM 문서, endpoint, DB status, parser route, test 위치를 다시 확인한다. 아무 것도 수정하지 않는다. | `git status`, `docs/GOAL/rentcar00_OPS-current.md`, `docs/PHASE/*fine-notice*`, `reservation_ai_parser/src/server.js`, `lib/features/fines/`, `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql` | `rg`/read-only 확인 결과 보고 | 문서에는 완료라고 되어 있는데 코드가 다르거나, 코드에는 새 status/endpoint가 있는데 migration/runtime이 못 따라온 상태일 수 있음 | 문서/코드/DB migration 중 하나라도 서로 다른 정책을 말하면 즉시 중단 |
| 1. b52 Device and Public Runtime Verification | b52 APK가 실제 폰에서 상단 메뉴와 과태료 parser를 제대로 보여주는지 확인한다. public parser가 JSON을 주는지도 본다. | 실기기 b52 APK, `https://parser.00rentcar.com/health`, `https://parser.00rentcar.com/parse-fine-notice` | 폰 확인, public curl/smoke | APK는 b52인데 public parser가 옛 코드일 수 있음. 앱 UI는 괜찮아도 parser 404/HTML이면 실사용 실패 | 메뉴 깨짐, raw `FormatException`, parser 404/HTML, APK 버전 불명확 |
| 2. Remote DB Status Migration Apply | remote Supabase의 `rc00_ops_fine_notices.status` constraint에 `not_our_vehicle`을 추가한다. | `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql`, remote Supabase `rc00_ops_fine_notices` | migration 적용 결과, constraint 확인, 필요 시 최소 status write 검증 | constraint를 잘못 재생성하면 기존 status 저장이 막힐 수 있음. 운영 DB 변경이라 되돌림도 migration 필요 | remote constraint가 로컬 migration과 다르거나, 기존 status 목록 누락 발견 |
| 3. Parser Runtime Restart and Public Smoke | 운영 parser를 현재 코드 기준으로 재시작하고 public endpoint를 확인한다. | parser runtime process, `reservation_ai_parser/src/server.js`, `https://parser.00rentcar.com` | `npm --prefix reservation_ai_parser run check`, public `/health`, `/parse-fine-notice`, `/ims/search-fine-notice-contracts`, `/fine-notices/save-contract-pdf` smoke | restart가 예약 parser까지 깨뜨릴 수 있음. Cloudflare/service 설정이 코드 밖에 있으면 예상보다 영향이 커짐 | restart 방법 불명확, service config 수정 필요, 기존 예약 parser regression |
| 4. Contract Original PDF Runtime Smoke | 확정 계약이 있는 실제 과태료 원장 1건으로 `contract_original.pdf` 저장을 확인한다. | `POST /fine-notices/save-contract-pdf`, selected fine notice row, IMS PDF endpoint, Mac mini SSD `storage/fine-notices`, `rc00_ops_fine_notice_files` | response JSON, file role/path, PDF open check | wrong contract PDF 저장, IMS id 혼동, 파일/DB write 실패, 민감정보 로그 노출 | 선택 row의 계약 source/id가 애매하거나 저장 PDF가 다른 계약서로 보이면 즉시 중단 |
| 5. Document Data Policy and Schema Lock | 계약자 정보, 민감정보, batch/document list, 문서번호 정책을 확정한다. 필요하면 additive migration draft를 만든다. | `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`, possible new `supabase/migrations/*`, later `FineNoticeCase` model | schema review, docs review, SQL additive-only 확인 | 주민번호/면허번호/주소 저장 정책이 불명확하면 법적/운영 리스크가 큼. 너무 큰 schema를 만들면 부채가 됨 | IMS/PDF에서 필수 정보 확보가 안 되거나 민감정보 표시 정책이 안 잠기면 구현 중단 |
| 6. Stamp Asset and Template Lock | 원본대조필/회사 인장 위치, 파일 보관 위치, 신청/통보서 변수와 도장 위치를 확정한다. | stamp/seal asset path outside git, `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`, document template policy | git status에 도장 원본 미포함 확인, template variable review | 도장 원본 git 유출, 회사정보/법령문구 오류, 도장 위치 불량 | 도장 파일 위치/권한 불명확, 회사 주소/전화/fax/email 최신값 불명확, 법령문구 확정 불가 |
| 7. Backend Document Generator MVP | `contract_original`을 기반으로 `contract_with_stamps`, `renter_change_application`, 필요 시 `vehicle_application_list`를 생성한다. | likely `reservation_ai_parser/src/server.js` or new module, `rc00_ops_fine_notice_files`, `storage/fine-notices`, tests/scripts | node check, generated PDF open/render, file role metadata, one approved runtime smoke | PDF 깨짐, 도장 위치 오류, wrong renter data, 민감정보 노출, file metadata mismatch | sample PDF 값/도장/첨부 역할 중 하나라도 틀리면 앱 UI로 넘어가지 않음 |
| 8. App File Access and Share MVP | 앱에서 생성 문서 상태를 보고 HTTPS 경로로 다운로드/공유할 수 있게 한다. path/role guard를 넣는다. | `lib/features/fines/`, backend file endpoint, `rc00_ops_fine_notice_files`, `storage/fine-notices` | `flutter analyze/test`, node check, valid/invalid file access smoke, phone share check | 파일 경로 노출, path traversal, 인증 약함, 다른 사건 파일 열람 | invalid path가 열리거나 role guard가 약하면 즉시 중단 |
| 9. Release Candidate Verification | 검증 완료된 범위만 APK로 빌드하고 업로드한다. | `pubspec.yaml`, Android build output, GDrive APK folder, release docs | full flutter/node checks, APK install/device smoke | dirty tree의 미검증 변경이 같이 들어갈 수 있음. 빌드번호/문서 불일치 가능 | 테스트 실패, 버전/빌드번호 불명확, APK에 원치 않는 변경 포함 |
| 10. Completion Docs and Commit | 완료된 phase만 current/completed 문서에 반영하고 정확한 파일만 stage/commit/push한다. | `docs/GOAL`, `docs/PHASE`, `docs/COMPLETED`, verified code/test/migration files only | `git status`, `git diff --check`, final test summary, stage list review | unrelated dirty files stage, `.env`/도장/민감정보 포함, 완료 문서 과장 | stage list에 승인 범위 밖 파일이 있으면 중단 |

## 5.2 Expected Modification Scope by Phase
| Phase | Expected Modification Scope |
| --- | --- |
| 0 | No file modification. Report only. |
| 1 | No repo modification unless device/public runtime issue requires a new corrective PM or hotfix phase. |
| 2 | Remote DB migration apply using existing migration draft. Repo file modification only if migration drift is found and must be corrected before apply. |
| 3 | Runtime restart only. Repo file modification only if public smoke proves code/config drift. `.env*` or service config changes are anomaly stops unless 사장님 explicitly confirms them inside this PM run. |
| 4 | Runtime DB/file write for one approved row. No broad code change. If endpoint fails due to code bug, stop and report before patching unless running under `pa all` and the fix stays inside the PM scope. |
| 5 | PM/schema docs and possibly additive migration draft. No remote DB apply in this phase unless it is moved into a later reviewed migration step under `pa all`. |
| 6 | Docs/policy updates. Do not copy stamp/seal binaries into git. Asset path may be recorded only without exposing secret/private binary content. |
| 7 | Backend generator code, focused tests/scripts, docs update. Expected area is `reservation_ai_parser/src/` plus file metadata handling. Flutter changes only if needed for trigger contract. |
| 8 | Flutter fine notice UI/client changes and backend guarded file endpoint. No external submission adapter. |
| 9 | Build/version/release docs and APK artifact/upload. Do not modify unrelated features. |
| 10 | Docs finalization, precise staging, commit, push. No new feature edits. |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Submission policy research | Phase 1 only | Read current submission policy draft and official/public sources for one selected profile. Do not edit files, do not log in, do not submit. Identify whether channel/docs are LOCKED, CANDIDATE, or UNKNOWN. | `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`, selected real notice profile | source list, blocker list, policy recommendation | Primary agent and 사장님 review before Phase 5/6 |
| Insurance sample search audit | Phase 0 or 1 only | Inspect existing docs/tests/log-free code paths for insurance candidate coverage. Under `pa all`, live read-only API probes are allowed if needed and if they do not mutate IMS/external state. | `reservation_ai_parser/src/server.js`, fine notice PMs, tests | whether a known insurance smoke sample exists | Primary agent decides if Phase 4 can include insurance or must stay normal-only |
| Template wording review | Phase 5 only | Review police name-change template variables and open questions. Do not change legal wording. Flag current company info, 민감정보 display, and 법령문구 confirmation needs. | traffic police template PM | checklist and unresolved questions | 사장님 locks wording before generator |

## 7. Phases

### Phase 0. Baseline and Anomaly Audit
Status: PLANNED

Purpose:
Reconfirm the exact current state before touching DB/runtime/files.

Scope:
- In:
  - git status and untracked file list
  - current PM/current/handoff docs
  - endpoint route search
  - app status values and migration status policy
  - test/harness availability
  - protected target check
- Out:
  - file edits
  - DB apply
  - restart
  - runtime writes
  - commit

Files/Targets:
- `docs/GOAL/rentcar00_OPS-current.md`
- `docs/PHASE/rentcar00_OPS-fine-notice-mvp-handoff-20260619.md`
- `docs/PHASE/rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/`
- `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql`

Execution Steps:
1. Run read-only git and file searches.
2. Check that app/client endpoint paths still match PM policy.
3. Check that `not_our_vehicle` appears in app/model/tests and migration draft.
4. Check whether any newer edits conflict with this PM.
5. If any mismatch is found, stop and ask 사장님 before Phase 1+.

Verification:
- Static checks:
  - `git status --short --branch`
  - `rg -n "/ims/search-reservations|/ims/search-fine-notice-contracts|save-contract-pdf|not_our_vehicle" reservation_ai_parser/src lib/features/fines supabase/migrations docs/PHASE docs/GOAL`
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 receives anomaly report.

Completion Evidence:
- Code/doc evidence: read-only report
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: None

Review Gate:
- Reviewer: 사장님
- Required checks: no policy/code/doc mismatch; protected actions still clearly separated.
- Failure handling: stop with conflict list and options.

Completion Judgment:
- PASS criteria: next protected phase has a clean, verified baseline.
- FAIL criteria: any route/status/schema/runtime expectation is unclear.

Commit Gate:
- Stage scope: None
- Commit message: None
- Commit only after: Not applicable

Next Phase Entry Criteria:
사장님 approves the specific next phase.

Rollback/Compensation:
None; read-only phase.

### Phase 1. b52 Device and Public Runtime Verification
Status: PLANNED

Purpose:
Confirm that the user-facing b52 app and public parser route are usable before DB/runtime changes continue.

Scope:
- In:
  - b52 APK 실기기 menu check
  - AI parser connection indicator/check
  - public `GET /health`
  - public `/parse-fine-notice` JSON behavior with safe test payload
  - no-login/no-live-submission checks
- Out:
  - parser restart
  - DB write
  - APK rebuild/upload
  - code changes

Files/Targets:
- b52 APK already uploaded in GDrive according to docs
- `https://parser.00rentcar.com/health`
- `https://parser.00rentcar.com/parse-fine-notice`
- App UI: top `예약 / 일정 / 과태료` selector and fine notice AI parser flow

Execution Steps:
1. Confirm b52 installed version/build on device if 사장님 provides device result or screenshot.
2. Verify top menu does not break at phone width.
3. Verify public parser health returns JSON.
4. Verify bad/safe `/parse-fine-notice` request returns JSON error, not HTML/404.
5. If actual notice image testing is approved/provided, check parse result without saving external submissions.

Verification:
- Static checks: Not in scope
- Tests: Not in scope
- Harness/smoke:
  - public curl health
  - public parser JSON shape
- Manual review:
  - 사장님 confirms device UI and parser attempt result.

Completion Evidence:
- Code/doc evidence: none
- Test evidence: public smoke result summary
- Runtime/DB/external evidence, if applicable: public parser response shape only

Review Gate:
- Reviewer: 사장님
- Required checks: app menu readable, parser returns JSON, no raw FormatException.
- Failure handling: stop and decide whether fix is UI, public route, runtime restart, or APK rebuild.

Completion Judgment:
- PASS criteria: b52/public parser is usable enough to continue operational gates.
- FAIL criteria: APK still has broken menu, parser returns 404/HTML, or app cannot reach parser.

Commit Gate:
- Stage scope: None
- Commit message: None
- Commit only after: Not applicable

Next Phase Entry Criteria:
Phase 0 passed and 사장님 approves either DB apply or parser restart.

Rollback/Compensation:
None for read/public verification. If public parser is wrong, proceed only through Phase 3 after approval.

### Phase 2. Remote DB Status Migration Apply
Status: PLANNED

Purpose:
Allow `not_our_vehicle` status in remote Supabase so app saves do not fail for non-owned/non-managed vehicles.

Scope:
- In:
  - inspect pending migration
  - confirm existing remote constraint shape if read-only check is available
  - apply `20260619190000_add_not_our_vehicle_fine_notice_status.sql`
  - verify remote accepts/defines status constraint; under `pa all`, a minimal sample/status write is allowed if needed for verification
- Out:
  - unrelated schema changes
  - data cleanup
  - file storage changes
  - parser restart

Files/Targets:
- `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql`
- Remote Supabase `public.rc00_ops_fine_notices`

Execution Steps:
1. Re-read migration and compare allowed status list with app statuses.
2. Confirm this migration only drops/re-adds status check and does not alter data.
3. Report exact SQL and expected impact.
4. Apply only after `pa fine-notice-next-db-apply`.
5. Verify constraint presence or migration success.
6. Stop if remote schema differs from local assumptions.

Verification:
- Static checks:
  - `rg -n "not_our_vehicle|status in" supabase/migrations lib/features/fines test`
- Tests:
  - `flutter test test/fine_notice_models_test.dart` before or after if code unchanged
- Harness/smoke:
  - remote schema/migration status check
  - under `pa all`, a minimal sample/status write is allowed if needed for verification; otherwise no sample row write
- Manual review:
  - 사장님 confirms DB migration result summary.

Completion Evidence:
- Code/doc evidence: migration file path and SQL summary
- Test evidence: status model test result if run
- Runtime/DB/external evidence, if applicable: remote migration apply result

Review Gate:
- Reviewer: 사장님
- Required checks: migration scope is exactly status constraint; no data rewrite.
- Failure handling: stop, do not retry destructive SQL; report remote error and rollback options.

Completion Judgment:
- PASS criteria: remote DB allows `not_our_vehicle` status under the expected constraint.
- FAIL criteria: migration fails, remote schema differs, or status list conflicts.

Commit Gate:
- Stage scope: None in this phase unless Phase 10 is reached under `pa all` or commit is phase-approved
- Commit message: None
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
Remote DB status compatibility confirmed.

Rollback/Compensation:
If needed, prepare a new explicit migration restoring previous status list. Do not auto-rollback without approval.

### Phase 3. Parser Runtime Restart and Public Smoke
Status: PLANNED

Purpose:
Make public parser runtime serve the verified local endpoint policy.

Scope:
- In:
  - identify current parser process and restart method
  - restart only approved parser service
  - verify public health, fine parser route, fine notice contract search route, and PDF save missing-row JSON response
  - verify reservation parser basic route still works
- Out:
  - cloudflared/tunnel reconfiguration unless explicitly required and approved
  - `.env` edits
  - DB migration
  - real PDF save
  - APK build/upload

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/package.json`
- public `https://parser.00rentcar.com`
- runtime process/service only after approval

Execution Steps:
1. Record current public health response.
2. Identify restart command/process without changing config.
3. Confirm rollback path.
4. Restart only after `pa fine-notice-next-parser-restart`.
5. Run public smoke:
   - `/health`
   - `/parse-fine-notice` safe invalid payload returns JSON
   - `/ims/search-fine-notice-contracts` safe read-only sample if approved
   - `/fine-notices/save-contract-pdf` missing-row returns JSON error without password/token blocker
6. Stop if reservation parser behavior regresses.

Verification:
- Static checks:
  - `npm --prefix reservation_ai_parser run check`
- Tests:
  - Not mandatory unless code changed
- Harness/smoke:
  - public endpoint checks before/after restart
- Manual review:
  - 사장님 confirms runtime restart was intended and smoke result is acceptable.

Completion Evidence:
- Code/doc evidence: no code changes expected
- Test evidence: node check result
- Runtime/DB/external evidence, if applicable: public smoke results

Review Gate:
- Reviewer: 사장님
- Required checks: parser public endpoints JSON, reservation path not broken.
- Failure handling: rollback restart or restore previous process; stop before further runtime writes.

Completion Judgment:
- PASS criteria: public parser serves current endpoint policy and no existing parser route is broken.
- FAIL criteria: 404/HTML response, restart failure, service routing change required, or reservation parser regression.

Commit Gate:
- Stage scope: None
- Commit message: None
- Commit only after: Not applicable

Next Phase Entry Criteria:
Phase 2 DB status compatibility and Phase 3 public parser alignment are both confirmed.

Rollback/Compensation:
Restart previous known-good process if recorded. Do not edit runtime config without new approval.

### Phase 4. Contract Original PDF Runtime Smoke
Status: PLANNED

Purpose:
Verify that one real confirmed fine notice can save its IMS contract PDF as `contract_original`.

Scope:
- In:
  - one 사장님-approved fine notice row with confirmed contract
  - source type/id check before write
  - call `POST /fine-notices/save-contract-pdf`
  - verify file role metadata and local file path
  - open/check saved PDF manually without exposing sensitive data
- Out:
  - batch generation
  - stamped contract generation
  - application PDF generation
  - external submission
  - broad DB/file cleanup

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/data/fine_notice_contract_pdf_client.dart`
- Remote Supabase fine notice row selected by 사장님
- Mac mini SSD `storage/fine-notices`

Execution Steps:
1. Ask 사장님 to identify or approve exactly one fine notice row.
2. Confirm row has `confirmed_contract_source_type` and correct PDF id semantics:
   - normal: PDF-safe `contractId` or fallback path available
   - insurance: `claimId`
3. Confirm no 민감정보 will be printed into docs/logs.
4. Call save endpoint only after `pa fine-notice-next-contract-pdf-smoke`.
5. Verify response JSON, file role `contract_original`, file exists, and PDF opens.
6. Stop if saved PDF does not match selected contract.

Verification:
- Static checks:
  - route/client path still uses `/fine-notices/save-contract-pdf`
- Tests:
  - `npm --prefix reservation_ai_parser run check`
- Harness/smoke:
  - one runtime write smoke
  - file existence/open check
- Manual review:
  - 사장님 or operator checks PDF is correct contract.

Completion Evidence:
- Code/doc evidence: none expected
- Test evidence: node check result
- Runtime/DB/external evidence, if applicable: saved file role/path summary without sensitive data

Review Gate:
- Reviewer: 사장님
- Required checks: correct row, correct source, correct PDF, no sensitive data leakage.
- Failure handling: stop; report whether failure is source id, IMS PDF endpoint, storage path, DB metadata, or permissions.

Completion Judgment:
- PASS criteria: exactly one approved fine notice row saves a correct `contract_original.pdf`.
- FAIL criteria: wrong contract, missing file, DB/file write error, sensitive data logging, or source id ambiguity.

Commit Gate:
- Stage scope: None
- Commit message: None
- Commit only after: Not applicable

Next Phase Entry Criteria:
Contract original PDF source flow is verified.

Rollback/Compensation:
Do not delete files automatically. Report created path/metadata and ask if cleanup is needed.

### Phase 5. Document Data Policy and Schema Lock
Status: PLANNED

Purpose:
Lock the data model and privacy policy needed for renter change documents.

Scope:
- In:
  - renter structured fields decision
  - identity type and masking/display policy
  - batch/document list fields
  - outbound document number format
  - migration draft only
  - doc updates
- Out:
  - remote DB apply
  - generator implementation
  - live submission
  - raw 민감정보 in docs/logs

Files/Targets:
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
- `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
- possible new migration draft under `supabase/migrations/`
- `lib/features/fines/domain/fine_notice_models.dart` only in later implementation phase

Execution Steps:
1. Review Phase 4 PDF smoke evidence.
2. Decide which fields must be structured vs kept in `renter_snapshot_json`.
3. Lock identity handling:
   - resident registration
   - driver license
   - birth date only
   - unknown
4. Decide what may be shown in UI and what must be masked.
5. Decide batch fields for multi-row document list.
6. Draft additive migration if approved for planning.
7. Stop if IMS cannot reliably provide required fields.

Verification:
- Static checks:
  - docs links and schema names
  - proposed SQL is additive only
- Tests:
  - Not in scope unless migration/model draft created
- Harness/smoke: Not in scope
- Manual review:
  - 사장님 confirms 민감정보 policy and document number policy.

Completion Evidence:
- Code/doc evidence: updated PM/schema decision
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: None

Review Gate:
- Reviewer: 사장님
- Required checks: fields, masking, batch, document number, DB apply separation.
- Failure handling: keep manual document preparation; do not implement generator.

Completion Judgment:
- PASS criteria: implementation can proceed without guessing sensitive data rules.
- FAIL criteria: any required field/source/display policy remains ambiguous.

Commit Gate:
- Stage scope: approved docs/migration draft only
- Commit message: `docs: lock fine notice document data policy`
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
Schema/policy is reviewed and generator scope is clear.

Rollback/Compensation:
Docs/migration draft can be revised before remote apply. No runtime rollback needed.

### Phase 6. Stamp Asset and Template Lock
Status: PLANNED

Purpose:
Lock the stamp/seal asset policy and document templates before PDF generation.

Scope:
- In:
  - identify existing stamp/seal source files without copying into git
  - decide official storage path outside git if needed
  - lock `contract_with_stamps` placement rules
  - lock `renter_change_application` template variables
  - lock `vehicle_application_list` minimum columns
  - confirm company address/tel/fax/email/current legal wording status
- Out:
  - creating new stamp images
  - committing stamp/seal originals
  - final legal advice
  - external submission

Files/Targets:
- `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
- stamp/seal file locations under `pa all` or phase approval; do not commit stamp/seal originals unless Phase 10 stage scope explicitly includes them

Execution Steps:
1. Confirm whether stamp/seal assets already exist and where they should live.
2. Confirm they must not be committed to git unless explicitly approved.
3. Lock template variables and unresolved legal/company info questions.
4. Define layout review method: generated sample PDF must be opened by a person.
5. Stop if asset location, permission, or wording is unclear.

Verification:
- Static checks:
  - no stamp/seal file added to git status
  - template variables list complete
- Tests: Not in scope
- Harness/smoke: sample render later in Phase 7
- Manual review:
  - 사장님 confirms asset path and template policy.

Completion Evidence:
- Code/doc evidence: template/asset policy doc update
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: None

Review Gate:
- Reviewer: 사장님
- Required checks: asset path, no git leakage, company info, 민감정보 display, wording status.
- Failure handling: pause generator; keep `contract_original` manual fallback.

Completion Judgment:
- PASS criteria: renderer can locate allowed assets and templates without guessing.
- FAIL criteria: asset/wording/company info remains ambiguous.

Commit Gate:
- Stage scope: docs only; no stamp/seal binaries unless explicitly approved
- Commit message: `docs: lock fine notice stamp and template policy`
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
Phase 5 and Phase 6 are both reviewed.

Rollback/Compensation:
Docs can be revised. If asset was copied by mistake, stop and ask before cleanup/delete.

### Phase 7. Backend Document Generator MVP
Status: PLANNED

Purpose:
Generate manual-ready fine notice document package files after source PDF, schema, and templates are locked.

Scope:
- In:
  - `contract_with_stamps.pdf`
  - `renter_change_application.pdf`
  - optional `vehicle_application_list` for batch/multi-row
  - file metadata insert/update
  - no external submission
- Out:
  - document24/fax/email/site sending
  - unsupported profiles
  - broad batch automation beyond locked profile
  - secret/stamp asset commits

Files/Targets:
- likely `reservation_ai_parser/src/server.js` or a new generator module under `reservation_ai_parser/src/`
- `lib/features/fines/data/*` only if app trigger requires it later
- `rc00_ops_fine_notice_files`
- Mac mini SSD `storage/fine-notices`
- tests/scripts to be decided from existing Node/Flutter harness

Execution Steps:
1. Re-read Phase 4-6 outputs.
2. Choose smallest renderer implementation matching existing Node service style.
3. Implement file generation for one locked profile or generic manual-ready package.
4. Write generated files using existing storage policy.
5. Store file role metadata.
6. Run local tests and one approved runtime generation smoke.
7. Open generated PDF manually and check stamp placement/values.
8. Stop if generated content is legally/policy ambiguous.

Verification:
- Static checks:
  - `npm --prefix reservation_ai_parser run check`
  - `git diff --check`
- Tests:
  - add focused generator test if practical
  - `flutter test test/fine_notice_models_test.dart` if app model touched
- Harness/smoke:
  - one approved manual-ready generation smoke
  - PDF open/render review
- Manual review:
  - 사장님 confirms sample PDF content and stamp placement.

Completion Evidence:
- Code/doc evidence: generator code and docs updated
- Test evidence: node/flutter checks
- Runtime/DB/external evidence, if applicable: generated file paths/roles without sensitive raw values

Review Gate:
- Reviewer: 사장님
- Required checks: correct contract, correct recipient/template, correct stamp placement, no live submission.
- Failure handling: disable/hide generator trigger and keep manual PDF attachment fallback.

Completion Judgment:
- PASS criteria: one manual-ready document package is generated and manually accepted.
- FAIL criteria: wrong values, unreadable PDF, asset missing, sensitive leak, or profile policy mismatch.

Commit Gate:
- Stage scope: approved generator code, tests, docs only
- Commit message: `feat: generate fine notice manual-ready documents`
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
Generated documents pass manual review.

Rollback/Compensation:
Do not delete generated runtime files automatically. Hide/revert app trigger or generator route if needed.

### Phase 8. App File Access and Share MVP
Status: PLANNED

Purpose:
Let the app show document package status and access/share generated files through a guarded HTTPS path.

Scope:
- In:
  - file status in fine notice detail/list
  - guarded download/share endpoint
  - app button for manual-ready files
  - path traversal and role guard
- Out:
  - phone gallery as official storage
  - unauthenticated broad file browsing
  - external submission
  - unrelated UI redesign

Files/Targets:
- `lib/features/fines/`
- `reservation_ai_parser/src/server.js` or dedicated file endpoint module
- `rc00_ops_fine_notice_files`
- Mac mini SSD `storage/fine-notices`

Execution Steps:
1. Lock file access policy: allowed roles, path guard, auth/secret model.
2. Implement backend endpoint for approved file retrieval.
3. Implement app UI for generated file status and share/download.
4. Verify no arbitrary path access.
5. Verify mobile flow with one generated file.

Verification:
- Static checks:
  - `flutter analyze`
  - `npm --prefix reservation_ai_parser run check`
  - `git diff --check`
- Tests:
  - `flutter test`
  - targeted backend guard test if practical
- Harness/smoke:
  - valid file download
  - invalid path/role denied
  - app share/download manual check
- Manual review:
  - 사장님 confirms mobile workflow.

Completion Evidence:
- Code/doc evidence: app/API changes
- Test evidence: flutter/node checks
- Runtime/DB/external evidence, if applicable: one guarded file access smoke

Review Gate:
- Reviewer: 사장님
- Required checks: file opens on phone, no broad file exposure, official storage policy preserved.
- Failure handling: disable app button and keep manual Mac mini file access.

Completion Judgment:
- PASS criteria: app can access/share approved generated files safely.
- FAIL criteria: file guard weak, wrong file served, or mobile flow unreliable.

Commit Gate:
- Stage scope: approved app/API/tests/docs only
- Commit message: `feat: share fine notice generated files`
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
All intended MVP user flow checks pass.

Rollback/Compensation:
Hide button/route and keep files in official storage.

### Phase 9. Release Candidate Verification
Status: PLANNED

Purpose:
Prepare a release candidate only after DB/runtime/app/document flows are verified.

Scope:
- In:
  - final analyze/test/check
  - version/build decision
  - APK build
  - APK upload under `pa all` or release phase approval
  - release note docs
- Out:
  - unverified feature inclusion
  - deploy beyond approved APK/parser scope
  - commit before Phase 10

Files/Targets:
- `pubspec.yaml`
- Android build output
- GDrive APK folder
- docs current/completed release notes

Execution Steps:
1. Confirm all included phases are verified.
2. Run full local verification suite.
3. Confirm build number/version.
4. Build APK after `pa fine-notice-next-release`.
5. Upload only if upload approval is explicit.
6. Record APK file name and verification status in docs.

Verification:
- Static checks:
  - `flutter analyze`
  - `git diff --check`
- Tests:
  - `flutter test`
  - `npm --prefix reservation_ai_parser run check`
  - fine parser checks if parser changed
- Harness/smoke:
  - install APK or device smoke if available
- Manual review:
  - 사장님 confirms APK install and core flows.

Completion Evidence:
- Code/doc evidence: version/build and release docs
- Test evidence: full check summary
- Runtime/DB/external evidence, if applicable: APK path/upload result

Review Gate:
- Reviewer: 사장님
- Required checks: build includes intended changes only; no protected config leaks.
- Failure handling: do not upload or supersede bad APK; fix under new phase.

Completion Judgment:
- PASS criteria: APK is verified and uploaded only if approved.
- FAIL criteria: tests fail, build identity unclear, or device smoke fails.

Commit Gate:
- Stage scope: handled in Phase 10
- Commit message: None here unless explicitly combined with Phase 10
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
Release notes and verification are ready for commit.

Rollback/Compensation:
If upload was bad, supersede with new APK after approval; do not delete remote files unless approved.

### Phase 10. Completion Docs and Commit
Status: PLANNED

Purpose:
Commit only the verified, approved scope and archive completed PMs correctly.

Scope:
- In:
  - update current/completed docs
  - archive completed phase docs if appropriate
  - stage exact files
  - commit approved scope
- Out:
  - staging `.env*`
  - staging stamp/seal originals
  - staging unrelated dirty files
  - push before Phase 10 or outside `pa all`/explicit push scope

Files/Targets:
- `docs/GOAL/rentcar00_OPS-current.md`
- `docs/PHASE/*`
- `docs/COMPLETED/*`
- exact code/migration/test files from verified phases only

Execution Steps:
1. Summarize verified phases and residual risks.
2. Update docs according to `PROJECT_DOCUMENTATION_RULES.md`.
3. Show `git status --short` and intended stage list.
4. Stage only approved files after `pa fine-notice-next-commit`.
5. Commit with a message matching completed scope.
6. Push if Phase 10 is reached under `pa all` and no anomaly remains; otherwise do not push without explicit approval.

Verification:
- Static checks:
  - `git diff --check`
  - `git status --short`
  - targeted docs link/path checks
- Tests:
  - repeat relevant checks from completed phases before commit
- Harness/smoke:
  - not needed unless phase changed runtime after last verification
- Manual review:
  - 사장님 approves stage scope.

Completion Evidence:
- Code/doc evidence: commit hash
- Test evidence: final verification summary
- Runtime/DB/external evidence, if applicable: release/runtime status summary

Review Gate:
- Reviewer: 사장님
- Required checks: no unrelated/protected files staged; docs reflect reality.
- Failure handling: unstage only the incorrect staged files; do not reset worktree.

Completion Judgment:
- PASS criteria: approved scope committed with accurate docs and residual risk note.
- FAIL criteria: unrelated dirty files included, tests stale, or docs exaggerate completion.

Commit Gate:
- Stage scope: exact approved files only
- Commit message: to be chosen from completed scope, e.g. `feat: complete fine notice document MVP gate`
- Commit only after: `pa fine-notice-next-commit`

Next Phase Entry Criteria:
Under `pa all`, push may proceed if Phase 10 reaches that step and no anomaly/stop condition remains. Otherwise push or next feature PM requires separate approval.

Rollback/Compensation:
Use a new revert commit only if 사장님 approves. Do not reset or checkout.

### Final Completion Report
- Completed phases:
  - None yet. This PM is in review.
- Commits:
  - None.
- Verification summary:
  - PM creation was based on current docs, git status, endpoint/status searches, migration draft, and package scripts.
- Residual risks:
  - b52 device verification still pending.
  - remote DB may not allow `not_our_vehicle` yet.
  - operating parser may not be restarted on current code.
  - real `contract_original.pdf` save is not yet proven.
  - 민감정보/schema/stamp/template policies are not locked.
  - submission policies are not LOCKED.
- Follow-up work:
  - First recommended approval for staged execution: `pa fine-notice-next-p0`.
  - Full execution approval: `pa all`.
  - Under `pa all`, execute Phase 0-10 in order and stop only for anomaly/stop conditions.
