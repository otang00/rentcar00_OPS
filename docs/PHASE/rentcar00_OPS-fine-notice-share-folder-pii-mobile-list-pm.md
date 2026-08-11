# rentcar00 OPS Fine Notice Share Folder, PII, Mobile List PM

## Document Metadata
- Created at: 2026-06-20 KST
- Last updated at: 2026-06-20 KST
- Author/agent: Codex
- Related milestone: 과태료 문서 패키지 실사용 안정화
- Related goal/spec docs:
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-app-document-package-mvp-pm.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
- Current status: Completed
- Execution scope: 과태료 문서 묶음 폴더를 `원본/공유`로 분리하고, 공유 폴더에는 정해진 제출 문서만 남기며, 금액 제거/개인정보 원문 전달/중복 생성 방지/모바일 리스트 축소까지 구현한다.
- Archive target: `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_share_folder_pii_mobile_list_pm.md`

## 0. Goal Lock
- Objective: 앱에서 공유할 때 문서가 과하게 날아가지 않도록, 한 고지서묶음 폴더 안에 `original/`과 `share/`를 분리하고 `share/` 안의 허용 문서만 핸드폰 공유창으로 보낸다.
- Final success condition:
  - 저장 구조가 `storage/fine-notices/notices/{고지서날짜}/{고지서묶음ID}/original/`과 `.../share/` 두 폴더로 고정된다.
  - 원본 고지서/계약서/보존용 파일은 `original/`에 남고, 공유 대상은 `share/`에만 생성된다.
  - 공유는 `share/` 안의 허용 role만 사용한다.
  - 계약서 공유본은 도장 찍힌 첫 장 계약서 1개만 포함한다.
  - 신청서/목록/앱 리스트에서 통행금액/과태료 금액을 제거한다.
  - 임차인 변경 문서에는 전화번호, 주민등록번호, 운전면허번호를 중간 마스킹 없이 원문으로 출력한다.
  - DB에는 주민등록번호와 운전면허번호를 둘 다 저장할 수 있고, 둘 다 있으면 둘 다 보존한다.
  - 완전 동일 파일은 중복 생성/중복 표시하지 않고 이미 존재로 처리한다.
  - 같은 role인데 내용이 다른 파일은 덮어쓰기/버전 정책을 적용하되, 기존 이상 상태는 자동 삭제하지 않고 중단 보고한다.
  - 모바일 과태료 목록은 좌우 스크롤 없이 보기 좋게 `차량번호`, `발송처`, `위반/통행일` 중심으로 표시한다.
  - `계약서확정`, `문서작성`, `발송완료`는 얇은 상태 2줄로 보여준다.
- Explicit non-goals:
  - 외부 기관 자동 발송
  - 카카오톡 방 자동 선택/자동 전송
  - 원본 파일 삭제
  - 과거 중복 파일 대량 정리
  - 고지서 외 다른 업무 화면 개편
  - 개인정보를 로그/PM 문서/완료보고서에 원문으로 기록
- Protected targets:
  - `storage/fine-notices`
  - `rc00_ops_fine_notice_files`
  - `rc00_ops_fine_notices`
  - 주민등록번호, 운전면허번호, 전화번호, 주소
  - 계약서 원본 PDF
  - 회사 인감/도장 이미지
  - parser service `ai.otang.reservation-ai-parser`
- Execution scope includes:
  - 서버 저장 경로/파일 role 정책 수정
  - 문서 생성 템플릿 금액 제거 및 개인정보 원문 출력
  - 공유 대상 파일 목록 필터 수정
  - 중복 파일 생성 방지
  - 앱 모바일 리스트 레이아웃 축소
  - 실제 고지서 묶음 smoke 검증

## 1. Current State Evidence
- Repo status:
  - 현재 작업트리는 깨끗하지 않다.
  - 수정 중 파일:
    - `lib/features/fines/domain/fine_notice_models.dart`
    - `reservation_ai_parser/src/server.js`
  - 위 변경은 직전 문서 디자인/도장 위치/공유 원본 제외 작업에서 나온 것이다. 다음 구현 시 덮어쓰지 말고 이어서 반영한다.
