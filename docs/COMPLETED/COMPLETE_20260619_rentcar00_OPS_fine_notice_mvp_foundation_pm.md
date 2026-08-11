# 과태료/주정차/통행료 임차인 변경 플로우 PM

## Document Metadata
- Created at: 2026-06-18
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: rentcar00_OPS 과태료 관리 탭 및 임차인 변경 업무 자동화
- Related goal/spec docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/HARNESS/CURRENT_STATE_MAP.md`
  - `docs/HARNESS/CURRENT_UI_API_BOUNDARY_MAP.md`
  - `docs/HARNESS/CURRENT_RUNTIME_LOOP_MAP.md`
- Current status: Completed
- Approval scope: Phase 1-10 MVP foundation 구현과 Supabase migration 적용은 승인·진행됨. Phase 11 이후 문서 생성, 모바일 다운로드/공유, 외부 제출, fax/문서24/사이트 접수는 `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`와 `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md` 기준으로 재정리한다.
- Archive target: archived here as `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`

## 0. Goal Lock
- Objective: 과태료, 주정차 단속, 통행료 고지서를 수동 입력으로 등록하고, 선택적으로 사진 OCR/분석을 보조로 사용한 뒤 계약자 특정 → 계약서/신청서/신청차량리스트 문서 패키지 생성 → fax/문서24/사이트 접수까지 추적하는 OPS 업무 흐름을 만든다.
- Final success condition: OPS 앱 상단에서 `예약 / 일정 / 과태료` 흐름으로 접근 가능하고, 과태료 원장 1건마다 증빙 파일·분석 결과·계약자 확정·서류 생성·정책 기반 제출 채널·제출 상태가 추적된다.
- Explicit non-goals:
  - 제출 채널을 매번 새로 판단하는 임의 분기
  - 승인 없는 IMS live 출력/다운로드/변경
  - Phase 8.1 이후 승인 없는 추가 DB migration 또는 운영 DB 반영
  - 승인 없는 파일 업로드/삭제
  - 고지서 분석 결과만으로 고객을 무근거 확정
  - 임시 호환 레이어 또는 추후 삭제 예정 구조
  - 계약서 원장 완전 통합 전까지 OPS DB만 보고 계약서를 확정하는 구조
- Protected targets:
  - `.env*`, secret, token, credential
  - Supabase production DB, Storage bucket, RLS policy
  - IMS live 계약서/예약 API
  - fax 발송 시스템
  - 문서24 및 기관별 접수 사이트
  - 계약서, 신분정보, 연락처, 과태료 고지서 원본 파일
- Approval required for:
  - DB schema/migration
  - Storage bucket/RLS 생성
  - OCR/AI 분석 API 연동
  - IMS live 계약서 API 사전 테스트 및 실제 호출
  - 문서 생성 템플릿 확정
  - 고지서 기관/유형별 제출 정책 확정
  - fax/문서24/기관 사이트 실제 제출
  - APK build/upload
  - commit/push

## 1. Current State Evidence
- Repo status:
  - branch: `fix/ops-return-complete-end-at`
  - HEAD: `05efdba docs: record b50 APK release`
  - app version/build: `1.0.0+51`
  - 문서 정리 변경이 uncommitted 상태로 존재한다.
- Existing implementation:
  - 현재 상단 업무 레이어: `lib/app/domain/ops_layer.dart`에 `reservations`, `statusBoard`, `fines`가 있다.
  - 현재 상단 UI: `lib/app/view/app_shell.dart`의 `SegmentedButton<OpsLayer>`가 `예약 / 일정 / 과태료` 표시를 제공한다.
  - 현재 일정은 `statusBoard` layer 안에서 독립 segment로 노출된다.
  - 예약 원장/차량/일정 owner: `lib/data/repositories/supabase_ops_repository.dart`
  - 계약자 특정 후보 데이터: IMS 일반계약서 목록과 IMS 보험계약서 목록. OPS 예약/일정 원장은 계약서 검색의 필수 source가 아니다.
  - 과태료 원장 저장 테이블은 `rc00_ops_fine_notices`, 파일 metadata 테이블은 `rc00_ops_fine_notice_files`로 remote Supabase에 적용됐다.
  - 과태료 원장 앱 feature는 `lib/features/fines/`에 있다.
  - 과태료 사진 파서는 `fine_notice_ai_parser/`에 있다.
  - 사진/문서 파일 공식 보관소는 Mac mini SSD `storage/fine-notices`다.
  - 기존 예약 파서는 `reservation-ai-parser` 운영명을 유지한다.
  - 과태료/고지서 파서는 같은 네이밍 규칙으로 `fine-notice-ai-parser`를 기본명으로 둔다.
  - 파서별 책임은 분리하되, 앱에서 호출하는 방식과 응답 schema 규칙은 통일한다.
  - 현재 `pubspec.yaml`에는 `image_picker`가 추가됐다. PDF/document generation 및 share/download 전용 dependency는 아직 별도 phase에서 결정한다.
- Existing docs/specs:
  - `docs/GOAL/rentcar00_OPS-current.md`는 과태료 MVP 진행 상태를 반영해야 한다.
  - `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`는 별도 가격 정책 PM 문서
  - 기존 HARNESS 문서는 예약/상태/IMS/parser 중심이며 과태료 업무 상태는 아직 없다.
- Existing tests/harness:
  - Flutter: `flutter analyze`, `flutter test`
  - Node parser: `npm --prefix reservation_ai_parser run check`
  - Existing tests: `test/ims_reservation_payload_test.dart`, `test/ops_input_formatters_test.dart`, `test/widget_test.dart`
  - 과태료 모델/파일 metadata/계약후보 mapping 테스트: `test/fine_notice_models_test.dart`
  - 과태료 문서 생성, 모바일 다운로드/공유, 제출 플로우 테스트는 아직 없다.
- Known conflicts or drift:
  - 앱에는 과태료 탭과 수동 입력/AI 보조/계약검색 MVP, 계약서 PDF 저장 버튼이 들어갔다. 문서 패키지 생성은 아직 미구현이다.
  - 계약서 PDF 저장은 코드/정적검사 기준 구현 완료이나, 확정 원장 1건의 실제 IMS runtime 저장 확인은 남아 있다.
  - 과태료 업무는 외부 제출이 목적이므로 제출 채널과 필요 서류를 정책으로 먼저 잠가야 한다.
  - 계약서 source of truth는 IMS 일반/보험 계약서 목록으로 둔다. OPS 예약/일정 원장 검색은 계약서 확정의 필수 단계에서 제외한다.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| Navigation | 상단 `예약 / 현황판`, 일정은 현황판 하위 | 상단 `예약 / 일정 / 과태료` 후보 | 과태료 관리가 1급 업무가 됨 |
| Fine workflow | 없음 | 수동 입력 기반 과태료 원장, 사진/AI파서는 선택 보조 | 사진 없이도 업무 진행 가능해야 함 |
| Parsing | 예약 생성용 이미지 파서만 존재 | `reservation-ai-parser`와 같은 규칙의 `fine-notice-ai-parser` 추가 | 이름과 책임 일치 |
| Parser first step | 앱/UI/DB와 섞일 수 있음 | 파서 단독 1차 phase로 분리 | 가장 작은 검증 단위 확보 |
| Model validation | 모델 성능/비용 기준 없음 | 샘플 5장으로 모델별 인식 정확도 검증 | 구현 전 최저모델 선택 |
| OCR model/use | 모델/호출 기준 없음 | 선택 사진 1장 API 호출, 모델/스키마/청구서 유형별 전략 문서화 | 고지서 4~5갈래 형태 대응 |
| Contract matching | 예약 상세에서 수동 확인 | IMS 예약 API 사전검증 후 계약서 확보 | 계약서 원장 미통합 상태 대응 |
| Documents | IMS 계약서/외부 제출 수동 | 케이스별 파일 폴더와 제출 상태 추적 | 증빙 관리와 재처리 |
| Submission | 앱 관리 없음 | 고지서 기관/유형별 제출 정책표 | 채널 선택 자동화 기준 |
| DB implementation timing | Phase 6/8/9 사이에 실제 DB 구현 시점이 흐릿함 | Phase 8.1에서 과태료 원장 DB migration/repository를 실제 구현 | DB 작업이 무기한 보류되지 않도록 계약검색 전 필수 gate로 고정 |
| Manual-first flow | 사진 촬영이 사실상 시작점처럼 읽힘 | `+` 수동 입력만으로 계약검색/문서작성/원장작성 가능 | AI파서는 보조이며 필수 dependency가 아님 |
| Document package | 문서 생성 대상이 추상적임 | 계약서(원본대조필+인감도장 이미지), 임차인 변경 신청서, 신청차량리스트 3종을 기본 패키지로 잠금 | 제출처별 개별/합본 제출에 대응 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| Navigation/UI | `app_shell.dart`, `ops_layer.dart`, route/page 구조 | Phase 1에서 결정 필요 | 기존 현황판 접근성 저하 | 상단 구조와 일정 독립화 먼저 설계 |
| Data model | 새 과태료 원장, 파일, 제출 상태 table 후보 | DB phase 필요 | 데이터/증빙 유실 | schema/storage를 별도 승인 |
| OCR/parser | `fine-notice-ai-parser` 추가 | parser phase 필요 | 유형별 오인식 | 모델/프롬프트/schema/fixture를 유형별로 잠금 |
| Contract matching | OPS 예약/일정 조회 후보 | IMS 일반계약서/보험계약서 목록 직접 조회 | 계약서 source of truth는 IMS | 일반/보험 계약서 API를 둘 다 조회 |
| File storage | 고지서 이미지, IMS 계약서, 신청서, 제출 증빙 | Mac mini SSD 기반 프로젝트 `storage/` 경로 필요 | 파일 분산/유실 | fine_notice_id 원장별 폴더 기준 잠금 |
| Document generation | 임차인 변경 신청서 템플릿, 원본필 처리 산출물 | 템플릿 확정 필요 | 기관별 양식 불일치 | 기관/유형별 템플릿 분리 |
| External submission | fax, 문서24, 기관 사이트 | 정책 phase 필요 | 채널 판단 흔들림 | 사장님 제공 정책표로 채널 결정 |
| Tests/harness | Flutter, parser, DB integration candidates | 매 phase 필요 | 회귀 누락 | phase별 최소 테스트 고정 |

## 4. Execution Policy
- Approval model: 이 문서는 로드맵이다. `pa all` 또는 명시 phase 승인 전 구현하지 않는다.
- Phase transition rule: DB/Storage/외부 제출 관련 phase는 직전 phase의 문서/테스트 기준이 확정된 뒤에만 진행한다.
- Review rule: 실제 업무상 필요한 외부 제출은 전제한다. 다만 채널 선택, 필요 서류, 제출 시점은 정책 문서와 phase gate로 고정한다.
- Commit rule: 각 phase는 검증 후 사장님 승인 시 별도 commit한다. 문서 정리 commit과 코드 commit은 섞지 않는다.
- Rollback/compensation rule: 코드/문서는 commit revert. DB/Storage/외부 제출은 사전 보정 절차가 승인된 경우에만 실행한다.
- Stop conditions:
  - OCR 모델/스키마/청구서 유형이 잠기지 않은 상태에서 구현하려는 경우
  - IMS 일반/보험 계약서 조회와 PDF 확보가 사전 테스트되지 않은 경우
  - 고지서 기관/유형별 제출 정책이 잠기지 않은 상태에서 제출 자동화를 구현하려는 경우
  - IMS/문서24/fax 인증정보 수정 필요
  - DB migration 또는 Storage RLS 정책이 불명확

## 4.1 MVP Workflow Lock

MVP 목적:
수동 입력으로 과태료 원장 초안을 만들고, 사람이 확인/수정한 차량번호와 날짜로 계약서를 찾을 수 있게 한다. AI 파서와 사진은 필수가 아니라 수동 입력을 빠르게 채우는 보조 기능이다.

MVP user flow:
1. OPS 상단에서 `과태료` 탭 진입
2. 과태료 리스트 확인
3. 큰 `+` 버튼으로 수동 입력 모달을 연다.
4. 수동 입력 모달에서 기본 필드를 직접 입력할 수 있다.
5. 사진이 있으면 모달 상단의 `AI파서` 버튼으로 고지서 사진 촬영 또는 업로드를 실행한다.
6. 모달 오른쪽에는 AI파서 연결 상태/재확인 표시를 둔다.
7. AI파서 실행 시 고지서 유형 판정과 프로필별 crop/raw 파싱을 수행하고 수동 입력 필드에 후보값을 채운다.
8. 사람이 필드 확인/수정
9. 차량번호 + 일시/일자 기준 계약서 후보 검색
10. 사람이 계약자/계약서를 확정
11. 계약자/계약서 확정값 기준으로 고지서 원장을 저장/갱신
12. 문서작성 phase에서 계약서, 임차인 변경 신청서, 신청차량리스트를 생성/첨부
13. 고지서 유형별 제출 정책에 따라 필요한 서류와 제출 채널을 확인
14. 실제 제출은 후속 phase에서 처리

MVP included:
- 과태료 탭
- 과태료 리스트
- 예약추가와 유사한 과태료 수동 입력 모달
- 모달 상단 `AI파서` 버튼
- 모달 오른쪽 AI파서 연결 상태 표시
- AI파서 버튼을 통한 사진 등록
- AI raw parsing result
- 수동 필드 수정
- 계약서 후보 검색
- 계약자/계약서 수동 확정
- 사진 없이 수동 입력값만으로 계약서 후보 검색
- 계약자/계약서 확정 후 문서작성 진입
- 고지서별 제출 정책 표시
- 필요서류 체크리스트 표시

MVP excluded:
- AI 결과 자동 보정
- AI 결과만으로 계약자 자동 확정
- 신청서 자동 생성
- IMS 계약서 자동 출력
- fax/문서24/기관 사이트 실제 제출
- 운영 제출 adapter 자동 실행

MVP status candidates:
- `draft`
- `analysis_needed`
- `review_needed`
- `ready_for_contract_search`
- `contract_candidates_found`
- `contract_confirmed`
- `document_package_needed`
- `document_package_ready`
- `submission_policy_needed`
- `documents_needed`
- `submission_ready`
- `on_hold`

Manual-first rules:
- `+` 버튼은 항상 수동 입력 모달을 먼저 연다.
- 사진/AI파서는 optional assist다. 사진이 없어도 저장, 계약서 검색, 계약자 확정, 문서작성으로 진행할 수 있어야 한다.
- AI파서 연결 실패는 업무 중단 사유가 아니다. 수동 입력 모드로 계속 진행한다.
- AI parser output은 `rawCandidate`로 표시한다.
- 사람이 수정한 값은 `confirmedValue`로 분리한다.
- 계약서 검색은 `confirmedValue`가 있으면 그것을 우선 사용한다.
- 계약서 검색은 사진 존재 여부와 무관하게 `confirmedValue.carNumber`와 `confirmedValue.violationAt/passAt` 기준으로 수행한다.
- `rawCandidate`와 `confirmedValue`가 다르면 차이를 표시한다.
- parser가 읽은 값을 앱이 임의 보정하지 않는다.

MVP screen map:
- `FineNoticeListScreen`
  - 과태료 원장 목록
  - 상태 filter
  - 검색: 차량번호, 고지서 번호, 발행기관, 계약자
  - 하단 또는 우하단 큰 `+` 등록 버튼
- `FineNoticeCreateDialog`
  - 예약추가 `_ReservationCreateDialog`와 유사한 수동 입력 모달
  - 기본은 수동 입력이다.
  - title 아래 액션 row 왼쪽에 `AI파서` 버튼을 둔다.
  - title/action row 오른쪽에 AI파서 연결 상태 icon 또는 chip을 둔다.
  - 연결 상태는 `ReservationAiParserClient.checkHealth()`와 같은 패턴으로 `FineNoticeAiParserClient.checkHealth()`를 사용한다.
  - `AI파서` 버튼을 누르면 사진 촬영/업로드 flow를 연다.
  - AI 결과는 필드를 자동 확정하지 않고 수동 입력값 후보로 채운다.
  - `rawCandidate`와 현재 입력값 차이를 warning/보조 텍스트로 보여준다.
  - 필수 필드: 고지서 유형, 발행기관, 차량번호, 위반/통행일시, 금액, 납부기한, 고지서번호, 메모
  - 하단 action: 취소, 저장, 계약검색
  - 사진이 없는 상태에서도 저장/계약검색 가능
- `FineNoticeAiParserImageDialog`
  - 사진 촬영 또는 갤러리 업로드
  - 원본 미리보기
  - 재촬영/사용 버튼
  - parser 실행 후 `FineNoticeCreateDialog`로 결과를 반환
- `FineNoticeContractSearchScreen`
  - confirmed 차량번호 + 일시/일자 기준 계약 후보 검색
  - 후보 예약/계약 카드
  - 후보 없음/수동 검색
  - 계약자/계약서 수동 확정
- `FineNoticeSubmissionChecklistSection`
  - noticeProfile별 제출 채널 표시
  - 필요서류 checklist
  - 양식/template placeholder
  - 실제 제출 버튼은 MVP에서 비활성 또는 미구현 상태

MVP field groups:
- Notice identity:
  - `noticeProfile`
  - `noticeType`
  - `issuer`
  - `documentNumber`
  - `noticeImage`
- Vehicle/date fields:
  - `carNumber`
  - `violationAt` 또는 `passAt`
  - `periodStart`
  - `periodEnd`
  - `dueDate`
- Amount/payment fields:
  - `totalAmount`
  - `baseAmount`
  - `discountAmount`
  - `surchargeAmount`
  - `paymentNumber`
  - `virtualAccount`
- Item fields:
  - `items[].occurredAt`
  - `items[].location`
  - `items[].amount`
  - `items[].surchargeAmount`
  - `items[].contractMatchRequired`
- Review fields:
  - `rawCandidate`
  - `confirmedValue`
  - `warnings`
  - `reviewedBy`
  - `reviewedAt`
- Contract fields:
  - `contractSearchCarNumber`
  - `contractSearchAt`
  - `candidateContracts[]`
  - `candidateContracts[].sourceType`: `ims_normal_contract` 또는 `ims_insurance_claim`
  - `candidateContracts[].imsContractId`
  - `candidateContracts[].imsClaimId`
  - `confirmedContractId`
  - `confirmedContractSourceType`
  - `confirmedRenterSnapshot`
- Document package fields:
  - `documentPackageStatus`
  - `noticeOriginalStatus`
  - `contractWithStampsStatus`
  - `renterChangeApplicationStatus`
  - `vehicleApplicationListStatus`
  - `submissionBundlePdfStatus`
  - `documentFiles[]`
- Submission policy fields:
  - `submissionChannel`
  - `requiredDocuments[]`
  - `formTemplate`
  - `submissionTarget`
  - `submissionPolicyStatus`

MVP state transitions:
- `draft` -> `review_needed`: 수동 입력 모달이 열리고 필드 입력이 시작됨
- `draft` -> `analysis_needed`: 모달에서 AI파서 버튼으로 사진이 등록됐지만 AI 파싱 전
- `analysis_needed` -> `review_needed`: AI raw parsing 결과가 수동 입력 모달에 후보값으로 채워짐
- `review_needed` -> `ready_for_contract_search`: 사람이 필수 필드를 확인/수정함
- `ready_for_contract_search` -> `contract_candidates_found`: 계약 후보가 1건 이상 조회됨
- `ready_for_contract_search` -> `on_hold`: 후보 없음 또는 필수 필드 부족
- `contract_candidates_found` -> `contract_confirmed`: 사람이 계약자/계약서를 확정함
- `contract_confirmed` -> `document_package_needed`: 계약서/신청서/신청차량리스트 작성 또는 첨부 필요
- `document_package_needed` -> `document_package_ready`: 기본 문서 3종이 생성/첨부됨
- `contract_confirmed` -> `submission_policy_needed`: 해당 profile의 제출 정책이 unknown
- `contract_confirmed` -> `documents_needed`: 제출 정책은 있으나 필요서류가 미완성
- `documents_needed` -> `submission_ready`: 필요서류 체크리스트가 충족됨
- any -> `on_hold`: 오인식, 계약 분쟁, 정책 미정, 서류 누락 등으로 보류

MVP navigation decision:
- 상단 1급 탭은 `예약 / 일정 / 과태료`를 목표 구조로 둔다.
- 기존 `현황판`의 차량/일정 기능은 Phase 1 review에서 재배치 확정 전까지 기존 구현을 유지한다.
- 구현 phase에서는 현황판 기능을 삭제하지 않고, 일정 탭 독립화와 현황판 재배치를 별도 UI 변경으로 다룬다.

MVP UI implementation reference:
- 예약추가 진입: `lib/app/view/app_shell.dart`의 `예약추가` `IconButton`
- 예약추가 flow: `showReservationCreateFlow`
- 예약생성 모달: `_ReservationCreateDialog`
- 예약 AI파서 액션 버튼: `_ReservationDialogActionButton(label: 'AI파서')`
- 예약 AI파서 연결 확인 UI: `_AiParserTextInputDialog`의 `checkHealth()` icon 패턴
- 과태료 구현은 같은 UX 패턴을 따르되, 텍스트 원문 입력 대신 사진 촬영/업로드를 AI파서 버튼 뒤에 둔다.

## 4.2 Submission Policy Matrix

고지서 기관/유형별로 제출 방식, 필요서류, 제출양식이 다르므로 정책표를 별도로 둔다.

정책표는 MVP에서 "표시/체크리스트"까지만 사용하고, 실제 발송/접수는 후속 phase에서 구현한다.

Policy dimensions:
- `noticeProfile`: 우면산, 강남순환도로, 남동구청, 서울시/cartax, 경찰/efine 등
- `issuer`: 발행기관
- `noticeType`: `toll_fee`, `parking_violation`, `traffic_fine`
- `submissionChannel`:
  - `file_upload`
  - `document24`
  - `login_site`
  - `fax`
  - `manual_visit_or_unknown`
- `requiredDocuments`:
  - 고지서 원본/사본
  - 임대차/렌트 계약서
  - 원본필 또는 직인 처리 계약서
  - 임차인 변경 신청서
  - 신청차량리스트
  - 제출처가 요구하는 경우 3장 합본 PDF
  - 사업자등록증/위임장/기타 기관 요구서류
  - 제출 증빙/접수증
- `formTemplate`:
  - 기관별 신청서 양식
  - 파일명 규칙
  - 필수 기재 필드
- `submissionTarget`:
  - fax 번호
  - 문서24 수신처
  - 기관 사이트 URL
  - 로그인 계정/권한 필요 여부
- `submissionNotes`:
  - 사장님이 알려주는 기관별 예외/주의사항
  - 제출 가능 시간
  - 중복 제출 주의

Initial policy rows:

| Notice profile | Channel | Required docs | Form/template | Target | Status |
| --- | --- | --- | --- | --- | --- |
| `toll_fee.woomyeonsan` | unknown | unknown | unknown | unknown | 사장님 입력 필요 |
| `toll_fee.gangnam_sunhwan` | unknown | unknown | unknown | unknown | 사장님 입력 필요 |
| `parking.namdong` | unknown | unknown | unknown | unknown | 사장님 입력 필요 |
| `parking.seoul_cartax` | unknown | unknown | unknown | unknown | 사장님 입력 필요 |
| `traffic.police_efine` | unknown | unknown | unknown | unknown | 사장님 입력 필요 |

Policy rules:
- 정책표 없이 제출 채널을 임의 선택하지 않는다.
- 한 기관 안에서도 고지서 종류가 다르면 제출 정책을 분리한다.
- 실제 제출 adapter는 정책표가 확정된 profile부터 순차 구현한다.
- fax/문서24/login site/file upload는 같은 interface를 쓰더라도 channel별 adapter를 분리한다.
- 제출 전에는 사람이 필요서류 체크리스트를 확인해야 한다.

## 4.3 File and Document Package Policy Lock

파일 저장은 Supabase Storage가 아니라 Mac mini SSD를 기준으로 한다. 프로젝트에는 `storage/` 경로가 보이지만 실제 bytes는 SSD에 저장된다.

Storage root:
- Project path: `storage/fine-notices`
- Actual path: `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices`
- Git policy: `storage`는 `.gitignore`에 포함하고 원본/문서 파일을 repository에 넣지 않는다.

Case folder rule:
- 기준 단위는 `fine_notice_id`다.
- 최초 사진 수신 시점에는 계약/차량 정보가 없을 수 있으므로 `incoming/{request_id}`에 먼저 저장한다.
- 원장 생성 후 `cases/{fine_notice_id}` 아래로 연결하거나 이동한다.
- 폴더 표시명에 차량번호/기관/일자를 붙이더라도 DB 연결의 기준은 항상 `fine_notice_id`다.

Locked case folder structure:

```txt
storage/fine-notices/cases/{fine_notice_id}/
  notice/
    notice_original.jpg

  contract/
    contract_original.pdf
    contract_with_stamps.pdf

  forms/
    renter_change_application.pdf
    vehicle_application_list.xlsx
    vehicle_application_list.pdf

  bundle/
    submission_bundle.pdf

  submission/
    submission_receipt.pdf
    submission_result_capture.jpg

  manifest.json
