# rentcar00_OPS Fine Notice Workflow Integrity Correction PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료 실전 MVP workflow integrity correction
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
- Current status: Local Implementation Verified / DB apply and deployment pending
- Approval scope: `pa all` 승인으로 Phase 1-5 로컬 구현/검증/문서 정정까지 완료. PDF 저장용 별도 내부 비밀번호 가드는 제거했다. remote DB apply, parser restart, APK build/upload, commit은 포함하지 않았다.
- Archive target: `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_workflow_integrity_correction_pm.md`

## 0. Goal Lock
- Objective: 과태료 MVP가 정책 문서의 workflow, ownership, permission, status 기준과 어긋난 부분을 정리한다.
- Final success condition:
  - `/ims/search-reservations`는 예약 가져오기 전용 경로로 유지된다.
  - 과태료 계약검색은 전용 endpoint `POST /ims/search-fine-notice-contracts`만 사용한다.
  - 일반계약 후보는 IMS `/v2/normal-contracts/group` 기준으로 찾고, PDF id는 `contractList[].id` 또는 `details[].normal_contract_id`를 사용한다.
  - 보험계약 후보는 IMS `/v2/rencar-claims` 기준으로 찾고, PDF id는 claim id를 사용한다.
  - 앱 과태료 계약검색 client는 예약검색 endpoint를 호출하지 않는다.
  - 기존 예약 가져오기/IMS import 흐름은 동작과 응답 구조가 바뀌지 않는다.
  - `not_our_vehicle` 상태 정책이 앱, DB constraint, 문서에서 일치한다.
  - 계약서 PDF 저장 endpoint는 별도 내부 비밀번호 없이 기존 parser/Supabase/storage 설정으로 사용한다.
  - `ims_contract_id`가 PDF용 contract id인지 detail id인지 흐려지지 않도록 저장 의미를 분리한다.
- Explicit non-goals:
  - 계약자 스냅샷 컬럼 추가
  - 문서 PDF 생성
  - parser 운영 프로세스 restart
  - APK build/upload
  - commit/push
  - 외부 제출 자동화
  - 실제 문서24/fax/site 제출
- Protected targets:
  - 운영 IMS API write endpoints
  - Supabase production DB
  - Mac mini SSD `storage/fine-notices`
  - 기존 예약 가져오기 endpoint `/ims/search-reservations`
  - 회사 인감/도장 이미지
  - 계약자 민감정보 원문
- Approval required for:
  - DB migration remote 적용
  - parser restart
  - 실제 fine notice 원장 PDF 저장 runtime test
  - APK build/upload
  - commit/push

## 1. Current State Evidence
- Repo status:
  - 여러 과태료 MVP 관련 파일이 수정/추가된 dirty worktree 상태다.
  - 이 PM은 unrelated dirty changes를 되돌리지 않는다.
- Pre-correction implementation:
  - 잘못 들어간 변경은 `/ims/search-reservations`에 과태료 전용 mode를 추가하고, 그 안에서 `/v2/normal-contracts/group`까지 조회하는 구조였다.
  - 앱 과태료 계약검색 client가 `/ims/search-reservations`로 과태료 전용 mode를 보내고 있었다.
  - 일반계약 candidate source id 우선순위가 `contractId` 우선으로 바뀌어 있다.
  - PDF 저장 fallback은 기존 detail id 확정 원장을 위해 `/v2/normal-contracts/group`에서 PDF id를 다시 찾도록 추가되어 있다.
  - 앱은 비소유/비관리 차량을 `not_our_vehicle` 상태로 저장하려고 한다.
  - 현재 migration의 `rc00_ops_fine_notices.status` check에는 `not_our_vehicle`가 없다.
  - `/fine-notices/save-contract-pdf`는 local file + DB metadata를 쓰는 write endpoint다.