- Existing implementation:
  - 서버에는 `/fine-notices/generate-documents`, `/fine-notice-file-packages`, `/fine-notice-files/download`가 있다.
  - 현재 저장 기준은 `notices/{고지서날짜}/{고지서묶음ID}/` 아래에 `contract/`, `documents/` 등 역할별 하위 폴더가 섞인다.
  - 현재 생성 응답에는 보존용 `contract_original`도 포함된다.
  - 앱 공유는 `FineNoticeFileMetadata.isPackageDocument`로 공유 파일을 고른다.
  - 직전 수정으로 공유 목록에서 `contract_original`은 제외됐지만, 서버 폴더 자체가 원본/공유로 분리되어 있지는 않다.
  - 현재 신청서에는 금액 항목이 남아 있고, 통행목록에도 금액 열이 있다.
  - 현재 문서 생성은 `maskPhoneForDocument()`를 사용해 전화번호를 마스킹한다.
  - 현재 DB migration에는 `renter_identity_no`와 `renter_driver_license_no` 컬럼이 이미 있다.
  - 현재 `renter_identity_type`은 primary identity 분류용이고, 주민등록번호와 운전면허번호 둘 다 있을 때의 보존/출력 정책은 아직 명확히 잠기지 않았다.
  - 현재 앱 리스트는 `DataTable` 최소폭 980, 금액/장소/상태 3열이 있어 모바일에서 좌우로 길다.
- Existing docs/specs:
  - 기존 앱 문서 패키지 PM에는 금액 열 표시, 전화번호 마스킹, 폴더 내부 `notice/contract/documents` 구조가 남아 있다.
  - 이 PM은 그 정책을 supersede한다.
- Existing tests/harness:
  - `node --check reservation_ai_parser/src/server.js`
  - `flutter analyze lib/features/fines`
  - `flutter test test/fine_notice_models_test.dart`
  - parser health smoke: `GET /health`
  - 실제 sample generation smoke: `POST /fine-notices/generate-documents`
  - PDF render review with bundled Poppler `pdftoppm`
- Known conflicts or drift:
  - 기존 생성 파일이 2번 생성되어 같은 폴더 안에 중복처럼 보이는 상태가 있다.
  - 완전 동일 파일인지, 같은 role 다른 내용인지 확인 전에는 자동 삭제하면 안 된다.
  - 문서 제출에는 개인정보 원문이 필요하지만, 개발 로그/보고서에는 원문을 남기면 안 된다.
  - 기존 PM의 "단일은 위반목록 없음" 정책은 유지한다.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| 저장 폴더 | 묶음 폴더 안에 role별 파일 혼재 | `original/`과 `share/` 두 폴더로 분리 | 원본 보존과 공유 대상을 눈으로 구분 |
| 공유 대상 | 앱 role 필터 중심 | `share/` 폴더 + role allowlist 둘 다 통과한 파일만 공유 | 문서가 과하게 공유되는 문제 방지 |
| 계약서 | 원본/도장본이 둘 다 보일 수 있음 | 공유에는 도장 찍힌 첫 장 계약서만 포함 | 제출에 필요한 계약서는 도장본 1개 |
| 금액 | 신청서/목록/UI에 표시 | 문서/목록/UI에서 제거 | 사용자가 볼 필요 없고 불필요한 정보 노출 |
| 전화번호 | 일부 문서에서 마스킹 | 제출 문서에는 원문 전체 출력 | 개인정보 전달 없으면 임차인 변경 불가 |
| 주민번호/면허번호 | primary identity 중심 | 주민번호와 면허번호 둘 다 저장/출력 가능 | 기관 제출 요구 대응 |
| 중복 생성 | 같은 문서를 여러 번 만들 수 있음 | 동일 sha/role/path는 이미 존재 처리 | 2번 눌러도 같은 파일이 쌓이지 않게 함 |
| 모바일 리스트 | 폭 980 표, 금액/장소 포함 | 차량번호/발송처/위반일 + 얇은 2줄 상태 | 핸드폰 첫 화면에서 바로 읽히게 함 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| File storage | `reservation_ai_parser/src/server.js`, `storage/fine-notices` | Medium | 기존 파일 위치와 새 위치가 섞임 | 새 생성부터 새 구조 적용, 기존은 삭제하지 않음 |
| Share package | `FineNoticeFileMetadata`, `FineNoticeDocumentClient`, server list/download | Medium | 공유 대상 누락 또는 과다 포함 | `share/` folder guard + role allowlist |
| PII handling | DB columns, mapper, PDF generator | High | 로그/문서에 민감정보 유출 | 생성 PDF에는 원문, 로그/보고서에는 마스킹/미기록 |
| Document template | application/list PDF generator | Medium | 기관 제출에 필요한 값 누락 | 금액만 제거, 전화/주민/면허/주소는 유지 |
| Duplicate guard | file metadata + filesystem writes | Medium | 다른 내용의 파일을 조용히 덮어씀 | 동일 sha만 skip, 충돌은 report/controlled replace |
| Mobile UI | `fine_notice_page.dart` | Medium | 너무 축약돼 세부 정보 접근 어려움 | 행 클릭 상세 모달에 전체 정보 유지 |
| Tests/smoke | Flutter + parser + PDF render | Medium | 실제 폰 폭에서 여전히 넘침 | narrow viewport/manual screenshot check |