```

Required document package roles:
- `notice_original`: 고지서 원본 사진. 사진이 없으면 원장 생성은 가능하지만 증빙 상태는 `missing`.
- `contract_original`: IMS에서 다운로드한 계약서 원본 PDF.
- `contract_with_stamps`: 계약서. 원본대조필 도장과 인감도장이 찍힌 상태를 이미지/PDF로 보관한다.
- `renter_change_application`: 임차인 변경 신청서.
- `vehicle_application_list`: 신청차량리스트. 엑셀 유사 표 양식으로 생성하거나 첨부한다. 작업용 `xlsx`와 제출용 `pdf`를 둘 다 허용한다.
- `submission_bundle_pdf`: 제출처가 요구하는 경우 계약서/신청서/신청차량리스트를 합친 PDF. 필요 여부와 순서는 profile별 제출 정책에서 잠근다.
- `submission_receipt`: 접수증, 팩스 결과, 문서24 접수증, 사이트 접수 캡처 등 제출 증빙.

Document package rules:
- 문서작성은 사진 존재 여부와 무관하게 계약자/계약서 확정 후 진행 가능해야 한다.
- 기본 제출 패키지는 계약서, 임차인 변경 신청서, 신청차량리스트 3종이다.
- 제출처에 따라 3개 파일을 개별 제출하거나 3장짜리 PDF로 합본 제출한다.
- PDF 합본 필요 여부, 페이지 순서, 파일명, 기관별 양식은 사장님이 알려주는 profile별 정책으로 잠근다.
- 계약서 도장 처리는 `contract_with_stamps` 역할로 저장한다. 도장 방식은 "이미 찍힌 계약서를 촬영/스캔"을 MVP 기준으로 둔다.
- 앱은 DB에 파일 binary를 저장하지 않는다. DB에는 `file_role`, `local_path`, `sha256`, `mime_type`, `size_bytes`, `backup_status`만 저장한다.
- 제출 전 draft 파일은 같은 role로 교체할 수 있다.
- 제출 완료 파일, 접수 증빙, 사장님이 최종확정한 파일은 덮어쓰지 않는다.
- 최종확정 후 재생성 파일은 `_v002`, `_v003` suffix를 붙인다.
- 핸드폰 갤러리는 공식 보관 위치가 아니다. 핸드폰에는 사용자가 다운로드/공유할 때만 임시 저장한다.
- Supabase DB는 파일 보관소가 아니다. 파일 조회/다운로드는 Mac mini HTTPS API를 통해서만 제공한다.

Mobile download and share policy:
- HTTPS entrypoint: `https://parser.00rentcar.com`
- 현재 health 확인: `GET https://parser.00rentcar.com/health` -> 200, `reservation_ai_parser`
- 다운로드 API는 신규 Cloudflare/HTTPS 통로를 만들지 않고 기존 `reservation_ai_parser` 서비스에 추가한다.
- 앱 다운로드 endpoint 형식:
  - `GET /fine-notices/{fine_notice_id}/files/{file_role}/download`
- 서버 동작:
  1. Supabase에서 `fine_notice_id + file_role` metadata를 조회한다.
  2. DB에 등록된 `local_path`만 읽는다.
  3. path traversal 또는 임의 path 입력은 거부한다.
  4. Mac mini SSD 파일을 streaming response로 내려준다.
  5. `Content-Type`, `Content-Length`, `Content-Disposition`을 설정한다.
- 앱 동작:
  1. 사용자가 파일 row에서 `다운로드` 또는 `공유`를 누른다.
  2. 앱 임시 폴더에 파일을 받는다.
  3. OS share sheet를 열어 카톡/메일/파일앱/팩스앱 등으로 넘긴다.
  4. 사용자가 명시적으로 저장하지 않으면 핸드폰을 원본 보관소로 보지 않는다.
- Public URL policy:
  - 영구 공개 링크를 만들지 않는다.
  - 다운로드는 앱 요청 시점에만 처리한다.
  - 권한은 기존 앱 로그인/서버 검증 기준으로 묶는다. 세부 인증 방식은 Phase 12.1에서 구현하며, 미확정이면 live 공개 배포를 막는다.

Mac mini parser file workflow:
1. 앱이 사진을 맥미니 `fine-notice-ai-parser`로 전송한다.
2. parser는 원본을 `incoming/{request_id}/notice_original.*`에 저장한다.
3. parser는 같은 이미지 bytes를 OpenAI API에 보내고 raw parsing JSON을 만든다.
4. 앱은 raw parsing JSON을 수동 입력 후보값으로 보여준다.
5. 사용자가 저장하면 Supabase 원장에는 텍스트/상태/파일 metadata만 저장한다.
6. NAS 백업은 하루 1회 별도 phase에서 `backup-manifests` 기준으로 검증한다.

## 4.4 UNLOCKED Decision Register

아래 항목은 아직 잠기지 않았다. 구현 중 임의로 결정하지 말고, 해당 phase에서 사장님 확인 후 잠근다.