- Existing docs/specs:
  - 사장님 기준: OPS 예약원장 검색은 과태료 계약검색에서 제외하고, IMS 계약서 기반으로 본다.
  - 경찰공문과 신청서는 별도 문서가 아니라 같은 `renter_change_application` 문서이며 `수신 - 참조`만 바뀐다.
  - 비소유/비관리 차량은 계약검색으로 넘어가지 않아야 한다.
- Existing tests/harness:
  - `npm --prefix reservation_ai_parser run check`
  - `flutter analyze`
  - `flutter test test/fine_notice_models_test.dart`
  - local smoke using parser server on a temporary port
  - `git diff --check`
- Known conflicts or drift:
  - `/ims/search-reservations`에 과태료 전용 mode를 넣은 것은 도메인 경계 위반이다.
  - PM 문서 일부가 “과태료 계약검색 후보에 contractId를 붙임”이라고 적어, 전용 endpoint가 아니라 기존 예약검색 보강처럼 보이게 되어 있다.
  - 일반계약 PDF id 확인 결과 자체는 유효하다: `details[].id`는 PDF용 id가 아니고, `contractList[].id` 또는 `details[].normal_contract_id`가 PDF용 id다.
  - `not_our_vehicle`는 정책/앱에는 있지만 DB status constraint에는 없다.
  - `ims_contract_id`는 현재 PDF용 id와 detail id가 섞일 수 있다.
  - PDF 저장 endpoint는 실제 원장 row 기준 runtime smoke가 아직 필요하다.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| 과태료 계약검색 endpoint | `/ims/search-reservations`에 `mode`를 추가해 재사용 | `POST /ims/search-fine-notice-contracts` 전용 endpoint | 예약검색과 과태료 계약검색 도메인 경계 분리 |
| 일반계약 검색 source | 예약 schedule/detail 조회와 normal contract group이 섞임 | `/v2/normal-contracts/group` 기준 | 과태료는 IMS 계약서 원장을 기준으로 확정 |
| 보험계약 검색 source | 기존 `/ims/search-insurance-claims` 호출 | 전용 endpoint 내부에서 `/v2/rencar-claims` 기준 통합 조회 | 앱은 과태료 계약 후보 API 하나만 호출 |
| PDF id | detail id와 contract id가 혼재 | 일반은 `contractId`, 보험은 `claimId`로 분리 | PDF 저장 실패 방지 |
| Non-owned vehicle status | 앱은 `not_our_vehicle`, DB constraint에는 없음 | DB/app/docs 모두 같은 상태값 또는 같은 보류 정책 사용 | 외부/지사 차량 저장 실패 방지 |
| Contract id ownership | `ims_contract_id`가 detail id/PDF id 혼재 가능 | 일반 PDF용 id, detail id, schedule id 의미 분리 | 후속 PDF 저장/스냅샷 생성 혼선 방지 |
| PDF save runtime | 별도 내부 비밀번호 가드로 차단 | 기존 parser/Supabase/storage 설정만으로 저장 시도 | MVP 실사용 흐름 우선 |
| 문서 설명 | 기존 예약검색 보강처럼 설명됨 | 과태료 전용 IMS 계약검색으로 정정 | 작업자 혼동 방지 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Backend endpoint | `reservation_ai_parser/src/server.js` | Medium | 기존 예약 가져오기 regression | `/ims/search-reservations` 동작/응답을 원복하고 smoke |
| Flutter client | `lib/features/fines/data/fine_notice_contract_matching_client.dart` | Low | 과태료 계약검색 호출 실패 | client endpoint를 전용 API로 단일화 |
| Domain model | `lib/features/fines/domain/fine_notice_models.dart` | Low | 일반/보험 source id 혼동 | candidate factory test 고정 |
| Repository/status | `lib/features/fines/data/fine_notice_repository.dart`, `supabase/migrations/*` | Medium | `not_our_vehicle` 저장 실패 | status constraint와 app status를 같은 값으로 맞춤 |
| Tests | `test/fine_notice_models_test.dart` | Low | 기대 source id/status 기준 변경 | 일반은 contractId, 보험은 claimId, 비소유 status 기준으로 test |
| Docs | PM/current/completed docs | Medium | 완료/진행 상태 오기 | 경계 위반 변경을 별도 correction PM으로 표시 |
| Runtime | parser process | Not in scope unless separately approved | restart 시 운영 영향 | 별도 승인 전 restart 금지 |
| DB/files | Supabase, Mac mini SSD storage | High if approved | status migration/write endpoint/file metadata 영향 | DB apply와 runtime write를 별도 gate로 분리 |
| Runtime write | parser PDF save route | Medium | 실제 원장 row 기준 저장 실패 가능 | 실제 원장 1건으로 runtime smoke |