## 4. Execution Policy
- Execution model:
  - 사용자가 `pa all`을 주면 이 PM 범위는 한 번에 승인된 것으로 보고 순서대로 실행한다.
  - 단, 아래 stop condition은 `pa all`이어도 멈추고 보고한다.
- Phase transition rule:
  - 저장 폴더 분리와 중복 정책이 먼저 통과해야 공유/API/UI를 수정한다.
  - 개인정보 저장/출력 정책이 코드에서 확인되기 전 문서 생성 완료로 보지 않는다.
  - 모바일 리스트가 실제 좁은 폭에서 읽히기 전 완료로 보지 않는다.
- Review rule:
  - 보고서/PM/커밋 메시지에는 주민번호/면허번호/전화번호 원문을 쓰지 않는다.
  - PDF는 실제 제출물이라 원문 출력 여부를 시각 확인하되, 검증 로그에는 원문을 옮겨 적지 않는다.
- Commit rule:
  - 최종 phase에서 scoped commit한다.
  - 기존 미커밋 변경과 이번 구현 변경이 같은 파일에 이어지므로, stage 전 diff를 반드시 확인한다.
- Rollback/compensation rule:
  - 기존 원본 파일은 삭제하지 않는다.
  - 새 `share/` 구조가 실패하면 공유 버튼은 비활성화하고 기존 파일은 보존한다.
  - DB additive field가 이미 없으면 migration 확인 후 진행한다.
- Stop conditions:
  - 기존 폴더에 같은 role 파일이 여러 개 있고 sha가 서로 다르며 최신 기준을 자동 판단할 수 없음.
  - 주민등록번호/운전면허번호를 실제 source에서 가져올 수 없는데 원문 출력이 필요한 상태.
  - `share/` 폴더 밖 파일이 공유 API에 포함됨.
  - storage root 밖 path가 다운로드 가능함.
  - 기존 원본 파일을 삭제해야만 구현 가능해짐.
  - 모바일 리스트에서 주요 텍스트가 겹치거나 버튼을 누를 수 없음.

## 5. Phase Map
| Phase | Responsibility Unit | Owner | State Change | Scope Lock Summary | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 저장 구조/중복 정책 잠금 | Codex | docs/code | `original/`, `share/`, identical skip, conflict stop | No | Final only |
| 2 | 서버 생성 경로/공유 allowlist 구현 | Codex | backend/files | 공유 폴더에는 정해진 제출 파일만 생성 | No | Final only |
| 3 | 개인정보 저장/문서 출력 정책 구현 | Codex | backend/DB mapper | 전화/주민/면허 원문 저장 및 PDF 출력, 로그 미기록 | No | Final only |
| 4 | 금액 제거 및 문서 템플릿 조정 | Codex | backend/PDF | 신청서/목록에서 금액 제거 | Can follow Phase 3 | Final only |
| 5 | 모바일 리스트 축소 | Codex | Flutter UI | 차량번호/발송처/위반일 + 2줄 상태 | After Phase 2 model | Final only |
| 6 | 앱 공유/다운로드 필터 보강 | Codex | Flutter client | `share/` package only share | After Phase 2 | Final only |
| 7 | Runtime/PDF/mobile verification | Codex | tests/runtime | sample generation, render, narrow UI check | No | Final only |
| Final | 완료판정/문서정리/커밋 | Codex | docs/git | completion record and scoped commit | No | Yes |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| None | Not applicable | Not applicable | Not applicable | Not applicable | 저장 구조, 개인정보 정책, 공유 UI가 서로 의존하므로 병렬화하지 않는다. |

## 7. Phases

### Phase 1. 저장 구조/중복 정책 잠금
Status: PLANNED

Purpose:
고지서묶음 폴더 안에서 원본 보존과 공유 대상을 물리적으로 분리하고, 같은 문서가 2번씩 쌓이지 않게 한다.

