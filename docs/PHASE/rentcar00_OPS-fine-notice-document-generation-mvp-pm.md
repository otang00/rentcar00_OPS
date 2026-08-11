# rentcar00_OPS Fine Notice Document Generation MVP PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료 실전 MVP 문서생성
- Related docs:
  - `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
- Current status: Storage root corrected / document generator runtime smoke verified
- Approval scope: `pa all` 승인으로 next operational PM Phase 0-4 및 storage-root correction micro PM 진행 완료. `not_our_vehicle` remote migration 적용, parser restart/public smoke, 실제 강남순환도로 fine notice 1건 `contract_original.pdf` 저장 smoke 완료, 문서생성 schema migration 적용, generator smoke 완료. 문서24/fax/site live submission은 여전히 금지.
- Archive target: `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_document_generation_mvp_pm.md`

## 0. Goal Lock
- Objective: 과태료 원장 확정 후 계약서 PDF와 신청/통보 문서를 생성해 manual-ready 제출 패키지로 만드는 실전 MVP를 구현한다.
- Final success condition:
  - 일반계약/보험계약/파트너일반 계약 source에서 문서 생성에 필요한 계약자 정보를 확보한다.
  - 계약자명, 주민번호 또는 면허번호, 실제 주소, 전화번호를 DB에 구조화 저장한다.
  - 계약서 PDF 저장 시점에 계약자 스냅샷이 함께 보강된다.
  - 계약서 PDF는 제출 패키지 기준 첫 페이지만 저장/사용한다.
  - 계약서 첫 페이지에는 원본대조필 도장 이미지와 빵빵카 회사 인장 이미지가 반영된 `contract_with_stamps` 산출물이 생성 또는 첨부된다.
  - 최종 신청서/통보서 상단 회사명 칸에도 회사 인감 도장 이미지가 들어간다.
  - 경찰/교통 과태료 공문은 `문서번호=임의 생성`, `시행일자=발행일` 기준으로 생성된다.
- Explicit non-goals:
  - 실제 문서24/fax/email/site 제출
  - 기관별 모든 양식 완성
  - 도장 이미지를 새로 제작
  - 법령 문구 최종 법률 검토
  - IMS 계약서 대량 다운로드
- Protected targets:
  - Supabase production DB
  - IMS live APIs
  - Mac mini SSD `storage/fine-notices`
  - 회사 인감/도장 이미지 파일
  - 계약자 주민번호/면허번호/주소/전화번호
- Approval required for:
  - DB migration
  - IMS live probe or additional detail API call
  - PDF/문서 생성 코드 변경
  - 도장 이미지 파일 등록/교체
  - external live submission
  - commit/push

## 1. Current State Evidence
- Existing app/backend:
  - 과태료 원장은 `rc00_ops_fine_notices`에 저장된다.
  - 현재 계약자 정보는 `renter_snapshot_json`에만 저장된다.
  - 현재 구조화 컬럼은 `confirmed_contract_source_type`, `ims_contract_id`, `ims_claim_id`, `renter_snapshot_json`, `contract_confirmed_at` 정도다.
  - 계약서 PDF 저장 endpoint는 `/fine-notices/save-contract-pdf`이고, `contract_original` file role로 저장한다.
  - 현재 PDF 저장은 `ims_normal_contract`와 `ims_insurance_claim`만 지원한다.
  - 2026-06-19 runtime smoke:
    - source notice: `toll_fee.gangnam_sunhwan`
    - car number: `142호5684`
    - row count: 2
    - created fine notice ids:
      - `5ec6b200-d553-443c-85f6-03ba1e99b738`
      - `01747ecf-d9f7-4764-bc75-239532b4f639`
    - IMS normal contract candidate count: 1
    - `contract_original.pdf` saved for `5ec6b200-d553-443c-85f6-03ba1e99b738`
    - saved file is a 2-page PDF, file role `contract_original`
    - 민감정보 raw values were not written to docs.
- IMS source 확인:
  - 과태료 계약검색 조회: `POST /ims/search-fine-notice-contracts`.
  - 일반계약 source: 전용 endpoint 내부에서 `GET /v2/normal-contracts/group` 조회.
  - 기존 `POST /ims/search-reservations`는 예약 가져오기 전용이며 과태료 계약검색에 사용하지 않는다.
  - 파트너일반 단서: 기존 예약 import 쪽 `fetchImsPartnerRentRequestDetail()`가 `GET /v2/rent-requests/{requestId}`를 호출하지만, 과태료 문서생성에서는 별도 source type 필요 여부가 아직 미확정이다.
  - 보험계약 source: 전용 endpoint 내부에서 `GET /v2/rencar-claims` 조회.
  - 계약서 PDF:
    - 일반계약: `GET /normal_contract/get_contract_pdf_from_list/{contractId}`
    - 보험계약: `GET /v2/rencar-claims/{claimId}/contracts/pdf`
  - 일반계약 PDF id:
    - `/v2/normal-contracts/group`의 `contractList[].id` 또는 `details[].normal_contract_id`가 PDF용 id다.
    - `details[].id`는 PDF endpoint에 직접 넣으면 실패할 수 있다.
- Current data gap:
  - 일반계약 후보에는 이름/전화/생년월일/대여장소/반납장소 정도가 내려온다.
  - 보험계약 후보에는 이름/전화/고객주소 후보가 있다.
  - 주민번호/면허번호/실주소는 현재 Flutter 모델과 DB 컬럼에 구조화되어 있지 않다.
  - 파트너일반을 별도 source type으로 분리할지 아직 미확정이다.
- Existing file roles:
  - `notice_original`
  - `contract_original`
  - `contract_with_stamps`
  - `renter_change_application`
  - `vehicle_application_list`
  - `submission_bundle_pdf`
  - `submission_receipt`
- Missing file role candidate:
  - 없음. 경찰 공문과 신청서는 같은 명의변경 통보/신청 문서이며 기존 `renter_change_application` role을 사용한다.
  - 제출처에 따라 `수신 - 참조`와 제목/본문 변수만 바뀐다.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| IMS source | normal/insurance만 앱에 표시 | normal/insurance/partner-normal 여부를 검증 | 계약자 정보 위치와 PDF endpoint가 다를 수 있음 |
| Renter info | `renter_snapshot_json` 중심 | 핵심 문서 필드는 컬럼화 + raw json 유지 | 명의변경 통보/신청서 자동 생성 안정성 |
| Address | 없음 또는 pickup/customer address 후보 | `renter_address` 구조화 저장 | 실제 운전자 주소가 제출서류에 필요 |
| Identity | 없음 | 주민번호/면허번호/birth fallback 구분 | 경찰 공문/기관 양식 대응 |
| Contract PDF | 원본 PDF 전체 저장 가능 | 첫 페이지만 저장하고 첫 페이지만 도장 처리 | 제출용 계약서 첫 장만 필요 |
| Application stamp | 미정 | 명의변경 통보/신청서 상단 회사명 칸에 인감 도장 이미지 반영 | 제출양식 요구 대응 |
| Outbound document | 고지서 번호와 혼재 가능 | 발송 공문번호/시행일자 별도 | 문서번호는 임의 생성, 시행일자는 발행일 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Risk | Mitigation |
| --- | --- | --- | --- |
| DB | `rc00_ops_fine_notices`, `rc00_ops_fine_notice_files` | 민감정보 컬럼 추가 | RLS 유지, 최소 컬럼, raw json과 분리 |
| IMS proxy | `reservation_ai_parser/src/server.js` | source별 필드 누락 | read-only probe 후 source별 mapper |
| Flutter model | `FineNoticeCase`, `FineNoticeContractCandidate` | UI/저장 누락 | 테스트로 row mapping 고정 |
| PDF/doc generation | backend document renderer TBD | 도장 위치/크기 오류 | 샘플 PDF render review |
| File storage | Mac mini SSD case folders | 도장/문서 파일 혼재 | file_role과 폴더 규칙 고정 |
| External submission | 문서24/fax/site | live 제출 위험 | manual-ready까지만 구현 |

## 4. Execution Policy
- Approval model:
  - `pa mvp-doc-probe`: IMS source/필드 read-only 확인만. 2026-06-19에 1차 완료됐으며, 새 source가 추가될 때만 다시 사용한다.
  - `pa mvp-doc-runtime-contract-pdf`: 실제 fine notice 원장 1건으로 `contract_original.pdf` 저장 runtime 확인만.
  - `pa mvp-doc-schema`: migration 작성/적용 전 보고. 실제 DB 적용은 별도 승인.
  - `pa mvp-doc-generate`: 문서 생성 코드 구현.
  - `pa mvp-doc-all`은 이 문서에서 금지. increment별 승인만 허용.
- Phase transition rule:
  - IMS source 3종 확인 전 schema 확정 금지.
  - 실제 계약서 원본 PDF 저장 확인 전 stamped contract/application generator 구현 금지.
  - 도장 이미지 파일 위치/권한 확인 전 PDF 생성 구현 금지.
  - DB migration 승인 전 앱 모델 저장 구현 금지.
- Review rule:
  - 생성 문서는 사람이 열어 확인한다.
  - 민감정보 표시 방식은 사장님 확인 전 `UNLOCKED`.
- Commit rule:
  - commit은 별도 승인 후.
- Rollback/compensation:
  - schema migration은 additive only.
  - 문서 생성 실패 시 기존 `contract_original`과 수동 첨부 fallback 유지.
- Stop conditions:
  - 주민번호/면허번호/주소를 IMS에서 안정적으로 못 가져옴.
  - 파트너일반 source가 기존 normal과 식별 불가.
  - 도장 이미지 위치/권한 불명확.
  - live 제출 동작이 필요해지는 경우.

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. IMS Source Probe | 일반/보험/파트너일반별 필요한 정보 확보 가능성 확인 | Codex | read-only API probe/docs | No | No |
| 2. Schema Lock | 계약자 스냅샷/공문번호/batch/file role migration안 확정 | Codex + 사장님 | docs, maybe migration draft | No | Later |
| 3. Stamp Asset Lock | 원본대조필/회사인감 이미지 파일과 위치 규칙 확정 | Codex + 사장님 | local file policy | Yes after Phase 1 | Later |
| 4. Document Template Lock | 명의변경 통보/신청서/차량리스트 변수와 도장 위치 확정 | Codex + 사장님 | docs/templates | Yes after Phase 1 | Later |
| 5. Backend Generator MVP | contract_with_stamps + 명의변경 통보/신청서 PDF 생성 | Codex | code/local files/DB metadata | No | Required |
| 6. App Manual-ready UI | 원장에서 문서 생성/다운로드 상태 표시 | Codex | Flutter code | No | Required |
| 7. Verification Pack | 실제 1건으로 파일 열람/값/도장 위치 검증 | Codex + 사장님 | tests/manual review | No | Required |

## 6. Proposed Schema
### `rc00_ops_fine_notices` additive columns
Migration draft file:
- `supabase/migrations/20260619200000_add_fine_notice_document_generation_fields.sql`

```sql
alter table public.rc00_ops_fine_notices
  add column if not exists source_batch_id uuid,
  add column if not exists source_row_index integer,
  add column if not exists source_row_count integer,
  add column if not exists document_list_group_key text,

  add column if not exists outbound_document_number text,
  add column if not exists outbound_document_issued_date date,

  add column if not exists renter_name text,
  add column if not exists renter_phone text,
  add column if not exists renter_address text,
  add column if not exists renter_identity_type text,
  add column if not exists renter_identity_no text,
  add column if not exists renter_driver_license_no text,
  add column if not exists renter_birth_date text,
  add column if not exists renter_snapshot_source text,
  add column if not exists renter_snapshot_confirmed_at timestamptz,

  add column if not exists contract_pdf_saved_at timestamptz,
  add column if not exists document_package_generated_at timestamptz;