## 4. Execution Policy
- Approval model:
  - `pa workflow-integrity-p1`: endpoint ownership correction만 실행한다.
  - `pa workflow-integrity-p2`: status ownership correction plan/migration draft만 작성한다. remote DB 적용은 별도 승인이다.
  - `pa workflow-integrity-p3`: PDF 저장 route를 MVP 실사용 기준으로 단순화한다. runtime 실제 저장과 restart는 별도 승인이다.
  - `pa workflow-integrity-p4`: read-only/local smoke와 테스트 검증을 실행한다.
  - `pa workflow-integrity-p5`: PM/current/completed 문서를 정정한다.
  - `pa workflow-integrity-all`: Phase 1-5를 모두 실행한다. 단, remote DB apply, parser restart, APK build/upload, commit은 포함하지 않는다.
  - `pa all`: 이 PM 문서가 active인 상태에서는 `pa workflow-integrity-all`과 동일하게 해석한다. 단, remote DB apply, parser restart, APK build/upload, commit은 포함하지 않는다.
  - `pa workflow-integrity-db-apply`: Phase 2 migration을 remote Supabase에 적용한다. 이 문구 없이는 DB apply 금지.
- Phase transition rule:
  - Phase 1 검증 전에는 Phase 4로 넘어가지 않는다.
  - Phase 2는 DB apply 없이 migration draft와 코드/doc policy까지만 가능하다.
  - Phase 3 이후에도 실제 원장 PDF 저장 runtime smoke는 별도 승인 전 하지 않는다.
  - Phase 4 검증 실패 시 문서 정정 전에 원인을 보고한다.
  - 운영 parser restart는 이 PM의 phase에 포함하지 않는다.
- Review rule:
  - `/ims/search-reservations`에 과태료 mode가 남아 있으면 실패다.
  - 앱 과태료 계약검색 client가 `/ims/search-reservations`를 호출하면 실패다.
  - 앱이 저장하려는 status가 DB constraint에 없으면 실패다.
  - PDF 저장 route가 별도 내부 비밀번호를 요구하면 MVP 흐름 실패다.
- Commit rule:
  - commit은 별도 승인 전 금지.
  - commit 시 unrelated dirty files는 stage하지 않는다.
- Rollback/compensation rule:
  - Phase 1 실패 시 해당 phase에서 건드린 코드만 되돌린다.
  - 기존 예약 import 동작이 깨지면 과태료 전용 endpoint 작업보다 예약검색 원복을 우선한다.
  - DB migration draft가 잘못되면 remote apply 없이 migration draft만 수정한다.
  - PDF 저장 route가 추가 운영 설정을 요구하면 제거하고 기존 설정 기준으로 맞춘다.