Work:
1. 새 저장 구조를 고정한다.
   - root: `storage/fine-notices/notices/{noticeDate}/{bundleId}/`
   - original: `storage/fine-notices/notices/{noticeDate}/{bundleId}/original/`
   - share: `storage/fine-notices/notices/{noticeDate}/{bundleId}/share/`
2. `original/` 보존 대상:
   - 원본 고지서
   - IMS 계약서 원본 첫 페이지
   - 필요 시 파싱 원본/보존용 생성물
3. `share/` 공유 대상:
   - `renter_change_application.pdf`
   - `notice_original`의 제출용 복사본
   - `contract_with_stamps.pdf`
   - 2건 이상 묶음일 때만 `vehicle_application_list.pdf`
4. 동일 파일 판단:
   - 같은 bundle, 같은 folder kind, 같은 file role, 같은 sha256이면 "이미 있음"으로 처리하고 새 metadata를 만들지 않는다.
   - 같은 role인데 sha256이 다르면 최신 파일로 교체할지 version suffix를 둘지 코드 구현 직전 diff를 보고 결정한다.
   - 기존에 이미 중복 metadata가 있으면 자동 삭제하지 않고 최신 1개만 표시하거나 중단 보고한다.
5. 파일명은 deterministic하게 잡는다.
   - `신청서.pdf`
   - `고지서.pdf`
   - `계약서.pdf`
   - `통행목록.pdf`

Reason:
사용자가 공유 버튼을 눌렀을 때 필요한 문서만 나가야 하고, 원본은 보존하되 공유되지 않아야 한다.

Scope:
- In: path builder, duplicate guard, metadata policy.
- Out: 과거 파일 대량 삭제, 외부 발송.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `rc00_ops_fine_notice_files`
- `storage/fine-notices/notices/*`

Scope Lock:
- Modification allowed: fine notice path/file helper only
- Creation allowed: `original/`, `share/` under bundle root
- Deletion allowed: none
- Read-only references: existing generated files
- Excluded targets: unrelated storage cleanup
- Behaviors not to change: 계약검색, 고지서 파싱, not_our_vehicle guard
- Outputs: canonical folder policy
- Scope drift criteria: 기존 파일이 동일 role 다중 sha로 충돌해 자동 판단 불가

Execution Steps:
1. Add folder-kind concept: `original` or `share`.
2. Update generated file writer to resolve deterministic path.
3. Add same-sha skip behavior.
4. Add conflict reporting behavior for different-sha duplicate.

Verification:
- Static checks: path guard review.
- Tests: helper/unit test if extracted.
- Harness/smoke: same sample generated twice leaves one share file per role.
- Manual review: folder tree has exactly `original/` and `share/` as user-facing file folders.

Completion Evidence:
- Code/doc evidence: path builder and duplicate policy exist.
- Test evidence: repeated generation result.
- Runtime/DB/external evidence: filesystem tree and file metadata count.

Review Gate:
- Reviewer: Codex
- Required checks: no share file outside `share/`, no original file inside `share/`.
- Failure handling: stop before app sharing.

Completion Judgment:
- PASS criteria: 2번 눌러도 공유 문서가 2장씩 늘지 않는다.
- FAIL criteria: same role duplicate remains visible in share list.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Bundle folder and duplicate policy are verified.

Rollback/Compensation:
- Keep original files; disable share list if duplicate conflict is unresolved.

### Phase 2. 서버 생성 경로/공유 allowlist 구현
Status: PLANNED

Purpose:
서버가 생성/목록/다운로드 단계에서 공유 폴더의 허용 문서만 앱에 넘기게 한다.

Work:
1. `/fine-notices/generate-documents`가 `original/`과 `share/`에 파일을 나눠 쓴다.
2. 생성 응답은 공유용 문서를 우선 반환한다.
3. `/fine-notice-file-packages`는 기본값으로 `share/` 파일만 반환한다.
4. download route는 file id가 bundle root 안이고, share action이면 `share/` 안인지 확인한다.
5. 공유 allowlist를 고정한다.
   - allowed: `notice_original`, `contract_with_stamps`, `renter_change_application`
   - bundle only: `vehicle_application_list`
   - denied: `contract_original`, raw parser temp, unknown roles

Reason:
앱 필터 하나만 믿으면 원본 계약서 같은 보존 파일이 실수로 공유될 수 있다.