| ID | Area | Status | Warning | Lock phase |
| --- | --- | --- | --- | --- |
| `U-01` | 계약서 확보 방식 | LOCKED | IMS 일반/보험 계약서 PDF를 source type별 endpoint로 받아 `contract/contract_original.pdf`와 `contract_original` file role에 저장한다. 실제 1건 runtime 확인은 남음 | Phase 10 |
| `U-02` | 원본필/도장 처리 | PARTIAL LOCK | 계약서는 원본대조필 도장+인감도장이 찍힌 이미지/PDF로 보관. 자동 합성은 하지 않고 수동 촬영/스캔 첨부를 MVP 기준으로 둔다 | Phase 10 / Phase 12 |
| `U-03` | 임차인 변경 신청서 양식 | PARTIAL LOCK | 임차인 변경 신청서는 기본 문서 3종 중 하나로 필수. 기관별 양식은 미정 | Phase 11 |
| `U-04` | 자동 생성 문서 포맷 | PARTIAL LOCK | 기본 문서 role은 계약서/신청서/신청차량리스트로 잠금. PDF 합본 필요 여부와 양식은 미정 | Phase 11 / Phase 13 |
| `U-05` | 파일 저장 위치 | LOCKED | 고지서 원본/문서 패키지는 프로젝트 `storage/` symlink를 통해 Mac mini SSD에 저장. Supabase Storage와 핸드폰 갤러리는 공식 보관소가 아님 | Phase 8.2 / Phase 12 |
| `U-06` | 파일명/버전 규칙 | PARTIAL LOCK | 기준 folder key는 `fine_notice_id`. 기본 폴더/role/최종파일 version suffix는 잠금. 사람이 읽는 표시명은 미정 | Phase 12 |
| `U-07` | profile별 제출 채널 | UNLOCKED | file upload/document24/login site/fax 중 profile별 채널 미확정 | Phase 13 |
| `U-08` | 제출 실행 자동화 수준 | UNLOCKED | 수동 안내/반자동/자동 제출 범위 미확정 | Phase 14 |
| `U-09` | 제출 증빙 저장 방식 | UNLOCKED | 접수번호, 팩스결과, 사이트 캡처, 문서24 접수증 저장 기준 미확정 | Phase 14 |
| `U-10` | 과태료 원장 DB schema/migration | LOCKED | `rc00_ops_fine_notices`, `rc00_ops_fine_notice_files` migration remote Supabase 적용 완료. 후속 변경은 별도 migration phase 필요 | Phase 8.1 |
| `U-11` | 제출용 PDF 합본 정책 | UNLOCKED | 어느 profile이 3장 합본 PDF를 요구하는지, 페이지 순서/파일명 미확정 | Phase 13 |
| `U-12` | NAS 백업 정책 | UNLOCKED | 백업 대상, 스케줄, 검증 manifest, 실패 알림 기준 미확정 | Phase 12 |
| `U-13` | 모바일 다운로드 권한 | PARTIAL LOCK | HTTPS 통로는 `parser.00rentcar.com`으로 잠금. 다운로드 endpoint/인증/공유 구현은 미구현 | Phase 12.1 |

Unlocked decision rule:
- `UNLOCKED` 항목은 MVP 화면에서 `정책 미정` 또는 `입력 필요`로 표시한다.
- `UNLOCKED` 항목을 코드에서 임의 기본값으로 확정하지 않는다.
- phase gate에서 잠기기 전까지 실제 외부 제출이나 profile별 문서 자동 생성을 진행하지 않는다.
- 고지서 원본과 문서 패키지 파일 저장은 `4.3 File and Document Package Policy Lock` 기준만 사용한다.

## 4.5 Implementation Phase Order From MVP

MVP 구현은 아래 순서로 진행한다.

1. Parser schema/fixture
   - `fine-notice-ai-parser`가 반환할 raw schema와 fixture를 먼저 잠근다.
2. Parser image API
   - 선택 사진 1장 입력과 profile/crop 기반 raw parsing을 붙인다.
3. Fine notice intake UI
   - 과태료 탭, 리스트, `+` 수동 입력 모달, AI파서 버튼, 연결상태 표시를 만든다.
   - 사진 없이도 수동 입력값으로 저장/계약검색이 가능해야 한다.
4. Fine notice persistence implementation
   - Phase 8의 로컬 in-memory 원장을 운영 가능한 DB-backed repository로 전환한다.
   - 사진 없이도 수동 입력 원장이 저장되고 계약검색 시작점이 되는지 먼저 고정한다.
   - 이 단계가 끝나기 전에는 계약검색/문서생성으로 넘어가지 않는다.
5. Parser image save implementation
   - 선택 사진이 있으면 맥미니 parser가 원본 bytes를 SSD `storage/fine-notices/incoming`에 저장한다.
   - DB에는 parser request id, file role, local path, sha256, mime type, size를 연결한다.
6. IMS contract search/confirmation
   - 사람이 확인한 차량번호/일시로 IMS 일반계약서와 보험계약서를 모두 조회하고 수동 확정한다.
   - OPS 예약원장 검색은 이 흐름의 필수 단계에서 제외한다.
7. IMS contract PDF save
   - 확정 source type 기준으로 IMS 일반/보험 계약서 PDF를 받아 `contract_original` role로 저장한다.
   - 원본대조필+인감도장 처리본은 `contract_with_stamps` role의 수동 촬영/스캔 첨부로 유지한다.
8. Document package preparation
   - 계약서, 임차인 변경 신청서, 신청차량리스트 3종을 fine_notice_id 폴더 기준으로 생성/첨부한다.
9. Mobile download/share
   - 생성/첨부된 파일은 Mac mini HTTPS API로 다운로드하고 앱에서 OS share sheet로 공유한다.
   - 핸드폰은 공식 보관 위치가 아니라 사용자 요청 시점의 임시 다운로드 위치다.
10. Submission policy display
   - 정책표에 따라 필요서류/채널을 보여주되, 실제 제출은 하지 않는다.

계약 확정 이후 문서/제출 흐름은 아래 phase에서 별도로 잠근다.

1. Contract document retrieval lock
   - 계약서 파일을 어떻게 확보할지 잠근다.
2. Renter-change document template lock
   - 임차인 변경 신청서 양식과 자동채움 필드를 잠근다.
3. Document package/storage lock
   - 계약서, 신청서, 신청차량리스트, 합본 PDF, 제출증빙을 어디에 어떤 이름으로 저장할지 잠근다.
4. Mobile download/share implementation
   - `parser.00rentcar.com` 기존 HTTPS 통로에 파일 다운로드 API를 붙이고 앱 공유 버튼을 구현한다.
5. Submission policy matrix lock
   - profile별 제출 채널/필요서류/대상/양식을 잠근다.
6. Submission adapter implementation
   - 잠긴 profile부터 fax/document24/login site/file upload adapter를 구현한다.

## 5. Phase Map
| Phase | Purpose | Owner | State Change | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- |
| 1. MVP Workflow and UI Lock | 상단 구조, 수동확인, 계약검색, 제출정책 표시 정의 | 사장님 + Codex | 문서만 | No | Optional docs commit |
| 2. Parser and OCR Policy Lock | `fine-notice-ai-parser` 네이밍/역할/호출 규칙 잠금 | Codex | 문서만 | With submission policy | Optional docs commit |
| 3. Model Validation PM | 샘플 5장으로 최저모델/보정점 검증 | Codex | API call 후보 | No | Optional docs commit |
| 4. Parser Phase 1 Schema and Fixture | 파서 단독 schema/test fixture 구현 | Codex | 코드 변경 있음 | No | Required |
| 5. Parser Phase 2 Image API | 선택 사진 1장 API 호출 구현 | Codex | 코드 변경 있음 | No | Required |
| 6. Data and File Model | 과태료 원장/파일/상태 schema 설계 | Codex | 문서만 | With API probe planning | Optional docs commit |
| 7. IMS Contract API Probe | IMS 예약 정보/계약서 API 사전 테스트 | Codex | API read/probe 후보 | No | Required if executed |
| 8. Manual Intake and Optional OCR Draft | 수동 입력 원장 초안과 선택 AI 사진 보조 흐름 | Codex | 코드/local state | Limited | Required if implemented |
| 8.1 Fine Notice Persistence Implementation | 과태료 원장 DB, repository/save/list 구현 | Codex | DB/code | No | Required before Phase 8.2/9 |
| 8.2 Parser Image Save Implementation | AI 파서 사진 원본 SSD 저장과 file metadata 연결 | Codex | code/local files/DB metadata | No | Required before photo-assisted Phase 9 |
| 9. IMS Contract Matching | IMS 일반계약서/보험계약서 후보 조회와 계약 확정 | Codex | 코드/DB read/write/API read | No | Required |
| 10. IMS Contract PDF Save Implementation | 일반/보험 계약서 PDF 다운로드와 `contract_original` 저장 | Codex | code/local files/API read/DB metadata | No | Required |
| 11. Renter Change Template Lock | 임차인 변경 신청서 양식/필드 잠금 | 사장님 + Codex | 문서만 | With policy draft | Optional docs commit |
| 12. Document Package and Storage Lock | 계약서/신청서/신청차량리스트/합본PDF 저장 정책 잠금 | 사장님 + Codex | 문서/local files 후보 | No | Optional docs commit |
| 12.1 Mobile Download and Share Implementation | Mac mini HTTPS 다운로드 API와 앱 공유 버튼 구현 | Codex | code/API read/local files | No | Required |
| 13. Submission Policy Matrix Lock | profile별 제출 채널/필요서류/대상 잠금 | 사장님 + Codex | 문서만 | With template lock | Optional docs commit |
| 14. Submission Adapter Implementation | 잠긴 profile의 제출 adapter 구현 | Codex | 코드/외부 후보 | Limited | Required |
| 15. Release Readiness | 테스트, 문서, APK/release 판단 | Codex | 문서/빌드 후보 | No | Required before release |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| Notice OCR schema research | Phase 2 | `fine-notice-ai-parser`의 4~5가지 청구서 유형별 JSON schema를 정리하라. | 사장님 설명, 샘플 필드명, 기존 parser 구조 | OCR JSON schema 초안 | 사장님 확인 |
| Model/API strategy | Phase 2 | 선택 사진 1장 API 호출 기준에서 사용할 모델, 프롬프트, confidence, retry, fallback 전략을 정리하라. | OpenAI API 후보, 기존 parser 구조 | 모델/호출 정책 | 구현 phase 승인 |
| Model validation runner | Phase 3 | 제공된 고지서 사진 5장을 최저 비용 vision 가능 모델부터 테스트하고 정답표와 비교하라. 코드/DB 수정 금지. | 샘플 이미지 5장, expected extraction | 모델별 정확도표 | 모델 선택 |
| Parser fixture draft | Phase 4 | 실제 이미지 없이도 고지서 유형별 fixture JSON과 parser contract test를 작성하라. 앱/UI/DB 수정 금지. | Phase 2 schema + Phase 3 결과 | parser fixture/test output | parser review |
| IMS contract API probe plan | Phase 7 | IMS에서 예약 정보 확인 후 계약서 확보가 가능한지 사전 테스트 계획을 작성하라. 실제 호출은 승인 전 금지. | IMS client/server code | API probe checklist | API 테스트 승인 |
| Submission policy draft | Phase 11 | 과태료/주정차/통행료 고지서 기관/유형별 제출 채널 정책표를 작성하라. 사장님 입력 전 unknown으로 둔다. | 사장님 제공 정책 | 제출 정책표 | 사장님 확정 |
| UI flow sketch | Phase 1 | 기존 Flutter 구조를 기준으로 과태료 탭 화면 흐름을 no-write로 설계하라. | `app_shell.dart`, routes | 화면/상태 흐름 | primary review |
| Test plan draft | Phase 2 | OCR, 계약자 매칭, 파일 패키지, 제출 이력 테스트 후보를 작성하라. | PM 문서 | 테스트 계획 | 구현 phase 승인 |

## 7. Phases

### Phase 1. MVP Workflow and UI Lock
Status: VERIFIED

Purpose:
과태료 관리 업무의 앱 진입 구조와 MVP 상태 흐름을 확정한다. MVP는 `+` 버튼으로 수동 입력 모달을 먼저 열고, 모달 안의 AI파서 버튼으로 사진 판독을 보조하는 구조다. AI 자동확정이 아니라 원문 판독 보조, 사람 확인/수정, 계약서 검색, 제출정책 표시까지를 범위로 한다.

Scope:
- In:
  - 상단 탭을 `예약 / 일정 / 과태료`로 바꾸는 기준 검토
  - 기존 `현황판` 기능을 어디에 둘지 결정
  - 과태료 리스트, 대형 `+` 버튼, 수동 입력 모달 시작 흐름 정의
  - 수동 입력 모달 상단 `AI파서` 버튼과 연결 상태 표시 정의
  - 과태료 MVP 상태값 정의: `draft`, `analysis_needed`, `review_needed`, `ready_for_contract_search`, `contract_candidates_found`, `contract_confirmed`, `submission_policy_needed`, `documents_needed`, `submission_ready`, `on_hold`
  - AI raw candidate와 사람이 확인한 confirmed value 분리 기준
  - 제출 정책/필요서류 체크리스트 표시 기준
- Out:
  - 코드 수정
  - DB 변경
  - 실제 사진 촬영/분석 구현
  - 신청서 자동 생성
  - fax/문서24/기관 사이트 실제 제출

Files/Targets:
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
- 참고: `lib/app/view/app_shell.dart`, `lib/app/domain/ops_layer.dart`, `lib/app/router/app_routes.dart`

Execution Steps:
1. `예약 / 일정 / 과태료` 상단 구조를 확정한다.
2. 현재 현황판 차량 기능의 위치를 정한다.
3. 과태료 원장 상태 machine을 문서에 고정한다.
4. raw candidate와 confirmed value의 표시/수정 기준을 정한다.
5. 제출정책표와 필요서류 체크리스트 표시 기준을 정한다.
6. 사용자가 보는 최소 화면 목록을 정한다.

Verification:
- Static checks: 문서 링크와 파일 경로 확인
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님 UI 흐름 승인

Completion Evidence:
- Code/doc evidence:
  - `MVP Workflow Lock`
  - `MVP screen map`
  - `MVP field groups`
  - `MVP state transitions`
  - `Submission Policy Matrix`
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: 상단 탭명, 현황판 재배치, 과태료 MVP 상태값, 수동확인/수정 흐름, 제출정책 표시
- Failure handling: 구현 phase 진입 중단

Completion Judgment:
- PASS criteria: 구현자가 MVP 화면 흐름을 해석 없이 만들 수 있다.
- FAIL criteria: 현황판/일정/과태료 진입 구조가 애매하다.