- Stop conditions:
  - 전용 endpoint 구현이 기존 예약 import를 수정해야만 가능해지는 경우
  - IMS contract group 응답 구조가 추가 확인과 다르게 나오는 경우
  - 실제 DB/file write가 필요한 검증으로 넘어가야 하는 경우
  - parser restart가 필요해지는 경우
  - status 정책이 `not_our_vehicle` 유지인지 `on_hold`+warning 대체인지 결정이 필요한 경우
  - 실제 PDF 저장이 DB/file write를 요구하는 검증으로 넘어가야 하는 경우

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. Endpoint Ownership Correction | 예약검색 endpoint에서 과태료 mode 제거, 과태료 전용 endpoint 생성 | Codex | code | No | No |
| 2. Status Ownership Correction | `not_our_vehicle` 앱/DB/문서 상태 일치 | Codex + 사장님 | code/migration draft/docs, DB apply separate | No | No |
| 3. PDF Save Runtime Unblock | 계약서 PDF 저장 endpoint의 별도 내부 비밀번호 가드 제거 | Codex + 사장님 | code/docs, runtime write separate | No | No |
| 4. Verification | 예약검색/과태료 전용 검색/local tests 검증 | Codex | read/local only | No | No |
| 5. PM Docs Correction | 잘못된 설명을 전용 endpoint/status/permission 기준으로 정정 | Codex | docs | Yes after Phase 4 | No |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| None | None | Not planned | N/A | N/A | 소유권/상태/권한이 같은 workflow를 건드리므로 병렬화하지 않는다 |

## 7. Phases

### Phase 1. Endpoint Ownership Correction
Status: VERIFIED (2026-06-19)

Purpose:
예약 가져오기 endpoint와 과태료 계약검색 endpoint의 역할을 분리한다.

Scope:
- In:
  - `/ims/search-reservations`에서 과태료 전용 mode 제거
  - `/ims/search-reservations` 내부 normal-contract group enrichment 제거
  - `POST /ims/search-fine-notice-contracts` 추가
  - 전용 endpoint 내부에서 일반계약 `/v2/normal-contracts/group` 조회
  - 전용 endpoint 내부에서 보험계약 `/v2/rencar-claims` 조회
  - 앱 `FineNoticeContractMatchingClient`가 새 endpoint만 호출하도록 변경
  - 일반계약 candidate는 PDF용 `contractId`를 source id로 사용