Scope:
- In: server generate/list/download response filtering.
- Out: public URL 생성, cloud upload.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/data/fine_notice_document_client.dart`
- `lib/features/fines/domain/fine_notice_models.dart`

Scope Lock:
- Modification allowed: fine notice document/file package routes and model flags
- Creation allowed: helper functions
- Deletion allowed: none
- Read-only references: existing DB rows
- Excluded targets: unrelated parser endpoints
- Behaviors not to change: file id download for allowed PDFs
- Outputs: share-only package response
- Scope drift criteria: app must show original/debug files to complete main workflow

Execution Steps:
1. Add folderKind metadata or infer from relative path.
2. Update package list response to expose share files only by default.
3. Keep original files queryable only if a future explicit debug/original endpoint is added.
4. Confirm app share uses returned package files plus `isPackageDocument`.

Verification:
- Static checks: `node --check reservation_ai_parser/src/server.js`
- Tests: package list does not include `contract_original`.
- Harness/smoke: real bundle list returns only allowed share roles.
- Manual review: generated API response file roles.

Completion Evidence:
- Code/doc evidence: allowlist exists in server/app.
- Test evidence: curl output role list.
- Runtime/DB/external evidence: share response excludes original.

Review Gate:
- Reviewer: Codex
- Required checks: `contract_original` never appears in share package.
- Failure handling: do not proceed to app share button.

Completion Judgment:
- PASS criteria: 공유할 문서가 딱 정해진 목록만 나온다.
- FAIL criteria: 원본 계약서 or unknown role appears in share package.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Share package response is locked.

Rollback/Compensation:
- Disable share button if allowlist check fails.

### Phase 3. 개인정보 저장/문서 출력 정책 구현
Status: PLANNED

Purpose:
임차인 변경에 필요한 개인정보는 DB와 제출 PDF에는 원문으로 넣고, 로그/문서/보고서에는 원문이 남지 않게 분리한다.

Work:
1. DB field policy:
   - `renter_phone`: 전화번호 원문
   - `renter_identity_no`: 주민등록번호 원문
   - `renter_driver_license_no`: 운전면허번호 원문
   - `renter_birth_date`: 주민번호/면허번호가 없을 때 보조 정보
   - `renter_identity_type`: primary 표시용이며 둘 다 저장 여부를 막지 않는다.
2. mapper policy:
   - IMS/API 후보에서 주민번호와 면허번호가 둘 다 있으면 둘 다 저장한다.
   - 하나만 있으면 있는 값만 저장한다.
   - 둘 다 없으면 warning을 남기되, 정책상 기관 제출 가능 여부를 다시 확인한다.
3. PDF policy:
   - 전화번호는 `maskPhoneForDocument()`를 쓰지 않는다.
   - 주민등록번호와 운전면허번호는 원문 전체를 출력한다.
   - 주소도 원문을 출력한다.
4. log/report policy:
   - action log meta에는 raw PII를 넣지 않거나, 이미 들어가는 경우 masking/sanitizing helper를 둔다.
   - PM/완료보고/터미널 보고에는 raw PII를 쓰지 않는다.

Reason:
임차인 변경 신청은 개인정보 전달이 없으면 접수/처리가 안 되지만, 개발 산출물에 원문을 남기면 안 된다.

Scope:
- In: DB mapper, renter snapshot, document generator output.
- Out: 개인정보 암호화 설계, 접근권한 재설계.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/data/fine_notice_repository.dart`
- `lib/features/fines/domain/fine_notice_models.dart`
- `supabase/migrations/20260619200000_add_fine_notice_document_generation_fields.sql`
- `test/fine_notice_models_test.dart`

Scope Lock:
- Modification allowed: fine notice mapper/PDF/model only
- Creation allowed: tests/helpers
- Deletion allowed: none
- Read-only references: existing migration
- Excluded targets: unrelated customer data models
- Behaviors not to change: not_our_vehicle and contract confirmation status
- Outputs: PII full output in PDF, sanitized logs
- Scope drift criteria: missing source data requires IMS probe or schema change beyond existing columns

Execution Steps:
1. Confirm existing columns are available.
2. Update candidate -> renter snapshot -> fine notice columns mapping.
3. Replace document phone masking with full display helper.
4. Add resident and driver license rows to application PDF.
5. Sanitize logs/API debug responses where needed.

Verification:
- Static checks: `flutter analyze lib/features/fines`, `node --check`.
- Tests: model mapping stores both identity values.
- Harness/smoke: generated PDF visually contains unmasked required fields without logging them.
- Manual review: verification report avoids raw PII.