```

Recommended checks:
```sql
alter table public.rc00_ops_fine_notices
  add constraint rc00_ops_fine_notices_renter_identity_type_check
  check (
    renter_identity_type is null
    or renter_identity_type in (
      'resident_registration',
      'driver_license',
      'birth_date_only',
      'unknown'
    )
  );
```

### `rc00_ops_fine_notice_files` role decision
- No new file role is required for 경찰 공문.
- Use existing `renter_change_application` for the unified 명의변경 통보/신청 문서.
- Store the concrete template key in `metadata_json.templateKey`, e.g. `traffic_police_name_change_letter`.

### Optional later table, not MVP
If multiple document packages per one fine notice become necessary:
```text
rc00_ops_fine_notice_document_packages
- id
- fine_notice_id
- package_type
- generated_at
- required_file_roles[]
- status
- metadata_json
```

## 7. IMS Source Probe Requirements
| Source | Current Source Type | Current Endpoint | Need To Confirm | Required Output |
| --- | --- | --- | --- | --- |
| 일반계약 | `ims_normal_contract` | `POST /ims/search-fine-notice-contracts` -> `/v2/normal-contracts/group`, PDF `/normal_contract/get_contract_pdf_from_list/{id}` | 주소/주민번호/면허번호가 detail or PDF에서 가능한지. `details[].id` can fail on PDF. | name, phone, address, identity/license/birth, rental/return |
| 보험계약 | `ims_insurance_claim` | `POST /ims/search-fine-notice-contracts` -> `/v2/rencar-claims`, PDF `/v2/rencar-claims/{id}/contracts/pdf` | 고객주소 외 주민번호/면허번호 가능 여부 | name, phone, address, identity/license/birth, rental/return |
| 파트너일반 | TBD, maybe inside normal | `GET /v2/rent-requests/{requestId}` detail merged into normal search | 별도 source type 필요 여부, PDF endpoint 동일 여부 | same as above plus partner request id |

Probe rule:
- read-only only.
- 1 known case per source is enough for MVP schema decision.
- Do not store real 민감정보 in docs; report field presence only.

## 8. Document Outputs
| File Role | File Name Candidate | Required Inputs | Stamp Requirement |
| --- | --- | --- | --- |
| `contract_original` | `contract/contract_original.pdf` | IMS PDF endpoint | first page only, no stamp |
| `contract_with_stamps` | `contract/contract_with_stamps.pdf` | contract_original first page, 원본대조필 image, company seal image | first page only, 원본대조필 + 회사 인장 |
| `renter_change_application` | `documents/renter_change_application.pdf` | unified name-change notice/application variables | top company name cell has company seal |
| `vehicle_application_list` | `documents/vehicle_application_list.pdf` or `.xlsx` | batch/document list rows | no stamp unless template requires |
| `submission_bundle_pdf` | `submission/submission_bundle.pdf` | ordered profile package | inherit stamped docs |

## 9. Police Letter Policy
- Applies first to `traffic_fine.seoul_seocho_police`.
- Template file: `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`.
- 경찰 공문과 신청서는 separate outputs가 아니다.
- Use one `renter_change_application` output; only `수신 - 참조` and profile variables change.
- Document number:
  - generated internally.
  - candidate format: `FN-{yyyyMMdd}-{seq}` or `{{yy-MM-dd}}-{{seq}}`.
  - final format is user-lock required.
- Issued date:
  - 발행일.
  - default: generation date.
- Required fields:
  - 통지번호
  - 차량번호
  - 위반일시
  - 위반장소
  - 위반내용
  - 위반일시 차량의 계약자
  - 계약자 주민번호 or 면허번호
  - 계약자 전화번호
  - 계약자 실제 주소, if recipient/form needs it

## 10. Stamp Policy
- Required image assets:
  - `stamp_original_true`: 원본대조필 도장 이미지
  - `stamp_company_seal`: 빵빵카 회사 인장 이미지
- Storage recommendation:
  - Mac mini SSD project private path, not public app asset:
    `storage/fine-notices/assets/stamps/`
- Contract output:
  - `contract_original.pdf` role remains; file content is normalized to first page only.
  - `contract_with_stamps.pdf` is generated separately.
- Application output:
  - `renter_change_application.pdf` must place company seal over/near top company-name field as template defines.
- Open lock:
  - exact page/coordinate per document template.
  - stamp size and opacity.
  - whether handwritten/scan fallback is acceptable for MVP.

## 11. Phases
### Phase 1. IMS Source Probe
Status: VERIFIED_NORMAL_PDF_PATH_FIXED (2026-06-19)

Purpose:
Confirm whether 일반/보험/파트너일반 APIs can provide renter name, phone, actual address, resident/license/birth fields.

Scope:
- In:
  - read-only IMS probe
  - field presence report
  - source type decision
- Out:
  - DB write
  - PDF generation
  - mass download

Verification:
- Static checks: none
- Tests: none
- Harness/smoke: one read-only call per source if approved
- Manual review: 사장님 confirms source names

Completion Judgment:
- PASS: source별 first-pass field availability known.
- GAP: partner-normal separation still requires follow-up.

Probe Result:
- `/ims/search-fine-notice-contracts` normal sample:
  - count: 1
  - present: name, phone, pickup/dropoff address candidate, PDF source id candidate
  - absent in candidate response: resident registration number, driver license number
- `/ims/search-fine-notice-contracts` insurance source sample:
  - count: 1
  - present: name, phone, customer address candidate, PDF source id
  - absent in candidate response: resident registration number, driver license number
- normal PDF direct probe:
  - `/normal_contract/get_contract_pdf_from_list/{detailId from reservation import}` returned 403, not a PDF.
  - interpretation: 과태료 문서용 일반계약은 예약 import `detailId`를 그대로 쓰면 안 될 수 있음. `/v2/normal-contracts/group` wrapper or confirmed PDF id path is needed.
- normal PDF path fix:
  - `/v2/normal-contracts/group` read-only probe found matching contract by car/date.
  - `contractList[].id` and `details[].normal_contract_id` both returned PDF 200.
  - `details[].id` returned non-PDF error, so it is not used as PDF source id.
  - `POST /ims/search-fine-notice-contracts` now returns normal candidates with PDF-safe `contractId`.
  - `POST /ims/search-reservations` remains reservation import only.
  - `/fine-notices/save-contract-pdf` now resolves old normal `detailId` rows through `/v2/normal-contracts/group` fallback before downloading PDF.
  - `/fine-notices/save-contract-pdf` uses existing parser/Supabase/storage configuration and does not require a separate internal write password.
- runtime write smoke on a real fine notice row was not executed in this phase because it writes local storage and DB metadata.
- insurance PDF direct probe:
  - PDF status: 200
  - text layer: present
  - detected keywords/patterns: address keyword, driver license keyword, phone keyword, birth keyword, phone pattern
  - not detected: resident registration keyword/pattern
- 민감정보 raw values were not printed or stored in docs.

### Phase 1.5. Contract Original PDF Runtime Smoke
Status: VERIFIED (2026-06-19)

Purpose:
Confirm that a real fine notice row with confirmed IMS contract can save `contract_original.pdf` to the Mac mini storage and `rc00_ops_fine_notice_files`.

Scope:
- In:
  - one existing fine notice row
  - `POST /fine-notices/save-contract-pdf`
  - local file existence check
  - file metadata row check
- Out:
  - stamped PDF generation
  - application/letter generation
  - external submission
  - APK build/upload
  - commit

Verification:
- Static checks: `npm --prefix reservation_ai_parser run check`
- Harness/smoke: one real row save; report only file role/path existence and status, not raw renter sensitive values
- Manual review: 사장님 confirms saved contract PDF is the expected contract

Completion Judgment:
- PASS: `contract_original.pdf` exists under the case folder and file metadata is saved.
- FAIL: IMS id resolves wrong PDF, file is missing, metadata write fails, or wrong renter contract is saved.

Completion Evidence:
- fine_notice_id: `5ec6b200-d553-443c-85f6-03ba1e99b738`
- file role: `contract_original`
- file path: `storage/fine-notices/cases/5ec6b200-d553-443c-85f6-03ba1e99b738/contract/contract_original.pdf`
- file check: previous smoke saved PDF document, version 1.3, 2 pages before first-page-only policy. Current policy requires next save/generation to store 1 page only.
- DB metadata: `rc00_ops_fine_notice_files` row exists with `sourceType=ims_normal_contract`
- storage correction: `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_storage_root_correction_micro_pm.md`

### Phase 1.6. Storage Root Correction and Generator Runtime Smoke
Status: VERIFIED (2026-06-19)

Purpose:
Correct parser runtime storage drift and verify generated fine notice document files are saved under official `storage/fine-notices`.

Scope:
- In:
  - `reservation_ai_parser/.env` storage root key
  - active file bytes for fine notice rows `5ec6b200-d553-443c-85f6-03ba1e99b738` and `01747ecf-d9f7-4764-bc75-239532b4f639`
  - `rc00_ops_fine_notice_files.local_path` correction
  - parser restart
  - one generator smoke for `5ec6b200-d553-443c-85f6-03ba1e99b738`
- Out:
  - live submission
  - app UI integration
  - orphan incoming file deletion

Completion Evidence:
- `npm --prefix reservation_ai_parser run check`: PASS
- parser restart: `ai.otang.reservation-ai-parser` listening on `127.0.0.1:43110`
- parse smoke: new incoming file saved under canonical `storage/fine-notices/incoming/20260619/...`
- DB metadata old drift prefix count: `0`
- stale abnormal metadata deleted: `0` safe deletion candidates
- generated files:
  - `contract_with_stamps`: canonical path, exists, PDF pages=2 before first-page-only policy. Current policy requires regenerated contract PDF and stamped contract to be 1 page.
  - `renter_change_application`: canonical path, exists, PDF pages=1
  - `vehicle_application_list`: canonical path, exists, PDF pages=1

### Phase 2. Schema Lock
Status: DRAFTED (2026-06-19)

Purpose:
Lock DB migration scope for renter snapshot, outbound document number/date, batch fields, and new file role.

Scope:
- In:
  - migration draft `supabase/migrations/20260619200000_add_fine_notice_document_generation_fields.sql`
  - model/repository update plan
- Out:
  - destructive schema changes
  - raw 민감정보 values in docs/logs

Verification:
- Static checks: `git diff --check`
- Tests: migration dry review
- Manual review: 사장님 approves sensitive fields

Completion Judgment:
- PASS: migration can be safely applied.
- FAIL: 민감정보 storage policy unclear.

### Phase 3. Stamp Asset Lock
Status: PLANNED

Purpose:
Lock original-true stamp and company seal image source/path/usage rules.

Scope:
- In:
  - asset file path
  - access/storage rule
  - coordinate review requirement
- Out:
  - generating new seal image

Verification:
- Manual review: image files visible and correct.

Completion Judgment:
- PASS: generator knows which images to use.
- FAIL: stamp assets unavailable.

### Phase 4. Document Template Lock
Status: PLANNED

Purpose:
Lock police letter, application, vehicle list variables and layouts.

Scope:
- In:
  - traffic police letter
  - renter change application first template
  - vehicle/document list fields
- Out:
  - every issuer nationwide

Verification:
- Manual review of rendered sample.

Completion Judgment:
- PASS: one real profile can render without guessing.
- FAIL: template coordinates/required fields unknown.

### Phase 5. Backend Generator MVP
Status: PLANNED

Purpose:
Implement backend document generation for one locked profile.

Scope:
- In:
  - generate stamped contract copy
  - generate name-change letter/application
  - save file metadata
- Out:
  - live submission

Verification:
- Static checks: backend check
- Tests: file role/path guard tests
- Harness/smoke: generate sample for one fine notice

Completion Judgment:
- PASS: files appear in case folder and open correctly.
- FAIL: missing stamps, wrong values, or unsafe paths.

### Phase 6. App Manual-ready UI
Status: PLANNED

Purpose:
Expose document generation/download status in OPS.

Scope:
- In:
  - buttons/status
  - missing field warnings
  - manual fallback
- Out:
  - submit button live send

Verification:
- Static checks: `flutter analyze`
- Tests: `flutter test`

Completion Judgment:
- PASS: user can generate and inspect package.
- FAIL: user can mistake generated package for submitted.

### Phase 7. Verification Pack
Status: PLANNED

Purpose:
Run one real fine notice end-to-end up to manual-ready package.

Scope:
- In:
  - one source profile
  - generated PDF review
  - DB field check
- Out:
  - external send

Verification:
- Manual review: 사장님 opens PDFs and checks stamps/values.

Completion Judgment:
- PASS: manual-ready package accepted for real work.
- FAIL: any required value/stamp/document missing.

## 12. First Executable Increment
Recommended first approval:
```text
pa mvp-doc-runtime-contract-pdf
```

This should only run one real confirmed fine notice through contract original PDF save. It must not generate stamped PDFs, application documents, external submissions, APKs, commits, or unrelated schema changes.