Phase 1 Result:
- MVP 범위는 `+` 수동 입력 모달 -> 선택적 AI 사진 판독 -> 사람 확인/수정 -> 계약서 검색/확정 -> 제출정책/필요서류 표시까지로 잠근다.
- AI 파서는 원문 판독 보조기이며 자동 보정/자동 확정은 MVP에서 제외한다.
- 제출 채널 실행은 MVP 제외이나, profile별 제출 정책표와 필요서류 체크리스트는 MVP 화면에 표시한다.
- 과태료 등록 UX는 예약추가 모달을 참고해 수동입력을 기본으로 하고, AI파서 버튼과 연결상태를 모달 상단에 둔다.
- 상단 목표 구조는 `예약 / 일정 / 과태료`이며, 기존 현황판 기능은 삭제 없이 재배치 검토 대상으로 둔다.

Commit Gate:
- Stage scope: 승인된 문서 파일만
- Commit message: `docs: lock fine notice workflow`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
UI 흐름과 상태값 승인.

Rollback/Compensation:
문서 변경 revert.

### Phase 2. Parser and OCR Policy Lock
Status: VERIFIED

Purpose:
`reservation-ai-parser`와 네이밍 규칙을 맞춘 `fine-notice-ai-parser`의 역할, 호출 방식, 선택 사진 1장 API 기준을 확정한다.

Scope:
- In:
  - 기존 `reservation-ai-parser` 운영명은 유지
  - 신규 파서명: `fine-notice-ai-parser`
  - 코드 디렉터리 후보: `fine_notice_ai_parser/` 또는 `fine-notice-ai-parser/` 중 repo 규칙에 맞춰 확정
  - API endpoint 후보: `POST /parse-fine-notice`
  - Flutter client 후보명: `FineNoticeAiParserClient`
  - 기존 예약 파서와 요청/응답/error envelope 규칙 통일
  - 선택 사진 1장 API 호출 방식
  - 모델 선택 기준: 구현 직전 OpenAI 공식 문서에서 이미지 입력과 structured output을 지원하는 최신 모델 확인 후 고정
  - 청구서 유형 4~5갈래 분류 기준
  - 유형별 JSON schema, confidence, fallback 규칙
- Out:
  - 기존 `reservation-ai-parser` 리네임
  - 기존 예약 파서 endpoint 변경
  - OCR 결과를 곧바로 계약자 확정값으로 쓰는 구조
  - 코드 구현
  - 실제 API 호출

Files/Targets:
- 문서: 이 PM 문서
- 후보 코드:
  - 신규 `fine_notice_ai_parser/*` 후보
  - 기존 `reservation_ai_parser/*`는 공통 규칙 참고용
  - Flutter 신규 client 후보
- 참고: OpenAI Responses API / Images and vision / Structured output official docs

Execution Steps:
1. 고지서 유형 4~5갈래를 사장님 기준으로 정한다.
2. 공통 추출 필드를 잠근다. 예: 고지서유형, 기관명, 문서번호, 차량번호, 위반일시, 위반장소, 금액, 납부기한, 제출채널 후보.
3. 유형별 추가 필드를 잠근다.
4. 모델 후보와 호출 방식을 문서화한다.
5. parser 결과는 `rawCandidate`, `fieldCrops`, `confidence`, `warnings`, `needsReview`로 나눈다. 앱이 임의 보정한 `normalized_fields`를 확정값처럼 저장하지 않는다.
6. 기존 예약 파서와 충돌하지 않도록 endpoint, client, schema naming을 맞춘다.

Verification:
- Static checks: schema 문서 리뷰
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님이 고지서 유형과 필수 필드 확인

Completion Evidence:
- Code/doc evidence: parser 이름, endpoint, client 이름, 모델 선택 기준, 유형별 schema
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: 파서 이름, endpoint, client 이름, 고지서 유형, 필수 필드, 모델/호출 방식, fallback
- Failure handling: OCR 구현 phase 미진입

Completion Judgment:
- PASS criteria: `reservation-ai-parser`와 통일성 있는 이름으로 과태료 파서 경계가 명확하다.
- FAIL criteria: 모델, schema, 유형 분류 중 하나라도 애매하다.

Commit Gate:
- Stage scope: 승인된 문서 파일만
- Commit message: `docs: lock fine notice parser policy`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
parser/OCR 구현 또는 데이터 모델 설계 승인.

Rollback/Compensation:
문서 revert.

### Phase 3. Model Validation PM
Status: VERIFIED

Purpose:
코드 구현 전, 사장님이 제공한 고지서 사진 5장을 기준으로 최저 비용 vision 가능 모델부터 파싱 정확도를 검증하고 고지서별 보정 규칙을 잠근다.

Scope:
- In:
  - 샘플 5장 정답표 작성
  - 최저 비용 vision 가능 모델 1차 테스트
  - 필요 시 상위 모델 1개 비교
  - 고지서별 템플릿/분기/위치 보완점 정리
  - `items[]` 분리 검증
  - 모델 선택 기준 문서화
- Out:
  - parser 코드 구현
  - 앱/UI/DB 수정
  - IMS/API/제출 기능
  - 대량 이미지 테스트

Sample Set:
- Photo 1: 우면산인프라웨이 유료도로 미납통행료, 단일 item 가능
- Photo 2: 남동구청 주정차위반 과태료, 단일 위반건
- Photo 3: 서울시/용산구 주정차위반 과태료, 단일 위반건
- Photo 4: 서울서초경찰서 교통법규/속도위반 과태료, 단일 위반건
- Photo 5: 강남순환도로 유료도로 미납통행료, 다중 item 필수

Expected Extraction Checklist:
- 공통:
  - `noticeType`
  - `issuer`
  - `recipient`
  - `documentNumber`
  - `carNumber`
  - `issueDate`
  - `dueDate`
  - `totalAmount`
  - `items[]`
  - `payment`
  - `warnings`
- item:
  - `itemIndex`
  - `violationAt` 또는 `passAt`
  - `location`
  - `amount`
  - `surcharge`
  - `reason`
  - `evidenceHint`
  - `contractMatchRequired`

Scoring:
- 차량번호 정확도: required
- 일시 정확도: required
- 금액/총액 정확도: required
- item 분리 정확도: required for toll/multi-item notices
- 발행기관/고지서 유형 정확도: required
- 납부기한/전자납부번호/지로번호: important
- 장소/위반내용: important, low-confidence 허용

Execution Steps:
1. 첨부 5장을 사람이 읽은 expected extraction으로 정리한다.
2. OpenAI 공식 문서에서 현재 image input + structured output 가능 모델 후보를 확인한다.
3. 최저 비용 후보 모델로 5장을 각각 파싱한다.
4. 정답표와 비교해 필드별 성공/실패를 기록한다.
5. 실패 지점을 고지서 유형별 prompt/schema 보정점으로 기록한다.
6. 필요하면 상위 모델 1개로 같은 샘플을 재검증한다.
7. Phase 4 fixture/schema에 반영할 최종 필드와 warnings 규칙을 확정한다.

Verification:
- Static checks: Not in scope
- Tests: Not in scope
- Harness/smoke:
  - 모델별 결과 JSON 저장 또는 문서화
  - Photo 5의 4개 item 분리 여부 확인
- Manual review:
  - 사장님이 모델 선택과 보정점 확인

Completion Evidence:
- Code/doc evidence:
  - 모델별 정확도표, 고지서별 보정점, schema 변경 후보
  - `docs/PHASE/rentcar00_OPS-fine-notice-model-validation-2026-06-18.md`
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: 승인된 OpenAI API 호출 결과만

Review Gate:
- Reviewer: 사장님
- Required checks: 최저 모델 사용 가능 여부, 상위 모델 필요 여부, 고지서별 분기 기준
- Failure handling: 샘플 추가 수집 후 재검증

Completion Judgment:
- PASS criteria: 최저 모델 또는 비교 모델 중 parser 구현에 쓸 기준 모델이 결정된다.
- FAIL criteria: 핵심 필드 또는 다중 item 분리가 불안정하다.

Phase 3 Result:
- `gpt-4.1-nano`: 최저 비용 후보이나 차량번호/일시 오인식이 많아 운영 기준 모델로 부적합.
- `gpt-4.1-mini`: 10회 반복 기준 48/50 sample pass, 8/10 full-run pass. 가장 우수하지만 사장님 기준인 10/10에는 미달.
- `gpt-4.1`: 10회 반복 기준 0/50 sample pass, 0/10 full-run pass. 실운영 기본 모델 부적합.
- `gpt-5-mini`: 10회 반복 기준 29/50 sample pass, 0/10 full-run pass. 실운영 기본 모델 부적합.
- `gpt-4.1-mini` profile-specific field read 재검증: 49/50 sample pass, 9/10 full-run pass. Photo 1 우면산 납기 1회 오독.
- 우면산/강남순환도로 crop repair 재검증:
  - 우면산 납부기한 숫자-only crop + 확대: 원문 판독 보조로 유효
  - 강남순환도로 표 crop + 확대: 원문 판독 보조로 유효
- 운영 기준 변경:
  - AI 파서는 자동 확정기가 아니라 원문 판독 보조기다.
  - 파서는 읽은 값을 임의 보정하지 않고 raw candidate와 confidence/warnings를 반환한다.
  - 최종 확정은 사람이 하며, 수동 입력/수정 후 계약서 검색이 가능해야 한다.
- 결론: 모델 단독/프롬프트 단독으로 10/10 자동확정하는 구조는 채택하지 않는다. Phase 4는 `gpt-4.1-mini` + profile field map + crop parser + warning validator + manual edit/contract search 구조로 재설계 필요.
- 상세 결과: `docs/PHASE/rentcar00_OPS-fine-notice-model-validation-2026-06-18.md`

Commit Gate:
- Stage scope:
  - 모델 검증 문서 또는 PM 문서
  - 샘플 결과 요약 문서
- Commit message: `docs: validate fine notice parsing model`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
모델과 schema 보정점 승인.

Rollback/Compensation:
문서 변경 revert. API 호출 결과는 검증 기록으로만 보관한다.

### Phase 4. Parser Phase 1 Schema and Fixture
Status: VERIFIED

Purpose:
앱/UI/DB와 분리해서 `fine-notice-ai-parser`의 출력 계약과 테스트 fixture를 먼저 만든다.

Scope:
- In:
  - 신규 parser 디렉터리/패키지 초안
  - `fine-notice-ai-parser` package naming
  - `parseFineNoticeInput` core 함수
  - `POST /parse-fine-notice` endpoint skeleton
  - 이미지 API 호출 없이 fixture 기반 normalize/validate test
  - 공통 response envelope
  - 청구서 유형 4~5갈래의 fixture JSON
- Out:
  - Flutter 앱 연동
  - DB 저장
  - 실제 OpenAI API 호출
  - 실제 고지서 이미지 처리
  - IMS/문서 제출 기능

Files/Targets:
- 신규 후보:
  - `fine_notice_ai_parser/package.json`
  - `fine_notice_ai_parser/src/server.js`
  - `fine_notice_ai_parser/src/parser-core.js`
  - `fine_notice_ai_parser/src/fixtures/*.json`
  - `fine_notice_ai_parser/README.md`