Completion Evidence:
- Code/doc evidence: full PII output helpers exist.
- Test evidence: unit test with fake values.
- Runtime/DB/external evidence: sample PDF visual check only, no raw values copied into report.

Review Gate:
- Reviewer: Codex
- Required checks: no `maskPhoneForDocument()` in submission PDF fields.
- Failure handling: stop if source cannot provide required identity data.

Completion Judgment:
- PASS criteria: 제출 PDF contains phone/resident/license full values when stored.
- FAIL criteria: PDF masks phone or drops one of resident/license values.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- PII storage/output policy is implemented.

Rollback/Compensation:
- Revert PDF output helper and keep document status `검토 필요`.

### Phase 4. 금액 제거 및 문서 템플릿 조정
Status: PLANNED

Purpose:
문서와 리스트에서 사용자가 볼 필요 없는 통행금액/과태료 금액을 제거한다.

Work:
1. 신청서 `신청 대상` 표에서 `금액` 행을 제거한다.
2. 통행목록 표에서 `금액` 열을 제거한다.
3. 통행목록 폭을 줄이고 날짜/장소 중심으로 정리한다.
4. 앱 리스트에서 금액 열을 제거한다.
5. 고지서수정 모달 내부에는 금액 수정 필드를 남길지 별도 판단한다.
   - 추천: DB 원본값 보존을 위해 수정 모달에는 남긴다.
   - 단, 메인 목록/공유 문서에는 표시하지 않는다.

Reason:
금액은 이번 공유/확인 흐름에서 불필요하고, 문서가 복잡해지는 원인이다.

Scope:
- In: generated PDFs, main mobile list.
- Out: DB amount field 삭제, parser amount extraction 삭제.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/presentation/fine_notice_page.dart`

Scope Lock:
- Modification allowed: display/template only
- Creation allowed: none
- Deletion allowed: none
- Read-only references: amount DB columns
- Excluded targets: parser extraction schema
- Behaviors not to change: amount persistence for audit
- Outputs: no amount in share docs/main list
- Scope drift criteria: user requests amount deletion from DB/parser

Execution Steps:
1. Remove amount row/column from application/list generator.
2. Remove DataTable amount column from main UI.
3. Keep raw DB value untouched.

Verification:
- Static checks: node/flutter analyze.
- Tests: PDF smoke and UI text scan.
- Harness/smoke: generated PDF render has no amount row/column.
- Manual review: main mobile list has no amount.

Completion Evidence:
- Code/doc evidence: no amount display in target templates.
- Test evidence: analyzer and smoke.
- Runtime/DB/external evidence: PDF render.

Review Gate:
- Reviewer: Codex
- Required checks: 금액 not visible in share docs/main list.
- Failure handling: remove remaining display path before next phase.

Completion Judgment:
- PASS criteria: 금액은 보존되지만 공유 문서/메인 리스트에는 안 보인다.
- FAIL criteria: 통행목록 or 신청서 still displays amount.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Documents no longer show amount.

Rollback/Compensation:
- Revert template changes if required by agency later.

### Phase 5. 모바일 리스트 축소
Status: PLANNED

Purpose:
과태료 목록을 핸드폰에서 좌우 스크롤 없이 핵심만 읽히게 바꾼다.

Work:
1. 기존 wide `DataTable(minWidth: 980)`을 모바일형 compact list/table로 바꾼다.
2. 첫 줄 정보:
   - 차량번호
   - 발송처
   - 위반/통행일
3. 상태 2줄:
   - 1줄: `계약서확정` check, `문서작성` check
   - 2줄: `발송완료` check, 필요 시 `단일/묶음` 표시
4. 행 클릭 시 기존 상세 모달을 유지한다.
5. 상세 모달에서는 고지서수정/계약서 재검색/문서생성/공유 기능이 계속 작동해야 한다.

Reason:
핸드폰에서 업무를 해야 하므로 메인 목록은 "한눈에 상태 확인"이 목적이고, 세부 작업은 모달에서 하면 된다.

Scope:
- In: fine notice main list layout.
- Out: 전체 앱 navigation redesign.

Files/Targets:
- `lib/features/fines/presentation/fine_notice_page.dart`

Scope Lock:
- Modification allowed: fine notice page widgets/helpers
- Creation allowed: small private widgets in same file or feature-local file
- Deletion allowed: remove unused wide-table-only widgets if replaced
- Read-only references: existing detail modal
- Excluded targets: other feature pages
- Behaviors not to change: row click opens detail modal
- Outputs: compact mobile-first list
- Scope drift criteria: desktop spreadsheet mode is requested as a separate toggle

Execution Steps:
1. Replace main DataTable with compact rows.
2. Add thin status strip widget.
3. Remove amount/location from main row.
4. Verify no overflow on narrow width.

Verification:
- Static checks: `flutter analyze lib/features/fines`.
- Tests: widget test if practical.
- Harness/smoke: narrow viewport/manual screenshot or Android visual check.
- Manual review: no horizontal scrolling needed for core row.

Completion Evidence:
- Code/doc evidence: compact list widgets.
- Test evidence: analyze.
- Runtime/DB/external evidence: screenshot/manual check.

Review Gate:
- Reviewer: Codex
- Required checks: text does not overlap, status is visible.
- Failure handling: reduce text or move secondary values to modal.

Completion Judgment:
- PASS criteria: phone-width list shows vehicle, sender, date, statuses without horizontal scroll.
- FAIL criteria: DataTable width still forces horizontal scroll for normal use.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Compact list is visually acceptable.

Rollback/Compensation:
- Revert to previous table and hide extra columns as a temporary fallback only if compact list breaks.

### Phase 6. 앱 공유/다운로드 필터 보강
Status: PLANNED

Purpose:
앱에서 공유 버튼을 누르면 `share/` 폴더의 정해진 문서만 내려받아 공유창에 넘기게 한다.

Work:
1. `FineNoticeDocumentClient.listPackageFiles()`가 서버의 share-only 응답을 사용한다.
2. `sharePackageFiles()`는 `isPackageDocument`와 서버 metadata/folder kind를 함께 확인한다.
3. 공유 기본 선택은 아래 순서다.
   - 신청서
   - 고지서
   - 계약서
   - 묶음일 때 통행목록
4. `contract_original`은 어떤 경우에도 공유하지 않는다.
5. 문서 생성 완료 후 공유 버튼을 활성화한다.

Reason:
서버와 앱 양쪽에서 거르면 원본 계약서나 보존 파일이 실수로 나갈 가능성이 줄어든다.

Scope:
- In: fine notice document client/share action.
- Out: 카카오톡 자동 전송.

Files/Targets:
- `lib/features/fines/data/fine_notice_document_client.dart`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`