- Out:
  - DB migration
  - PDF 저장 runtime write
  - parser restart
  - APK build/upload

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/data/fine_notice_contract_matching_client.dart`
- `lib/features/fines/domain/fine_notice_models.dart`
- `test/fine_notice_models_test.dart`

Execution Steps:
1. `/ims/search-reservations` payload에서 `mode`를 제거한다.
2. `searchImsReservationsForImport()`를 예약 import 전용으로 되돌린다.
3. 과태료 전용 `normalizeFineNoticeContractSearchPayload()`를 만든다.
4. `POST /ims/search-fine-notice-contracts` route를 추가한다.
5. 일반/보험 계약 후보를 전용 endpoint 안에서 통합 반환한다.
6. 앱 client 호출 경로를 새 endpoint로 변경한다.
7. 일반계약 candidate factory의 source id 기준은 전용 endpoint 응답에서만 사용한다.

Verification:
- Static checks:
  - `rg -n "payload\\.mode|/ims/search-reservations" reservation_ai_parser/src/server.js lib/features/fines`
  - `/ims/search-reservations` 관련 함수에 과태료 mode가 남지 않았는지 확인
- Tests:
  - `npm --prefix reservation_ai_parser run check`
  - `dart format ...`
  - `flutter test test/fine_notice_models_test.dart`
- Harness/smoke:
  - Phase 4에서 수행
- Manual review:
  - 사장님이 endpoint 이름과 흐름 확인

Completion Judgment:
- PASS criteria: endpoint 경계가 코드상 분리되고 테스트가 통과한다.
- FAIL criteria: `/ims/search-reservations`가 계속 과태료 전용 mode를 받거나 normal-contract group을 직접 조회한다.

Rollback/Compensation:
Phase 1에서 수정한 파일만 이전 상태로 되돌린다. unrelated dirty files는 건드리지 않는다.

### Phase 2. Status Ownership Correction
Status: MIGRATION_DRAFT_VERIFIED (2026-06-19)

Purpose:
비소유/비관리 차량 상태값을 앱, DB constraint, 문서에서 일치시킨다.

Scope:
- In:
  - `not_our_vehicle`을 별도 status로 유지할지, `on_hold` + warning으로 처리할지 PM 기준 확정
  - app repository/UI status 사용처 정리
  - migration draft 작성
  - status 관련 test 추가/수정
- Out:
  - remote Supabase migration apply
  - 기존 운영 데이터 보정
  - parser restart

Files/Targets:
- `supabase/migrations/*`
- `lib/features/fines/data/fine_notice_repository.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`
- `lib/features/fines/domain/fine_notice_models.dart`
- `test/fine_notice_models_test.dart`
- related docs

Execution Steps:
1. Preferred policy로 `not_our_vehicle`을 공식 status로 확정했다.
2. app status write는 `not_our_vehicle` 유지.
3. migration draft `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql`를 작성했다.
4. remote DB apply는 `pa workflow-integrity-db-apply` 전까지 실행하지 않는다.

Verification:
- Static checks:
  - app에서 쓰는 status와 migration constraint 비교
- Tests:
  - `flutter test test/fine_notice_models_test.dart`
- Harness/smoke:
  - DB write smoke는 remote DB apply 전 금지
- Manual review:
  - 사장님이 비소유 차량 표시/저장 정책 확인

Completion Judgment:
- PASS criteria: status 정책이 앱/DB/docs에서 일치한다.
- FAIL criteria: 앱이 DB constraint 밖의 status를 계속 저장한다.

Rollback/Compensation:
DB apply 전이면 파일만 되돌린다. DB apply 후 rollback은 별도 migration으로 처리한다.

### Phase 3. PDF Save Runtime Unblock
Status: VERIFIED_UNBLOCKED (2026-06-19)

Purpose:
계약서 PDF 저장 endpoint가 MVP에서 별도 내부 비밀번호 없이 바로 저장 시도되도록 단순화한다.

Scope:
- In:
  - `/fine-notices/save-contract-pdf` 별도 내부 비밀번호 가드 제거
  - app PDF 저장 client header 제거
  - env example에서 별도 내부 비밀번호 키 제거
  - runtime smoke 금지 조건 명시
- Out:
  - parser restart
  - 실제 PDF 저장
  - DB/file write smoke

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/data/fine_notice_contract_pdf_client.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`
- related docs

Execution Steps:
1. PDF 저장 endpoint의 별도 내부 비밀번호 검사를 제거했다.
2. 앱 PDF 저장 client가 별도 header 없이 `fineNoticeId`만 보내게 정리했다.
3. env example에서 별도 내부 비밀번호 키를 제거했다.
4. parser restart와 실제 원장 저장 smoke는 실행하지 않았다.

Verification:
- Static checks:
  - 별도 내부 비밀번호 키/헤더/가드가 남지 않았는지 확인
- Tests:
  - `npm --prefix reservation_ai_parser run check`
- Harness/smoke:
  - 실제 PDF 저장 smoke는 별도 승인 전 금지
- Manual review:
  - 사장님이 핸드폰 다운로드/공유 workflow와 권한 기준 확인

Completion Judgment:
- PASS criteria: PDF 저장 route가 별도 내부 비밀번호 없이 기존 설정으로 저장 시도한다.
- FAIL criteria: PDF 저장 route가 별도 내부 비밀번호/env/header 때문에 막힌다.

Rollback/Compensation:
파일 변경만 되돌린다. env/runtime은 이 phase에서 건드리지 않는다.

### Phase 4. Verification
Status: VERIFIED (2026-06-19)

Purpose:
예약검색 endpoint가 원래 역할로 돌아왔고, 과태료 전용 계약검색이 read-only로 정상 후보를 반환하는지 확인한다.

Scope:
- In:
  - 임시 local parser server 포트 사용
  - `/ims/search-reservations` smoke
  - `/ims/search-fine-notice-contracts` smoke
  - 일반계약 후보 `contractId` 존재 확인
  - 보험계약 후보 `claimId` 존재 확인
- Out:
  - 운영 parser restart
  - 실제 원장 PDF 저장
  - DB/file write

Verification:
- Static checks:
  - `git diff --check`
- Tests:
  - `flutter analyze`
  - `flutter test test/fine_notice_models_test.dart`
  - `npm --prefix reservation_ai_parser run check`
- Harness/smoke:
  - local `POST /ims/search-reservations`
  - local `POST /ims/search-fine-notice-contracts`
  - local `POST /fine-notices/save-contract-pdf` missing-row smoke
- Manual review:
  - 사장님이 smoke 결과의 endpoint 경계 확인

Completion Judgment:
- PASS criteria: 기존 예약검색과 과태료 전용 계약검색이 각각 독립 smoke를 통과한다.
- FAIL criteria: 둘 중 하나라도 endpoint 역할이 섞이거나 기존 예약검색 응답이 바뀐다.

Rollback/Compensation:
검증 실패 시 code commit 없이 원인 phase 파일만 수정 또는 원복한다.

### Phase 5. PM Docs Correction
Status: VERIFIED (2026-06-19)

Purpose:
PM/current/completed 문서에서 잘못된 설명을 과태료 전용 IMS 계약검색, status, permission 기준으로 정정한다.

Scope:
- In:
  - 문서생성 MVP PM 정정
  - current 문서 정정
  - completed 로그 정정
  - 이 correction PM 상태 업데이트
- Out:
  - 코드 추가 수정
  - 과거 archive 문서 대량 정리

Execution Steps:
1. `/ims/search-reservations` 과태료 mode 표현을 제거한다.
2. `POST /ims/search-fine-notice-contracts` 전용 endpoint 기준으로 설명한다.
3. 일반계약 PDF id 확인 결과는 유지한다.
4. `not_our_vehicle` status policy를 DB/app 기준과 맞춘다.
5. PDF 저장 endpoint는 별도 내부 비밀번호 없이 사용한다고 명시한다.
6. 실제 원장 PDF 저장 runtime은 미실행으로 남긴다.

Verification:
- Static checks:
  - `rg -n "/ims/search-reservations.*과태료|예약검색.*과태료" docs/PHASE docs/GOAL docs/COMPLETED`
  - `git diff --check`
- Tests:
  - Not required for docs-only phase

Completion Judgment:
- PASS criteria: 문서가 전용 endpoint/status/permission 기준으로 일관된다.
- FAIL criteria: 기존 예약검색 endpoint에 과태료 계약검색을 섞는 설명이 남는다.

Rollback/Compensation:
문서 변경만 되돌린다.

### Final Completion Report
- Completed phases:
  - Phase 1 Endpoint Ownership Correction
  - Phase 2 Status Ownership Correction migration draft
  - Phase 3 PDF Save Runtime Unblock
  - Phase 4 Verification
  - Phase 5 PM Docs Correction
- Commits:
  - None
- Verification summary:
  - `npm --prefix reservation_ai_parser run check` passed
  - `flutter test test/fine_notice_models_test.dart` passed
  - `flutter analyze` passed
  - local `/ims/search-reservations` smoke passed: reservation source only, no `contractId`
  - local `/ims/search-fine-notice-contracts` smoke passed: normal contract source with `contractId`
  - PDF 저장용 별도 내부 비밀번호 가드 제거 확인
  - local `/fine-notices/save-contract-pdf` missing-row smoke passed: no password/token blocker, `fine_notice_not_found` reached
- Residual risks:
  - `not_our_vehicle` migration draft는 작성됐지만 remote Supabase에는 아직 적용하지 않았다.
  - parser restart는 아직 하지 않았다.
  - 실제 fine notice 원장 1건 PDF 저장 runtime smoke는 아직 하지 않았다.
  - 보험계약 후보 hit가 있는 샘플 smoke는 추가 확인이 필요하다.
  - parser 운영 프로세스는 재시작하지 않았으므로 운영 반영은 아직 아니다.
- Follow-up work:
  - `pa workflow-integrity-db-apply`로 remote status migration 적용
  - parser restart
  - 실제 원장 1건 PDF 저장 runtime smoke