- 참고:
  - `reservation_ai_parser/package.json`
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/parser-core.js`

Parser Contract:
- Endpoint: `POST /parse-fine-notice`
- Initial input:
  - `imageBase64`: optional in Phase 4, required in Phase 5
  - `mimeType`: optional
  - `text`: optional fixture/debug input
- Initial output:
  - `ok`
  - `noticeType`
  - `issuer`
  - `documentNumber`
  - `rawCandidate.carNumber`
  - `rawCandidate.violationAt`
  - `rawCandidate.location`
  - `rawCandidate.amount`
  - `rawCandidate.dueDate`
  - `confirmedValue`: 앱/사용자 입력 영역, parser 단독 phase에서는 null
  - `fieldCrops`
  - `paymentAccount`
  - `submissionHint`
  - `rawText`
  - `confidence`
  - `warnings`
  - `meta`

Notice Type Candidates:
- `traffic_fine`
- `parking_violation`
- `toll_fee`
- `local_government_notice`
- `unknown_notice`

Execution Steps:
1. 기존 `reservation-ai-parser`의 package/server/check 구조를 참고한다.
2. `fine_notice_ai_parser` skeleton을 만든다.
3. 실제 이미지 호출 없이 fixture JSON으로 normalize/validate 함수를 만든다.
4. `npm --prefix fine_notice_ai_parser run check` 기준을 만든다.
5. README에 endpoint와 schema를 문서화한다.

Verification:
- Static checks:
  - `node --check fine_notice_ai_parser/src/server.js`
  - `npm --prefix fine_notice_ai_parser run check`
  - `git diff --check`
- Tests:
  - fixture normalize/validate test 또는 `npm --prefix fine_notice_ai_parser run simulate`
- Harness/smoke:
  - `POST /parse-fine-notice` skeleton이 fixture/debug input에 대해 schema shape를 반환
- Manual review:
  - 사장님이 출력 필드가 실제 업무 원장 초안에 충분한지 확인

Completion Evidence:
- Code/doc evidence: 신규 parser skeleton, fixture, README
- Test evidence: node check / npm check / fixture result
- Runtime/DB/external evidence, if applicable: 없음

Review Gate:
- Reviewer: 사장님
- Required checks: 이름, endpoint, output schema, 유형 후보, fixture
- Failure handling: Phase 5 이미지 API 구현 보류

Completion Judgment:
- PASS criteria: 실제 API 호출 없이도 parser contract가 고정된다.
- FAIL criteria: output schema가 앱 원장/후속 매칭에 부족하다.

Phase 4 Result:
- 신규 `fine_notice_ai_parser` skeleton 추가.
- `POST /parse-fine-notice` fixture/debug contract 추가.
- `rawCandidate`, `confirmedValue`, `fieldCrops`, `warnings`, `confidence` 중심 schema 구현.
- 우면산/강남순환도로 fixture 추가.
- 검증:
  - `node --check fine_notice_ai_parser/src/parser-core.js`
  - `node --check fine_notice_ai_parser/src/server.js`
  - `node --check fine_notice_ai_parser/src/simulate.js`
  - `npm --prefix fine_notice_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run simulate`

Commit Gate:
- Stage scope:
  - `fine_notice_ai_parser/*`
  - 관련 PM 문서
- Commit message: `feat: scaffold fine notice ai parser`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
parser contract와 fixture 승인.

Rollback/Compensation:
신규 parser 디렉터리와 문서 변경 revert. 기존 `reservation_ai_parser`는 건드리지 않는다.

### Phase 5. Parser Phase 2 Image API
Status: VERIFIED

Purpose:
선택 사진 1장을 OpenAI vision-capable model에 보내고 `fine-notice-ai-parser` schema로 구조화된 결과를 받는다.

Scope:
- In:
  - `imageBase64` + `mimeType` request 처리
  - OpenAI API 호출
  - model config
  - prompt/schema
  - confidence/warnings/fallback
  - 샘플 이미지 1~3장 smoke
- Out:
  - Flutter 앱 카메라 연동
  - DB 저장
  - 계약자 확정
  - 제출 정책 적용

Files/Targets:
- `fine_notice_ai_parser/src/parser-core.js`
- `fine_notice_ai_parser/src/server.js`
- `fine_notice_ai_parser/.env.example`
- `fine_notice_ai_parser/README.md`
- protected: `.env`, API keys

Execution Steps:
1. 구현 직전 OpenAI 공식 문서에서 이미지 입력과 structured output 지원 모델을 확인한다.
2. `FINE_NOTICE_AI_MODEL` 또는 parser-local model env key를 확정한다.
3. 선택 사진 1장 입력을 data URL 또는 supported image input으로 변환한다.
4. 고지서 유형별 prompt/schema를 적용한다.
5. low-confidence 결과는 `warnings`와 `needsReview`로 넘긴다.

Verification:
- Static checks:
  - `node --check fine_notice_ai_parser/src/server.js`
  - `npm --prefix fine_notice_ai_parser run check`
  - `git diff --check`
- Tests:
  - fixture 유지
  - API call은 승인된 샘플 이미지에서만 smoke
- Harness/smoke:
  - 샘플 이미지 1장 → schema 반환
  - 유형 불명확 이미지 → `unknown_notice` 또는 warnings
- Manual review:
  - 사장님이 실제 고지서 샘플 결과 확인

Completion Evidence:
- Code/doc evidence: image API implementation and README
- Test evidence: check/smoke result
- Runtime/DB/external evidence, if applicable: OpenAI API sample result only

Review Gate:
- Reviewer: 사장님
- Required checks: 모델, 비용/속도, 인식 필드, warnings
- Failure handling: prompt/schema 보정 또는 model 변경

Completion Judgment:
- PASS criteria: 선택 사진 1장으로 수동 입력 보조에 필요한 후보 필드를 안정적으로 반환한다.
- FAIL criteria: 유형/차량번호/일시/금액 중 핵심 필드가 반복적으로 불안정하다.

Phase 5 Result:
- `imageBase64` + `mimeType` request 처리 구현.
- OpenAI image input 호출 경로 구현.
- raw OCR 후보 반환 원칙 유지: parser가 날짜/차량번호를 임의 보정하지 않음.
- `/health`와 `/parse-fine-notice` HTTP smoke 완료.
- 실제 live image API smoke는 기존 Phase 3 샘플 검증 결과를 기준으로 두고, 이번 phase에서는 fixture HTTP smoke만 수행.
- 검증:
  - `curl http://127.0.0.1:43120/health`
  - `curl -X POST /parse-fine-notice` fixture payload

Commit Gate:
- Stage scope:
  - `fine_notice_ai_parser/*`
  - 관련 문서
- Commit message: `feat: parse fine notice image`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
이미지 파서 smoke 통과.

Rollback/Compensation:
Phase 5 commit revert. 기존 `reservation_ai_parser`는 건드리지 않는다.

### Phase 6. Data and File Model
Status: VERIFIED

Purpose:
과태료 원장, 고지서 이미지, 계약서 파일, 신청서, 제출 증빙을 어떤 저장소와 테이블로 관리할지 정한다.

Scope:
- In:
  - 과태료 원장 table 후보
  - 원장 1건당 파일 폴더/버킷 경로 정책
  - 파일 종류: notice_original, notice_processed, ims_contract, stamped_contract, renter_change_application, submission_receipt
  - 예약/계약자 연결 필드 기준
  - 계약서 원장 미통합 상태에서 IMS 계약서 파일을 케이스 폴더에 붙이는 임시 기준
- Out:
  - migration 실행
  - Storage bucket 생성
  - 실제 파일 업로드

Files/Targets:
- 후보 문서: 이 PM 문서 또는 별도 schema PM
- 후보 코드: `supabase/migrations/*`, `lib/data/models/*`, `lib/data/repositories/*`
- Protected: Supabase production DB/Storage

Execution Steps:
1. 원장 필드를 확정한다.
2. 파일 경로 규칙을 확정한다. 예: `fine-cases/{fine_case_id}/...`
3. 제출 업무에 필요한 파일이 빠지지 않도록 파일 종류와 상태를 정의한다.
4. migration 필요 여부와 rollout 방식을 분리한다.

Verification:
- Static checks: schema 문서 리뷰
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 파일 보관 정책 승인

Completion Evidence:
- Code/doc evidence: table/storage 초안
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: 저장 대상, 원장별 폴더, 파일 종류, 보류/실패 정책
- Failure handling: DB phase 미진입

Completion Judgment:
- PASS criteria: migration 작성자가 그대로 구현 가능한 schema가 있다.
- FAIL criteria: 파일 저장 위치나 원장 연결이 애매하다.

Phase 6 Result:
- 이번 `pa 4-8`에서는 운영 DB migration, Supabase Storage bucket, RLS 생성은 실행하지 않았다.
- Phase 8 MVP는 로컬 in-memory state로 제한해 DB/Storage를 건드리지 않는다.
- Phase 6은 실제 DB 작업을 미루는 phase가 아니라 schema/파일 모델을 잠그는 review gate다.
- 실제 과태료 원장 DB 구현은 `Phase 8.1 Fine Notice Persistence Implementation`에서 수행한다.
- `Phase 8.1`은 `Phase 9 Contract Matching` 진입 전 필수 phase다. DB-backed 원장이 없으면 계약자 확정/action log/document package 흐름으로 넘어가지 않는다.
- 원장에 필요한 필드 그룹은 `MVP field groups`로 잠금:
  - notice identity
  - vehicle/date
  - amount/payment
  - items
  - review
  - contract
  - submission policy
- 저장 위치는 project `storage/` symlink -> Mac mini SSD 기준으로 partial lock.
- 파일명/version, 제출 증빙 저장 방식은 `UNLOCKED`로 유지:
  - `U-06`
  - `U-09`
- 과태료 원장 DB schema/migration은 `U-10`으로 추적하고 `Phase 8.1`에서 잠근다.

Commit Gate:
- Stage scope: 승인된 문서 파일만
- Commit message: `docs: design fine notice data model`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Phase 8 UI MVP 검증 후 `Phase 8.1`에서 실제 DB schema/migration/repository 적용 승인.

Rollback/Compensation:
문서 revert.

### Phase 7. IMS Contract API Probe
Status: VERIFIED

Purpose:
계약서 source of truth를 IMS로 두고, 과태료 계약검색에 필요한 일반계약서/보험계약서 조회와 PDF 확보 경로를 사전 테스트한다.

Scope:
- In:
  - 차량번호+날짜 기준 IMS 일반계약서 후보 조회 API 확인
  - 차량번호+날짜 기준 IMS 보험계약서 후보 조회 API 확인
  - 일반/보험 계약서 PDF 다운로드 API 확인
  - 테스트 결과를 원장/문서 패키지 phase 기준으로 반영
- Out:
  - 무승인 실제 계약서 대량 다운로드
  - IMS 데이터 변경
  - 외부 제출

Files/Targets:
- 후보:
  - `reservation_ai_parser/src/server.js`
  - `lib/features/reservations/detail/data/ims_reservation_client.dart`
  - `lib/features/status_board/detail/data/reservation_ai_parser_client.dart`
  - IMS API probe script 후보
- Protected:
  - IMS credential/session
  - 실제 계약서 파일

Execution Steps:
1. 기존 IMS search/import/create/return API 구조를 확인한다.
2. IMS 일반계약서 목록/PDF endpoint를 확인한다.
3. IMS 보험계약서 목록/PDF endpoint를 확인한다.
4. 계약서 파일을 과태료 원장 폴더에 붙이는 기준을 정한다.

Verification:
- Static checks: probe plan review
- Tests: Not in scope before live probe
- Harness/smoke:
  - IMS 일반계약서 목록/PDF read probe
  - IMS 보험계약서 목록/PDF read probe
- Manual review:
  - 사장님이 조회 대상과 계약서 산출물 확인

Completion Evidence:
- Code/doc evidence: IMS 계약서 확보 경로
- Test evidence: API/probe 결과
- Runtime/DB/external evidence, if applicable: 승인된 read/probe 결과만

Review Gate:
- Reviewer: 사장님
- Required checks: 계약서 확보 가능 여부, API 안정성, 실패 시 수동 fallback
- Failure handling: IMS 자동 확보를 보류하고 수동 첨부 기준으로 전환

Completion Judgment:
- PASS criteria: IMS에서 예약 정보와 계약서 산출물을 얻는 절차가 검증된다.
- FAIL criteria: endpoint가 불명확하거나 계약서 확보가 안정적이지 않다.

Phase 7 Result:
- IMS read-only probe로 일반/보험 계약서 API를 확인했다.
- 일반계약서 목록: `GET /v2/normal-contracts/group` 200 확인.
- 일반계약서 PDF: `GET /normal_contract/get_contract_pdf_from_list/{contractId}` `application/pdf` 200 확인.
- 보험계약서 목록: `GET /v2/rencar-claims` 200 확인.
- 보험계약서 PDF: `GET /v2/rencar-claims/{claimId}/contracts/pdf` `application/pdf` 200 확인.
- 계약서 source of truth는 IMS 일반/보험 계약서 목록으로 잠근다. OPS 예약/일정 원장은 계약검색 필수 경로에서 제외한다.
- Phase 8 MVP의 `계약검색` 버튼은 다음 Phase 안내만 표시한다.
- Phase 7은 IMS read/probe 가능성을 확인하는 gate이며, 과태료 원장 저장 자체는 `Phase 8.1`에서 DB-backed로 구현한다.
- `Phase 9` 계약검색은 `Phase 8.1`의 저장 원장을 기준으로 IMS 일반/보험 계약서 후보를 모두 조회한다.
- `Phase 10`은 확정된 source type에 따라 contract PDF를 저장하고, 원본대조필/인감도장 처리본을 별도 role로 받는다.
- 남은 미정:
  - `U-02`: 원본대조필/인감도장 자동 합성 여부
  - `U-11`: 제출처별 3장 합본 PDF 필요 여부

Commit Gate:
- Stage scope: 승인된 probe/docs files only
- Commit message: `docs: verify ims contract retrieval path`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
Phase 8.1 과태료 원장 DB 구현 완료 후, 계약검색에 필요한 IMS read/probe 승인 범위 결정.

Rollback/Compensation:
문서/코드 revert. IMS 조회는 read/probe 기록만 남긴다.

### Phase 8. Manual Intake and Optional OCR Draft
Status: VERIFIED

Purpose:
과태료 탭에서 `+` 버튼으로 수동 입력 모달을 열고, 사진이 있으면 선택적으로 AI파서 버튼을 눌러 후보값을 채운 뒤 과태료 원장 초안을 만든다. 사진이 없어도 수동 입력값으로 저장과 계약검색 진입이 가능해야 한다.

Scope:
- In:
  - 과태료 탭 리스트 UI
  - 대형 `+` 버튼
  - 예약추가와 유사한 수동 입력 모달
  - 모달 상단 `AI파서` 버튼
  - 모달 오른쪽 AI파서 연결 상태 표시
  - AI파서 버튼 뒤의 사진 촬영/선택
  - `fine-notice-ai-parser`에 고지서 사진 분석 요청
  - AI raw candidate를 수동 입력 필드 후보로 반영
  - 사람이 수정 가능한 프로필 원장 화면
  - 사진 없이 수동 입력값만으로 원장 초안 생성
- Out:
  - 계약자 무근거 확정
  - 외부 제출
  - 실제 문서 패키지 생성/외부 제출은 후속 phase 승인 전 제외

Files/Targets:
- 후보:
  - `lib/app/domain/ops_layer.dart`
  - `lib/app/view/app_shell.dart`
  - `lib/app/router/app_routes.dart`
  - `lib/features/fines/*`
  - `lib/data/models/*`
  - `lib/data/repositories/*`
  - 신규 `fine_notice_ai_parser/*` 후보
  - Flutter `FineNoticeAiParserClient` 후보
  - `pubspec.yaml` dependency 후보

Execution Steps:
1. 과태료 feature directory와 route를 만든다.
2. 과태료 리스트와 `+` 버튼을 만든다.
3. `+` 버튼이 `FineNoticeCreateDialog` 수동 입력 모달을 열도록 한다.
4. 모달 상단에 `AI파서` 액션 버튼과 연결 상태 표시를 둔다.
5. camera/image picker dependency 필요성을 확정한다.
6. Phase 2/3의 parser naming/schema/model validation 결과를 구현한다.
7. AI파서 버튼에서 선택 사진 1장을 API로 보내고 raw candidate를 받는다.
8. parser 결과를 확정값이 아니라 수동 입력 후보로 채운다.
9. confidence가 낮은 필드는 `확인 필요`로 둔다.
10. AI파서를 쓰지 않은 경우에도 수동 입력값으로 저장/계약검색이 가능하게 한다.

Verification:
- Static checks:
  - `dart format <changed dart files>`
  - `flutter analyze`
  - `npm --prefix reservation_ai_parser run check` if parser changed
  - `git diff --check`
- Tests:
  - parser OCR mapping unit test 후보
  - Flutter widget test for list/+ flow 후보
- Harness/smoke:
  - `+` 버튼 -> 수동 입력 모달 표시
  - 모달의 AI파서 버튼/연결 상태 표시
  - 샘플 고지서 이미지로 raw candidate가 필드 후보로 채워짐
  - 사진 없이 수동 입력 후 저장 가능
  - 사람이 수정 후 저장 가능
- Manual review:
  - 사장님이 실제 고지서 1건으로 필드 확인

Completion Evidence:
- Code/doc evidence: 과태료 리스트, 수동 입력 모달, AI파서 버튼, 연결 상태 표시, 프로필 초안 경로
- Test evidence: static/test 결과
- Runtime/DB/external evidence, if applicable: 운영 반영 전 없음

Review Gate:
- Reviewer: 사장님
- Required checks: OCR 필드 정확도, 수정 가능성, 저장 전 확인
- Failure handling: OCR schema 보정 후 재검증

Completion Judgment:
- PASS criteria: `+` 버튼으로 수동 입력 모달이 열리고, AI파서 버튼은 선택적으로 사진 판독 후보값을 채우며, 사진 없이도 필드 입력/저장/계약검색 진입이 가능하고 계약자 확정은 다음 phase로 분리된다.
- FAIL criteria: 오인식값이 확정값처럼 저장/표시됨

Phase 8 Result:
- `OpsLayer.fines` 추가.
- `AppShell` 상단 segment에 `과태료` 추가.
- 과태료 레이어에서 상단 `+` 버튼은 `FineNoticeCreateDialog` 수동 입력 모달을 연다.
- 수동 입력 모달 상단에 `AI파서` 버튼과 오른쪽 연결 상태 icon 추가.
- `AI파서` 버튼에서 사진 촬영/갤러리 선택 후 `FineNoticeAiParserClient.parseImage` 호출.
- parser 결과는 확정값이 아니라 입력 후보값으로만 필드에 채운다.
- 과태료 원장 초안은 로컬 in-memory list에 저장한다. DB/Storage write 없음.
- 사진 없이도 수동 입력값으로 원장 초안을 저장할 수 있어야 한다.
- 제출정책은 `정책 미정` placeholder로 표시한다.
- 계약검색은 Phase 9 안내 snackbar만 표시한다.
- 검증:
  - `dart format lib/app/domain/ops_layer.dart lib/app/view/app_shell.dart lib/features/fines`
  - `flutter analyze`
  - `flutter test`

Commit Gate:
- Stage scope: 승인된 feature/parser/test/docs 파일만
- Commit message: `feat: add fine notice intake draft flow`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
고지서 원장 초안 생성 흐름 검증 후 `Phase 8.1` DB persistence 승인.

Rollback/Compensation:
코드 commit revert. DB/Storage 반영이 있다면 별도 승인된 migration rollback 필요.

### Phase 8.1. Fine Notice Persistence Implementation
Status: VERIFIED

Purpose:
Phase 8에서 만든 수동 입력 기반 과태료 원장 초안을 로컬 in-memory 상태에서 실제 DB-backed 원장으로 전환한다. 사진이 없어도 계약검색/계약자 확정/문서 패키지/제출 상태 추적이 한 케이스를 기준으로 이어질 수 있어야 한다.

Scope:
- In:
  - 과태료 원장 DB schema/migration 확정
  - AI raw candidate와 사람이 확인한 confirmed value 분리 저장
  - parser warnings/review flags 저장
  - 고지서 profile/type, issuer, document number, 차량번호, 위반/통행 일시, 금액, 납부기한 저장
  - 계약검색 전 상태값 저장: draft, review_needed, ready_for_contract_search
  - Flutter repository/model/provider를 DB-backed 흐름으로 전환
  - 과태료 리스트 reload/persist 동작 구현
  - action log 최소 구조 후보 확정
  - 사진이 없으면 `notice_original` file role은 `missing` 상태로 두고 원장 저장은 허용
  - 파일 metadata table/field는 만들 수 있으나 실제 image bytes 저장 구현은 Phase 8.2로 분리
- Out:
  - Supabase Storage bucket/RLS 생성
  - 고지서 원본 image bytes 저장
  - AI parser image upload/save endpoint 구현
  - IMS 계약서 파일 저장
  - 임차인 변경 신청서 생성
  - 계약서/신청서/신청차량리스트 자동 생성
  - 외부 제출

Files/Targets:
- 후보:
  - `supabase/migrations/*`
  - `lib/features/fines/domain/*`
  - `lib/features/fines/data/*`
  - `lib/features/fines/shared/*`
  - `lib/data/repositories/*` 또는 별도 fine notice repository
  - `test/*fine_notice*`
- Protected:
  - Supabase production DB
  - Supabase Storage bucket/RLS
  - 실제 고지서 원본 파일

Execution Steps:
1. Phase 6의 field groups를 기준으로 table/column/RLS 초안을 확정한다.
2. migration 파일을 작성한다.
3. fine notice repository의 create/list/update-status API를 구현한다.
4. Phase 8의 in-memory provider를 DB-backed provider/repository로 전환한다.
5. AI raw candidate와 confirmed value가 섞이지 않도록 저장 모델을 검증한다.
6. 저장 후 앱 재진입/목록 재조회로 원장이 유지되는지 확인한다.
7. 사진이 없는 경우에도 fine notice id를 발급하고 `notice_original` 상태를 `missing`으로 표시한다.
8. 계약검색 버튼은 저장된 fine notice id를 기준으로 Phase 9에 넘길 준비만 한다.

Verification:
- Static checks:
  - `dart format <changed dart files>`
  - `flutter analyze`
  - `git diff --check`
- Tests:
  - fine notice model/repository unit test 후보
  - raw candidate와 confirmed value 분리 저장 test
  - status transition test
- Harness/smoke:
  - 과태료 수동 입력 저장
  - 앱/화면 재조회 후 원장 유지 확인
  - AI parser 후보값 저장 후 사람이 수정한 값이 confirmed value로 유지되는지 확인
  - 사진 없이 저장한 원장이 계약검색 준비 상태로 남는지 확인
- Manual review:
  - 사장님이 실제 고지서 1건을 저장하고 목록 재조회 확인

Completion Evidence:
- Code/doc evidence: migration, repository, provider, 저장 UI 연결
- Test evidence: static/test 결과
- Runtime/DB/external evidence, if applicable: 승인된 DB 환경에 적용한 migration 또는 local DB dry-run 결과

Review Gate:
- Reviewer: 사장님
- Required checks: table명/column/RLS/rollback, raw와 confirmed 분리, 저장 후 재조회
- Failure handling: migration 적용 전이면 migration 수정. 적용 후이면 승인된 rollback/보정 migration만 사용.

Completion Judgment:
- PASS criteria: 과태료 원장이 DB에 저장되고 재조회되며, 사진 유무와 관계없이 Phase 9가 저장된 fine notice id를 기준으로 계약검색을 시작할 수 있다.
- FAIL criteria: 과태료 원장이 여전히 in-memory에만 있거나, AI 오인식 후보값과 사람이 확정한 값이 구분되지 않는다.

Commit Gate:
- Stage scope: 승인된 migration/repository/fines feature/test/docs 파일만
- Commit message: `feat: persist fine notice cases`
- Commit only after: DB 적용 범위 승인, 검증 통과, 사장님 commit 승인

Next Phase Entry Criteria:
DB-backed 과태료 원장 저장/목록 재조회 검증 완료. 사진 보조 흐름을 붙일 경우 Phase 8.2를 먼저 진행하고, 사진 없이 수동 계약검색만 진행할 경우 Phase 9로 바로 진입할 수 있다.

Rollback/Compensation:
코드 commit revert. DB migration이 적용된 경우에는 사전에 승인된 rollback/보정 migration만 실행한다. 운영 DB 직접 수동 수정은 별도 승인 없이는 금지한다.

Phase 8.1 Result:
- Implemented in code and applied to remote Supabase DB after explicit approval.
- Added migration file:
  - `supabase/migrations/20260619153000_add_fine_notice_tables.sql`
- Added DB-backed fine notice repository/provider:
  - `lib/features/fines/data/fine_notice_repository.dart`
  - `lib/features/fines/shared/fine_notice_providers.dart`
- Updated manual intake save/list flow to use Supabase repository instead of in-memory state.
- Preserved parser raw output separately in `raw_candidate_json`; human-confirmed values stay in regular fine notice columns.
- Added tests:
  - `test/fine_notice_models_test.dart`
- Verification:
  - `supabase db push --dry-run`: PASS, one pending migration only
  - `supabase db push --yes`: PASS
  - `supabase migration list`: PASS, `20260619153000` present on remote
  - REST read smoke for `rc00_ops_fine_notices`: PASS, 200
  - REST read smoke for `rc00_ops_fine_notice_files`: PASS, 200
  - `flutter analyze`: PASS
  - `flutter test test/fine_notice_models_test.dart`: PASS
  - `flutter test`: PASS
  - `git diff --check`: PASS
- Not executed:
  - Supabase Storage
  - IMS contract search
  - parser image SSD save
  - commit

### Phase 8.2. Parser Image Save Implementation
Status: VERIFIED

Purpose:
AI 파서 버튼으로 선택한 고지서 사진 1장을 맥미니 parser API가 받아 원본 파일을 프로젝트 `storage/` symlink 경유 Mac mini SSD에 저장하고, 과태료 원장에는 파일 metadata와 raw parser 결과만 연결한다. 사진은 보조 입력이며, 사진 저장 실패가 수동 원장 저장 자체를 막지 않아야 한다.

Scope:
- In:
  - parser API image bytes 수신
  - 원본 이미지 저장 루트: `storage/fine-notices/incoming`
  - 실제 저장 위치: `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices/incoming`
  - case 확정 후 연결 루트: `storage/fine-notices/cases/{fine_notice_id}`
  - file metadata 저장: file_role, local_path, sha256, mime_type, size_bytes, parser_request_id, backup_status
  - 파일 role: `notice_original`
  - raw parser result와 file metadata 연결
  - parser 연결상태 표시와 실패 메시지 정리
- Out:
  - Supabase Storage 저장
  - NAS 백업 자동화
  - 계약서 PDF 저장
  - 제출용 문서 생성
  - OCR 값을 자동 확정값으로 덮어쓰기

Files/Targets:
- 후보:
  - `fine_notice_ai_parser/src/server.js`
  - `fine_notice_ai_parser/src/parser-core.js`
  - `fine_notice_ai_parser/README.md`
  - `lib/features/fines/data/fine_notice_ai_parser_client.dart`
  - `lib/features/fines/presentation/fine_notice_page.dart`
  - `lib/features/fines/domain/*`
  - `test/*fine_notice*`
  - `storage/fine-notices/incoming/*` runtime file root
- Protected:
  - 실제 고지서 원본 파일
  - OpenAI API key
  - 운영 DB file metadata

Execution Steps:
1. parser API가 imageBase64/mimeType을 받으면 request id를 생성한다.
2. 원본 bytes의 sha256, size, mime type을 계산한다.
3. 원본을 `storage/fine-notices/incoming/{yyyyMMdd}/{requestId}.{ext}`에 저장한다.
4. OpenAI vision parsing은 저장된 원본 또는 수신 bytes를 기준으로 실행하되, 결과는 rawCandidate로만 반환한다.
5. Flutter는 parser 응답의 file metadata를 fine notice draft에 붙인다.
6. fine notice 저장 시 file metadata를 `notice_original` role로 DB 원장에 연결한다.
7. parser 실패 시 수동 입력 모달은 유지하고, 저장 실패/파싱 실패를 분리해 표시한다.

Verification:
- Static checks:
  - `npm --prefix fine_notice_ai_parser run check`
  - `dart format <changed dart files>`
  - `flutter analyze`
  - `git diff --check`
- Tests:
  - parser file metadata unit/smoke test
  - Flutter parser response mapping test 후보
- Harness/smoke:
  - 사진 1장 선택 후 parser 호출
  - SSD incoming 경로에 원본 저장 확인
  - sha256/size/mime type metadata 확인
  - rawCandidate가 confirmedValue를 자동 덮어쓰지 않는지 확인
  - parser 서버 미연결 상태에서 수동 저장 가능 확인
- Manual review:
  - 사장님이 실제 고지서 1장으로 저장 경로와 화면 표시 확인

Completion Evidence:
- Code/doc evidence: parser 저장 코드, Flutter metadata 연결, README/local storage 기준
- Test evidence: parser check, Flutter analyze/test, smoke 결과
- Runtime/DB/external evidence, if applicable: 승인된 local parser 호출 결과와 SSD 파일 경로

Review Gate:
- Reviewer: 사장님
- Required checks: SSD 저장 위치, file role, raw/confirmed 분리, 사진 없는 수동 저장 유지
- Failure handling: parser 사진 저장만 비활성화하고 수동 원장 저장은 유지한다.

Completion Judgment:
- PASS criteria: 사진 1장이 parser로 전달되고 SSD에 원본이 저장되며, DB 원장에는 `notice_original` metadata와 rawCandidate만 연결된다.
- FAIL criteria: 사진이 Supabase Storage로 올라가거나, parser 후보값이 사람 확정값을 자동 변경하거나, parser 실패가 수동 원장 저장을 막는다.

Commit Gate:
- Stage scope: 승인된 parser/fines feature/test/docs 파일만
- Commit message: `feat: store fine notice parser images locally`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
사진 보조 고지서 원장 저장 검증 완료. 사진 없는 수동 흐름은 Phase 8.1 완료만으로 Phase 9 진입 가능.

Rollback/Compensation:
코드 commit revert. SSD에 생성된 테스트 파일 삭제는 별도 승인 후 수행한다. DB metadata가 생성된 경우 승인된 보정 migration 또는 테스트 데이터 정리 절차만 사용한다.

Phase 8.2 Result:
- Implemented parser-side original image save before OpenAI parsing.
- Storage root resolves to project `storage/fine-notices`; actual bytes follow the project symlink to Mac mini SSD.
- Parser now returns `file` metadata:
  - `fileRole`
  - `requestId`
  - `localPath`
  - `sha256`
  - `mimeType`
  - `sizeBytes`
  - `backupStatus`
- Flutter parser client maps `file` metadata into `FineNoticeFileMetadata`.
- Fine notice save inserts parser file metadata into `rc00_ops_fine_notice_files` as `notice_original`.
- Parser failure still leaves manual input/save flow available.
- Verification:
  - `npm --prefix fine_notice_ai_parser run check`: PASS
  - `npm --prefix fine_notice_ai_parser run simulate`: PASS
  - `npm --prefix fine_notice_ai_parser run file-save-smoke`: PASS
  - `flutter analyze`: PASS
  - `flutter test test/fine_notice_models_test.dart`: PASS
  - `flutter test`: PASS
  - `git diff --check`: PASS
- Not executed:
  - Supabase migration apply
  - 운영 DB write
  - live OpenAI image parse smoke
  - NAS backup
  - commit

### Phase 9. IMS Contract Matching
Status: VERIFIED

Purpose:
Phase 8.1에서 저장된 과태료 원장의 날짜와 차량번호를 기준으로 IMS 일반계약서 목록과 IMS 보험계약서 목록을 모두 조회해 특정 계약자를 확정한다. OPS 예약/일정 원장 검색은 이 phase의 필수 경로에서 제외한다.

Scope:
- In:
  - IMS 일반계약서 후보 조회: `GET /v2/normal-contracts/group`
  - IMS 보험계약서 후보 조회: `GET /v2/rencar-claims`
  - 차량번호 + 위반/통행일시 기준 후보 기간 overlap 판단
  - 일반/보험 source type을 구분한 후보 계약자 카드와 근거 표시
  - 계약자 확정
  - 확정 이력/action log
  - 확정 결과를 저장된 fine notice case에 반영
- Out:
  - OCR 결과만으로 무근거 확정
  - OPS 예약원장만 보고 계약자 확정
  - IMS 계약서 PDF 다운로드/저장
  - 신청서 제출

Files/Targets:
- 후보:
  - `lib/features/fines/*`
  - `reservation_ai_parser/src/server.js`
  - `lib/features/fines/data/*`
  - `lib/features/fines/domain/*`
  - `lib/features/fines/shared/*`

Execution Steps:
1. 저장된 fine notice case id를 기준으로 후보 조회를 시작한다.
2. 일반계약서 목록에서 차량번호/기간 기준 후보를 조회한다.
3. 보험계약서 목록에서 차량번호/기간 기준 후보를 조회한다.
4. 후보를 `ims_normal_contract`와 `ims_insurance_claim`으로 구분해 같은 리스트에 표시한다.
5. 후보 카드에 차량번호, 계약자, 연락처, 계약기간, contractId/claimId, source type, match reason을 표시한다.
6. 사람이 하나를 확정하면 과태료 원장에 source type, contractId 또는 claimId, 계약자 snapshot을 저장한다.

Verification:
- Static checks: `flutter analyze`, `dart format`, `git diff --check`
- Tests:
  - IMS 일반/보험 후보 merge unit test
  - 기간 overlap matching unit test
  - KST boundary test
- Harness/smoke:
  - 일반계약 후보 표시
  - 보험계약 후보 표시
  - 같은 차량 다중 계약 후보 표시
  - 후보 없음 상태 표시
- Manual review:
  - 실제 사례 기준 후보 정확도 확인

Completion Evidence:
- Code/doc evidence: IMS contract matching repository/UI
- Test evidence: matching tests
- Runtime/DB/external evidence, if applicable: 외부 write 없음

Review Gate:
- Reviewer: 사장님
- Required checks: 일반/보험 후보 분리, 확정 근거, 후보 없음 처리
- Failure handling: matching rule 수정 후 재검증

Completion Judgment:
- PASS criteria: 날짜+차량번호로 IMS 일반/보험 계약 후보를 제시하고 사용자가 source type과 계약자를 확정한다.
- FAIL criteria: OPS 예약원장만 보고 고객이 확정되거나, 일반/보험 중 한쪽만 조회하거나, 저장된 fine notice case 없이 임시 화면 상태만으로 계약검색이 진행된다.

Commit Gate:
- Stage scope: 승인된 matching files/tests/docs
- Commit message: `feat: match fine notice to rental contract`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
IMS 일반/보험 계약자 확정 흐름 검증.

Rollback/Compensation:
commit revert. 운영 DB snapshot이 생성된 경우 별도 승인된 정리 필요.

Phase 9 Result:
- Implemented MVP contract matching flow.
- Fine notice card now exposes `계약검색` when car number and notice date exist.
- Contract search calls both IMS read endpoints through `AI_PARSER_BASE_URL`:
  - normal candidates: `POST /ims/search-reservations`
  - insurance candidates: `POST /ims/search-insurance-claims`
- Candidate dialog shows source label, renter, phone, car number, rental/return time, and match reason.
- Human confirmation writes to `rc00_ops_fine_notices`:
  - `status = contract_confirmed`
  - `confirmed_contract_source_type`
  - `ims_contract_id` or `ims_claim_id`
  - `renter_snapshot_json`
  - `contract_confirmed_at`
- Confirmation also writes an action log using existing `rc00_ops_action_logs` with `target_type = fine_notice`.
- Added code:
  - `lib/features/fines/data/fine_notice_contract_matching_client.dart`
- Updated code:
  - `lib/features/fines/domain/fine_notice_models.dart`
  - `lib/features/fines/data/fine_notice_repository.dart`
  - `lib/features/fines/presentation/fine_notice_page.dart`
  - `test/fine_notice_models_test.dart`
- Verification:
  - `flutter analyze`: PASS
  - `flutter test test/fine_notice_models_test.dart`: PASS
  - `flutter test`: PASS
  - `git diff --check`: PASS
- Important caveat:
  - MVP uses existing IMS proxy import endpoints, not a newly added direct `/v2/normal-contracts/group` wrapper.
  - Phase 10 must verify that the selected `detailId`/`claimId` maps directly to the PDF download endpoints before contract PDF storage is finalized.
- Not executed:
  - live IMS search smoke from the app UI
  - IMS PDF download
  - document generation
  - external submission
  - commit

### Phase 10. IMS Contract PDF Save Implementation
Status: VERIFIED

Purpose:
IMS 일반/보험 계약 후보가 확정된 뒤 제출 패키지에 들어갈 계약서 원본 PDF를 source type별 endpoint로 다운로드하고, `contract_original` file role로 fine notice case 폴더에 저장한다. 원본대조필 도장+인감도장이 찍힌 `contract_with_stamps` 산출물은 이 phase에서 자동 생성하지 않고 수동 촬영/스캔 첨부 상태로 남긴다.

Scope:
- In:
  - IMS 일반계약서 PDF 다운로드: `GET /normal_contract/get_contract_pdf_from_list/{contractId}`
  - IMS 보험계약서 PDF 다운로드: `GET /v2/rencar-claims/{claimId}/contracts/pdf`
  - `contract_original` 저장 구현
  - 저장 위치: `storage/fine-notices/cases/{fine_notice_id}/contract/contract_original.pdf`
  - file metadata 저장: file_role, local_path, sha256, mime_type, size_bytes, source_type, ims_contract_id 또는 ims_claim_id
  - 수동 첨부 fallback 기준
  - 계약서 원본, 출력본, 원본대조필+인감도장 처리본 상태 구분
  - MVP 기준: 도장 처리된 계약서를 촬영/스캔해서 `contract_with_stamps`로 보관
  - `U-01`, `U-02` decision lock
- Out:
  - 무승인 IMS live 계약서 대량 다운로드
  - 전자도장 자동 합성
  - 원본대조필/인감도장 자동 생성
  - 임차인 변경 신청서 생성
  - 제출용 PDF 합본 생성

Files/Targets:
- 구현:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/parser-core.js`
  - `lib/features/fines/data/fine_notice_contract_pdf_client.dart`
  - `lib/features/fines/presentation/fine_notice_page.dart`
  - `storage/fine-notices/cases/*` runtime file root
- 참고:
  - `lib/features/reservations/detail/data/ims_reservation_client.dart`
  - `reservation_ai_parser/src/server.js`
- Protected:
  - IMS credential/session
  - 실제 계약서 파일

Execution Steps:
1. 저장된 fine notice case의 확정 source type과 IMS id를 읽는다.
2. `ims_normal_contract`이면 일반계약서 PDF endpoint를 호출한다.
3. `ims_insurance_claim`이면 보험계약서 PDF endpoint를 호출한다.
4. 받은 PDF bytes의 content-type, sha256, size를 검증한다.
5. PDF를 `contract_original` role로 `storage/fine-notices/cases/{fine_notice_id}/contract/contract_original.pdf`에 저장한다.
6. DB file metadata에 저장 경로와 source type을 연결한다.
7. 실패 시 수동 첨부 fallback 상태로 전환하고 재시도/오류 사유를 표시한다.
8. 원본대조필 도장+인감도장이 찍힌 계약서는 후속 문서 패키지 phase에서 `contract_with_stamps`로 수동 첨부한다.

Verification:
- Static checks:
  - `dart format <changed dart files>`
  - `flutter analyze`
  - `git diff --check`
- Tests:
  - source type별 PDF endpoint selection test 후보
  - file metadata 저장 test 후보
- Harness/smoke:
  - 승인된 1건 일반계약 PDF 다운로드/저장
  - 승인된 1건 보험계약 PDF 다운로드/저장
  - 저장된 PDF content-type/sha256/size 확인
  - 실패 시 수동 첨부 fallback 표시 확인
- Manual review:
  - 사장님이 저장된 계약서 PDF 열람과 file role 확인

Completion Evidence:
- Code/doc evidence: source type별 PDF 다운로드 코드, `contract_original` 저장/metadata 연결
- Test evidence:
  - `npm --prefix reservation_ai_parser run check`
  - `dart format lib/features/fines/data/fine_notice_contract_pdf_client.dart lib/features/fines/presentation/fine_notice_page.dart`
  - `flutter analyze`
  - `flutter test`
  - `git diff --check`
- Runtime/DB/external evidence:
  - endpoint 구현: `POST /fine-notices/save-contract-pdf`
  - local 저장 정책 구현: `storage/fine-notices/cases/{fine_notice_id}/contract/contract_original.pdf`
  - DB metadata role: `contract_original`
  - 승인된 실제 fine notice 1건의 앱 버튼 클릭 저장 검증은 운영 확인으로 남김

Probe Evidence:
- 일반계약서 목록 `GET /v2/normal-contracts/group`: 200 확인
- 일반계약서 PDF `GET /normal_contract/get_contract_pdf_from_list/{contractId}`: `application/pdf` 200 확인
- 보험계약서 목록 `GET /v2/rencar-claims`: 200 확인
- 보험계약서 PDF `GET /v2/rencar-claims/{claimId}/contracts/pdf`: `application/pdf` 200 확인

Review Gate:
- Reviewer: 사장님
- Required checks: 일반/보험 PDF endpoint, local 저장 위치, 수동 첨부 fallback, 원본필 처리 기준
- Failure handling: IMS 자동 확보를 보류하고 수동 첨부 기준으로 전환

Completion Judgment:
- PASS criteria: 일반/보험 계약서 PDF가 source type별로 다운로드되어 `contract_original` role로 저장되고, 실패 시 수동 첨부 fallback이 남는다.
- FAIL criteria: 일반/보험 구분 없이 하나의 계약서 API만 사용하거나, 계약서 PDF가 case 폴더/file metadata에 연결되지 않는다.

Commit Gate:
- Stage scope: 승인된 PDF retrieval/fines feature/test/docs 파일만
- Commit message: `feat: store fine notice contract pdfs`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
코드/정적검사 기준 `contract_original` PDF 저장 구현 완료. 실제 IMS 1건 저장 확인은 사장님이 확정 원장에서 버튼으로 확인 후 `Phase 10 runtime verified`로 닫는다.

Rollback/Compensation:
코드 commit revert. SSD에 저장된 테스트 PDF 삭제나 DB metadata 정리는 별도 승인 후 수행한다.

## Closed Scope Notice

이 문서는 과태료/주정차/통행료 임차인 변경 MVP foundation 작업의 완료 문서로 닫는다.

Closed as completed:
- Phase 1 MVP Workflow and UI Lock
- Phase 2 Parser and OCR Policy Lock
- Phase 3 Model Validation PM
- Phase 4 Parser Phase 1 Schema and Fixture
- Phase 5 Parser Phase 2 Image API
- Phase 6 Data and File Model
- Phase 7 IMS Contract API Probe
- Phase 8 Manual Intake and Optional OCR Draft
- Phase 8.1 Fine Notice Persistence Implementation
- Phase 8.2 Parser Image Save Implementation
- Phase 9 IMS Contract Matching
- Phase 10 IMS Contract PDF Save Implementation

Not carried as active phases in this completed document:
- Phase 11 Renter Change Template Lock
- Phase 12 Document Package and Storage Lock
- Phase 12.1 Mobile Download and Share Implementation
- Phase 13 Submission Policy Matrix Lock
- Phase 14 Submission Adapter Implementation
- Phase 15 Release Readiness

Active continuation document:
- `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`

Runtime note:
- b51 실기기 확인에서 상단 메뉴 폭 깨짐과 과태료 AI parser endpoint 미연결 문제가 발견됐다.
- 해당 hotfix는 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`로 완료 처리했다.

### Phase 11. Renter Change Template Lock
Status: MOVED_TO_CONTINUATION

고지서 profile별 임차인 변경 신청서와 신청차량리스트 양식, 자동채움/수동입력 필드를 잠근다.

Scope:
- In:
  - profile별 신청서 양식 유무
  - 신청차량리스트 표 양식
  - 공통 양식 사용 가능 여부
  - 자동채움 필드: 차량번호, 위반/통행일시, 계약자, 계약기간, 주소 등
  - 수동 확인 필드
  - 출력 포맷 후보: PDF, JPEG, DOCX, 기관 사이트 form
  - 기본 문서 3종 중 신청서와 신청차량리스트 생성 기준
  - `U-03`, `U-04` decision lock
- Out:
  - 실제 문서 생성 코드
  - 전자서명/도장 합성
  - 외부 제출

Files/Targets:
- 문서: 이 PM 문서 또는 별도 template policy doc
- 후보 template assets: 미정

Execution Steps:
1. profile별 신청서 양식이 같은지 다른지 표시한다.
2. profile별 신청차량리스트 표 양식이 같은지 다른지 표시한다.
3. 각 양식의 필수 입력 필드를 정의한다.
4. 자동채움 가능한 필드와 사람이 입력해야 하는 필드를 분리한다.
5. 출력 포맷과 미리보기 기준을 잠근다.

Verification:
- Static checks: 문서 리뷰
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review: 사장님이 양식/필드 확인

Completion Evidence:
- Code/doc evidence: profile별 template policy, field map, output format
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: profile별 양식, 자동채움 필드, 수동입력 필드, 출력 포맷
- Failure handling: 해당 profile은 `submission_policy_needed` 또는 `documents_needed` 상태로 보류

Completion Judgment:
- PASS criteria: 문서 생성 구현자가 양식과 필드를 해석 없이 만들 수 있다.
- FAIL criteria: 기관별 양식 차이 또는 필수 필드가 불명확하다.

Commit Gate:
- Stage scope: 승인된 문서/template policy files only
- Commit message: `docs: lock renter change templates`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
신청서 양식과 필드 승인.

Rollback/Compensation:
문서 revert.

### Phase 12. Document Package and Storage Lock
Status: MOVED_TO_CONTINUATION

Purpose:
계약서, 임차인 변경 신청서, 신청차량리스트, 합본 PDF, 제출 증빙을 Mac mini SSD의 fine_notice_id 폴더 기준으로 어디에 어떤 규칙으로 저장할지 잠근다.

Scope:
- In:
  - 원장 1건당 파일 패키지 기준
  - 저장 위치 정책: `storage/fine-notices/cases/{fine_notice_id}`
  - 파일명/버전 규칙
  - IMS API 또는 수동 첨부로 확보한 계약서 파일 상태
  - 원본대조필 도장+인감도장 처리 계약서 파일 분류
  - 임차인 변경 신청서 파일 분류
  - 신청차량리스트 파일 분류
  - 제출처별 3장 합본 PDF 필요 여부 표시
  - 파일별 version/status
  - `U-05`, `U-06`, `U-09`, `U-11`, `U-12` decision lock
- Out:
  - IMS API 사전 테스트 없는 live 출력
  - 승인 없는 파일 외부 전송
  - 승인 없는 전자도장 자동 합성
  - 승인 없는 Storage bucket/RLS 생성
  - 제출처 정책 없이 합본 PDF를 임의 생성/제출

Files/Targets:
- 문서:
  - 이 PM 문서 또는 별도 document package/storage policy doc
- 후보 정책 대상:
  - `storage/fine-notices/cases/{fine_notice_id}` 원장별 폴더
  - `storage/fine-notices/backup-manifests` 백업 검증 기록
  - document template assets 후보
- Protected:
  - 계약서 원본
  - 원본필 처리본
  - 임차인 변경 신청서
  - 신청차량리스트
  - 제출 증빙

Execution Steps:
1. 파일 패키지 상태값을 확정한다.
2. 원장 폴더 구조와 파일명 규칙을 잠근다.
3. 계약서, 도장 처리 계약서, 신청서, 신청차량리스트, 제출증빙의 파일 종류를 잠근다.
4. 제출처별 합본 PDF 필요 여부, 페이지 순서, 파일명 정책을 잠근다.
5. version/status 규칙을 잠근다.
6. NAS 백업 대상과 manifest 검증 기준을 잠근다.

Verification:
- Static checks: 문서 리뷰, `git diff --check`
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review:
  - 실제 필요 서류 구성 확인

Completion Evidence:
- Code/doc evidence: document package/storage policy
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: 원장별 폴더, 파일 종류, 기본 문서 3종, 합본 PDF 필요 여부, 누락 서류 표시
- Failure handling: 파일 모델 보정

Completion Judgment:
- PASS criteria: 제출 전 필요한 파일 종류, 저장 위치, 파일명, version/status 규칙이 잠긴다.
- FAIL criteria: 파일이 원장과 분리되거나 접근 경계가 불명확하다.

Commit Gate:
- Stage scope: 승인된 document package/storage policy docs
- Commit message: `docs: lock fine notice document package`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
서류 패키지 완성 기준 승인.

Rollback/Compensation:
문서 revert. 실제 파일 생성/전송은 이 phase에서 하지 않는다.

Phase 12 Policy Update:
- Storage root locked:
  - Project path: `storage/fine-notices`
  - Actual path: `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices`
- Official storage is Mac mini SSD only.
- Supabase Storage is not used for generated documents.
- Phone gallery/app storage is not an official archive. Phone files are temporary downloads/share copies only.
- Locked case folder:
  - `cases/{fine_notice_id}/notice/notice_original.jpg`
  - `cases/{fine_notice_id}/contract/contract_original.pdf`
  - `cases/{fine_notice_id}/contract/contract_with_stamps.pdf`
  - `cases/{fine_notice_id}/forms/renter_change_application.pdf`
  - `cases/{fine_notice_id}/forms/vehicle_application_list.xlsx`
  - `cases/{fine_notice_id}/forms/vehicle_application_list.pdf`
  - `cases/{fine_notice_id}/bundle/submission_bundle.pdf`
  - `cases/{fine_notice_id}/submission/submission_receipt.pdf`
  - `cases/{fine_notice_id}/submission/submission_result_capture.jpg`
  - `cases/{fine_notice_id}/manifest.json`
- Finalized/submitted files are not overwritten. Regenerated finalized files use `_v002`, `_v003` suffixes.
- DB keeps metadata only: `file_role`, `local_path`, `sha256`, `mime_type`, `size_bytes`, `backup_status`.

### Phase 12.1. Mobile Download and Share Implementation
Status: MOVED_TO_CONTINUATION

Purpose:
Mac mini SSD에 저장된 고지서/계약서/신청서/신청차량리스트/합본/제출증빙 파일을 핸드폰 앱에서 다운로드하거나 OS share sheet로 공유할 수 있게 한다. 파일의 공식 보관 위치는 계속 Mac mini SSD이며, 핸드폰은 임시 다운로드/공유 위치로만 사용한다.

Scope:
- In:
  - 기존 HTTPS 통로 `https://parser.00rentcar.com` 재사용
  - `reservation_ai_parser`에 파일 다운로드 endpoint 추가
  - Endpoint: `GET /fine-notices/{fine_notice_id}/files/{file_role}/download`
  - Supabase에서 `fine_notice_id + file_role` file metadata 조회
  - DB에 등록된 `local_path`만 읽기
  - Mac mini SSD 파일 streaming response
  - `Content-Type`, `Content-Length`, `Content-Disposition` 설정
  - 앱에서 파일 row별 `다운로드`/`공유` 버튼 추가
  - 앱 임시 폴더 다운로드 후 OS share sheet 호출
  - path traversal, 임의 path 다운로드 방지
- Out:
  - 영구 public URL 발급
  - Supabase Storage 업로드
  - 핸드폰 갤러리를 공식 보관 위치로 사용
  - 제출 adapter 실행
  - 문서24/fax/기관 사이트 자동 제출

Files/Targets:
- 후보:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/README.md`
  - `lib/features/fines/*`
  - `pubspec.yaml` if share/open-file dependency is needed
  - `test/*fine_notice*`
- Protected:
  - Mac mini SSD document files
  - Supabase credentials
  - public HTTPS endpoint
  - 사용자 계약서/신청서/제출증빙

Execution Steps:
1. `GET /fine-notices/{fine_notice_id}/files/{file_role}/download` route를 추가한다.
2. route는 Supabase file metadata를 조회하고, 없는 파일/권한 불명확/미등록 path를 거부한다.
3. `local_path`가 `storage/fine-notices` 또는 실제 SSD root 밖이면 거부한다.
4. 파일이 없으면 404와 명확한 error code를 반환한다.
5. 파일이 있으면 stream으로 내려주고 filename은 role 기반 기본명 또는 DB metadata 기준으로 지정한다.
6. Flutter 앱에 파일 목록/다운로드/공유 UI를 추가한다.
7. 다운로드한 파일은 앱 임시 폴더에 저장하고 share sheet를 연다.
8. 다운로드 성공/실패를 원장 UI에 표시한다.

Verification:
- Static checks:
  - `npm --prefix reservation_ai_parser run check`
  - `dart format <changed dart files>`
  - `flutter analyze`
  - `git diff --check`
- Tests:
  - registered file path allow test 후보
  - path traversal deny test 후보
  - missing file 404 test 후보
  - Flutter download/share mapping test 후보
- Harness/smoke:
  - `GET https://parser.00rentcar.com/health` -> 200 유지
  - test fixture file metadata로 local download smoke
  - 미등록 file_role 다운로드 거부 확인
  - 앱에서 다운로드/공유 버튼 동작 확인
- Manual review:
  - 사장님이 핸드폰에서 PDF/XLSX/JPG 1개씩 다운로드 또는 공유 확인

Completion Evidence:
- Code/doc evidence: download endpoint, app download/share UI, README/API doc
- Test evidence: static/test/smoke 결과
- Runtime/DB/external evidence, if applicable: HTTPS download smoke result

Review Gate:
- Reviewer: 사장님
- Required checks: HTTPS route, path guard, file role guard, 핸드폰 공유 동작, 영구 공개 URL 미사용
- Failure handling: download endpoint 비활성화, 파일은 Mac mini SSD에 그대로 유지

Completion Judgment:
- PASS criteria: 앱에서 등록된 file_role을 눌러 Mac mini SSD 파일을 HTTPS로 받아 공유할 수 있고, 임의 path/public URL 노출이 없다.
- FAIL criteria: 파일 URL이 영구 공개되거나, DB metadata 없이 path를 직접 받아 내려주거나, 핸드폰 저장소를 원본 보관소로 사용한다.

Commit Gate:
- Stage scope: 승인된 parser download endpoint, app download/share files, tests/docs
- Commit message: `feat: download fine notice documents`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
모바일 다운로드/공유 경로 검증 완료.

Rollback/Compensation:
code commit revert. 공개 route가 잘못 열렸다면 endpoint 비활성화 후 Cloudflare/tunnel 노출 상태를 확인한다. 이미 다운로드된 핸드폰 임시 파일은 앱 정책에 따라 사용자 단말에서만 정리 가능하다.

### Phase 13. Submission Policy Matrix Lock
Status: MOVED_TO_CONTINUATION

Purpose:
고지서 기관/유형별 제출 채널, 필요서류, 제출양식, 제출대상을 정책표로 잠근다.

Scope:
- In:
  - 사장님이 제공하는 고지서 기관/유형별 제출 정책표
  - 제출 채널 선택: fax / 문서24 / 기관 사이트
  - 제출 전 체크리스트
  - 제출 대상 기관/연락처/URL
  - 제출 상태와 이력
  - 제출 영수증/접수번호 첨부
  - `U-07` decision lock
- Out:
  - 정책표 없이 채널을 임의 판단
  - 인증정보/세션 수정 승인 없는 자동 로그인/접수
  - 실제 제출 adapter 구현

Files/Targets:
- 문서:
  - 이 PM 문서 또는 별도 submission policy doc
- Protected:
  - fax API credential
  - 문서24 계정/session
  - 기관 사이트 계정/session

Execution Steps:
1. 사장님이 알려주는 고지서 기관/유형별 제출 채널을 정책표로 잠근다.
2. 채널별 제출 요구 서류를 문서화한다.
3. 원장 분석 결과의 `noticeProfile`로 정책표 row를 찾아 필요서류/채널을 표시한다.
4. 제출 양식/template과 제출대상을 profile별로 표시한다.
5. 실제 발송/접수는 Phase 14 승인 전까지 진행하지 않는다.

Verification:
- Static checks: 문서 리뷰, `git diff --check`
- Tests: Not in scope
- Harness/smoke: Not in scope
- Manual review:
  - 사장님이 제출 정책표와 채널별 필요 서류 확인

Completion Evidence:
- Code/doc evidence: profile별 제출 정책표
- Test evidence: Not in scope
- Runtime/DB/external evidence, if applicable: Not in scope

Review Gate:
- Reviewer: 사장님
- Required checks: 정책표, 채널 표시, 필요서류 체크리스트, 중복 방지, 접수 증빙
- Failure handling: 외부 제출 미진행, 상태만 보류

Completion Judgment:
- PASS criteria: 고지서 기관/유형에 따라 필요한 서류, 양식, 제출 채널, 제출 대상이 정책표로 잠긴다.
- FAIL criteria: 정책표 없이 채널이 임의 선택된다.

Commit Gate:
- Stage scope: 승인된 submission policy docs
- Commit message: `docs: lock fine notice submission policy`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
정책표에 포함된 채널별 실행 adapter 승인.

Rollback/Compensation:
문서 revert. 실제 외부 제출은 이 phase에서 하지 않는다.

### Phase 14. Submission Adapter Implementation
Status: MOVED_TO_CONTINUATION

Purpose:
Phase 13에서 잠긴 profile부터 file upload, 문서24, login site, fax 제출 adapter를 순차 구현한다.

Scope:
- In:
  - 잠긴 profile의 제출 adapter만 구현
  - 제출 전 checklist 확인
  - 제출 결과/접수번호/증빙 기록
  - duplicate submission guard
  - `U-08`, `U-09` decision lock 후 구현
- Out:
  - 정책표가 unknown인 profile의 제출
  - 무승인 계정/session/credential 변경
  - 무승인 live 제출

Files/Targets:
- 후보:
  - `lib/features/fines/*`
  - submission repository/model
  - external adapter 후보
- Protected:
  - fax API credential
  - 문서24 계정/session
  - 기관 사이트 계정/session
  - 실제 외부 제출

Execution Steps:
1. profile별 adapter type을 선택한다.
2. 제출 전 checklist와 missing document guard를 구현한다.
3. dry-run 또는 manual-ready 상태를 먼저 구현한다.
4. 사장님 별도 승인 후 profile별 live submit을 구현/검증한다.
5. 제출 결과/접수번호/증빙 파일을 원장에 연결한다.

Verification:
- Static checks: `flutter analyze`, `dart format`, `git diff --check`
- Tests:
  - submission state machine test
  - duplicate submission guard test
  - missing document guard test
- Harness/smoke:
  - 제출대기 -> 제출준비완료 -> 제출완료/실패 상태 전환
  - 중복 제출 방지
  - live 제출은 별도 승인된 profile/sample에서만
- Manual review:
  - 사장님이 실제 제출 결과와 증빙 확인

Completion Evidence:
- Code/doc evidence: adapter, guard, submission history UI
- Test evidence: state/guard tests
- Runtime/DB/external evidence, if applicable: 별도 승인된 제출 기록만

Review Gate:
- Reviewer: 사장님
- Required checks: 제출 채널, 필요서류, live 제출 승인, 중복 방지, 접수 증빙
- Failure handling: live 제출 중단, 원장 상태 `on_hold`, 수동 제출 fallback

Completion Judgment:
- PASS criteria: 잠긴 profile에 대해서만 제출 adapter가 동작하고 이력이 남는다.
- FAIL criteria: 정책표 unknown profile 또는 미승인 채널로 제출된다.

Commit Gate:
- Stage scope: 승인된 submission adapter files/tests/docs
- Commit message: `feat: implement fine notice submission adapter`
- Commit only after: 검증 통과와 사장님 commit 승인

Next Phase Entry Criteria:
잠긴 profile별 제출 adapter 검증.

Rollback/Compensation:
코드 revert. 이미 외부 제출된 건은 되돌릴 수 없으므로 보정 문서와 후속 연락 절차 필요.

### Phase 15. Release Readiness
Status: MOVED_TO_CONTINUATION

Purpose:
기능을 실사용 가능한 APK/운영 기준으로 정리한다.

Scope:
- In:
  - 전체 검증
  - 문서 완료 정리
  - APK build 필요 여부 판단
  - 배포 전 리스크 목록
- Out:
  - 승인 없는 APK build/upload
  - 승인 없는 운영 DB migration
  - 승인 없는 parser restart/deploy

Files/Targets:
- `docs/GOAL/rentcar00_OPS-current.md`
- `docs/COMPLETED/rentcar00_OPS-completed.md`
- APK/release artifacts only if separately approved

Execution Steps:
1. 전체 테스트를 실행한다.
2. 고지서 등록부터 제출대기까지 end-to-end smoke를 확인한다.
3. 문서와 구현 기준을 맞춘다.
4. 배포가 필요하면 별도 release 승인으로 진행한다.

Verification:
- Static checks:
  - `flutter analyze`
  - `npm --prefix reservation_ai_parser run check` if parser changed
  - `git diff --check`
- Tests:
  - `flutter test`
  - parser tests if added
- Harness/smoke:
  - 과태료 등록
  - OCR 초안
  - IMS 계약서 API/probe 기준
  - 계약자 후보/확정
  - 서류 패키지
  - 제출대기/이력
- Manual review:
  - 사장님 실사용 흐름 확인

Completion Evidence:
- Code/doc evidence: 완료 문서와 기준점 갱신
- Test evidence: 명령 결과
- Runtime/DB/external evidence, if applicable: 승인된 배포/제출 기록만

Review Gate:
- Reviewer: 사장님
- Required checks: 테스트, 제출 정책표, IMS 계약서 확보 경로, 배포 기준
- Failure handling: release 중단 후 해당 phase로 복귀

Completion Judgment:
- PASS criteria: 실사용 흐름이 검증되고 문서가 최신이다.
- FAIL criteria: 제출 정책/IMS 계약서 확보/파일 보관 기준이 남아 있다.

Commit Gate:
- Stage scope: 승인된 코드/테스트/문서/release 파일
- Commit message: `docs: record fine notice workflow completion`
- Commit only after: 사장님 commit 승인

Next Phase Entry Criteria:
운영 배포 승인.

Rollback/Compensation:
코드/문서 revert. 배포 후 문제는 새 APK 또는 feature disable 계획 필요.

### Final Completion Report
- Completed phases: Phase 1-9 verified up to MVP contract matching. Phase 8.1 Supabase migration applied to remote.
- Phase 10 code verified: IMS 일반/보험 계약서 PDF 저장 endpoint와 OPS 버튼 구현 완료. 실제 확정 원장 1건 runtime 저장 확인은 남음.
- Commits: None from this PM document
- Verification summary: `flutter analyze`, `flutter test`, `npm --prefix fine_notice_ai_parser run check/simulate/file-save-smoke`, `npm --prefix reservation_ai_parser run check`, `git diff --check`, Supabase migration list/REST read smoke passed.
- Residual risks:
  - 실제 기관별 임차인 변경 신청서 양식과 제출 채널 확인 필요
  - 계약서 PDF endpoint와 Phase 9 selected id 매핑은 코드 연결됨. 실제 확정 원장 1건으로 버튼 저장 재확인 필요
  - Mac mini SSD 파일 보존/NAS 백업 정책 필요
  - 모바일 다운로드/공유 endpoint 인증/권한 구현 필요
  - 고지서 기관/유형별 제출 정책은 사장님 입력 필요
- Follow-up work:
  - 확정된 과태료 원장 1건에서 `계약서 PDF 저장` 버튼 runtime 확인
  - `Phase 11` 신청서/신청차량리스트 양식 잠금
  - `Phase 12.1` 모바일 다운로드/공유 구현 승인 여부 결정
  - `Phase 13` 기관별 제출 정책 입력