Scope Lock:
- Modification allowed: share/download client and UI button state
- Creation allowed: helper method/tests
- Deletion allowed: none
- Read-only references: server package response
- Excluded targets: other app sharing flows
- Behaviors not to change: user chooses final app from Android/iOS share sheet
- Outputs: share-only package flow
- Scope drift criteria: user requests auto-send to a specific Kakao room

Execution Steps:
1. Add/confirm metadata field for folder kind if needed.
2. Filter package files by role and folder kind.
3. Download only selected share files.
4. Keep error per file/package understandable.

Verification:
- Static checks: `flutter analyze lib/features/fines`.
- Tests: fake metadata share filter test.
- Harness/smoke: package list excludes original.
- Manual review: share button cannot send original.

Completion Evidence:
- Code/doc evidence: app filter.
- Test evidence: analyzer/test.
- Runtime/DB/external evidence: share package role list.

Review Gate:
- Reviewer: Codex
- Required checks: original contract cannot be shared.
- Failure handling: keep share disabled.

Completion Judgment:
- PASS criteria: app share list equals server share allowlist.
- FAIL criteria: 원본 or duplicate appears in share dialog.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- App share filter works.

Rollback/Compensation:
- Disable share button and keep file open/download only.

### Phase 7. Runtime/PDF/mobile verification
Status: PLANNED

Purpose:
실제 생성물과 앱 화면이 정책대로 바뀌었는지 끝까지 확인한다.

Work:
1. Parser syntax check.
2. Flutter analyze/test.
3. parser service restart and `/health`.
4. 실제 sample fine notice로 문서 생성 2회 실행.
5. 파일 tree 확인:
   - `original/` has originals
   - `share/` has only allowed files
   - 2회 실행 후 duplicate 없음
6. PDF render review:
   - 신청서 no amount
   - 목록 no amount
   - 전화/주민/면허 full output when data exists
   - contract stamped first page only
7. API share package response role list 확인.
8. 모바일 narrow UI check.

Reason:
이번 작업은 파일이 잘못 나가면 바로 실무 사고가 되므로 runtime 확인이 필수다.

Scope:
- In: local parser/app verification.
- Out: 실제 외부 제출.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/**`
- `storage/fine-notices/notices/{date}/{bundleId}`

Scope Lock:
- Modification allowed: bugfixes needed by this PM
- Creation allowed: temporary rendered preview files, then clean up
- Deletion allowed: temporary preview files only
- Read-only references: generated PDF contents
- Excluded targets: original stored docs
- Behaviors not to change: no external submission
- Outputs: verification evidence
- Scope drift criteria: real device deployment/build becomes required

Execution Steps:
1. Run static checks.
2. Restart parser if server code changed.
3. Generate sample twice.
4. Inspect filesystem and API response.
5. Render PDFs and visually inspect.
6. Check compact UI.

Verification:
- Static checks: node/flutter/test.
- Tests: relevant unit/widget tests.
- Harness/smoke: curl generation/list/download.
- Manual review: PDF and UI screenshots.

Completion Evidence:
- Code/doc evidence: final diff.
- Test evidence: command outputs.
- Runtime/DB/external evidence: sample generation and file tree.

Review Gate:
- Reviewer: Codex
- Required checks: all final success conditions.
- Failure handling: fix within current PM scope or stop with exact blocker.

Completion Judgment:
- PASS criteria: all checks pass and no unsafe sharing.
- FAIL criteria: duplicate/share/PII/mobile policy mismatch remains.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all checks pass

Next Phase Entry Criteria:
- All implementation phases completed.

Rollback/Compensation:
- Revert last implementation chunk; keep original files untouched.

### Final Phase. Completion Judgment / Documentation Cleanup / Commit
Status: PLANNED

Purpose:
작업 완료 여부를 판정하고 문서/커밋을 정리한다.

Work:
- Review all phase outputs.
- Update this PM status or create completed report.
- Confirm no raw PII appears in docs, logs, commit message.
- Confirm git status only contains intended files.
- Commit if checks pass.

Reason:
문서 생성/공유는 실무 위험이 크므로 완료판정을 따로 한다.

Scope Lock:
- Modification allowed: this PM, completed report, intended implementation files
- Creation allowed: completed doc
- Deletion allowed: temporary preview files only
- Read-only references: git diff/status/log
- Excluded targets: unrelated dirty files
- Behaviors not to change: external submission remains disabled
- Outputs: commit and completion report
- Scope drift criteria: unrelated dirty files must be included to commit

Verification:
- Review evidence: phase completion checklist.
- Test/build/harness evidence: node/flutter/smoke/PDF/UI.
- Documentation evidence: PM/completed doc.
- Git status evidence: staged files match scope.

Completion Judgment:
- PASS criteria:
  - `original/` and `share/` policy implemented.
  - share package contains only allowed docs.
  - no amount in share docs/main list.
  - phone/resident/license full values supported in DB/PDF.
  - duplicate generation guarded.
  - mobile list fits core fields.
  - checks pass.
- FAIL criteria:
  - original files can be shared.
  - duplicate files appear after repeated generation.
  - required PII is masked/dropped in generated submission PDF.
  - raw PII is written to PM/completion/commit text.

Commit Gate:
- Stage scope:
  - `reservation_ai_parser/src/server.js`
  - `lib/features/fines/**`
  - `test/**` relevant to fine notice
  - `docs/PHASE/...` and completion doc
- Commit message:
  - `feat: harden fine notice share packages`
- Commit only after:
  - all PASS criteria are met.

Rollback/Compensation:
- Use git revert for code commit if needed.
- Keep `original/` files untouched.
- If share flow is unsafe, disable share button until fixed.

### Final Completion Report
- Completed phases: 1-7 and Final
- Commits: See completion report
- Verification summary:
  - `node --check reservation_ai_parser/src/server.js`
  - `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
  - `flutter test test/fine_notice_models_test.dart`
  - parser `/health` smoke
  - sample document generation run twice
  - share package API role/folder-kind check
  - PDF render review for application/list/contract
- Residual risks:
  - 개인정보 원문은 제출에는 필요하지만 운영 접근통제/로그 정책은 계속 조심해야 한다.
  - 기존 중복 파일 정리는 별도 승인 없이는 자동 삭제하지 않는다.
  - 실제 기관별 양식에서 주민번호/면허번호 중 어떤 필드를 요구하는지는 기관별 후속 정책이 필요할 수 있다.
- Follow-up work:
  - 기존 폴더 중복 정리 PM
  - 기관별 제출 양식 템플릿 분리
  - 실제 기기 APK smoke 및 배포
