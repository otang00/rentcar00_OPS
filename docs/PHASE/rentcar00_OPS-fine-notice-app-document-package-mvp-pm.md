# rentcar00 OPS Fine Notice App Document Package MVP PM

## Document Metadata
- Created at: 2026-06-19 KST
- Last updated at: 2026-06-19 KST
- Author/agent: Codex
- Related milestone: 과태료 문서 생성 기능을 앱에서 실제로 쓰기
- Related goal/spec docs:
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_storage_root_correction_micro_pm.md`
- Current status: In Review
- Execution scope: 고지서 날짜/고지서묶음ID 기준 저장 폴더를 먼저 잠그고, 과태료 화면을 엑셀식 리스트로 전환한 뒤, 행 클릭 상세 모달에서 문서 생성/다운로드/공유 기능을 작동하게 만드는 MVP.
- Archive target: `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_app_document_package_mvp_pm.md`

## 0. Goal Lock
- Objective: 사장님이 앱에서 과태료 건을 열고 `문서 생성`을 누르면 제출 준비용 PDF 묶음이 만들어지고, 앱에서 바로 어떤 파일이 준비됐는지 확인할 수 있게 한다.
- Final success condition:
  - 계약 확정된 과태료 건에서 앱 버튼으로 문서 생성이 가능하다.
  - 과태료 화면은 카드가 아니라 엑셀식 리스트로 표시된다.
  - 리스트에서 `계약서확정`, `문서작성`, `발송완료` 체크 상태를 한눈에 본다.
  - 리스트 행을 누르면 상세 카드 모달이 뜨고, 그 안에서 고지서수정/계약서 재검색/문서생성/공유가 작동한다.
  - 생성 후 상세 모달에 `신청서`, `고지서`, `계약서`, 필요 시 `위반목록`이 표시된다.
  - PDF 파일은 핸드폰에서 목록 확인 후 다운로드할 수 있다.
  - 다운로드된 PDF는 앱에서 열거나 공유할 수 있다.
  - 단일 건은 위반목록을 만들지 않는다.
  - 묶음 건은 신청서 1개, 고지서 묶음 1개, 계약서 1개, 위반목록 1개 후보로 표시한다.
  - 계약서 PDF는 제출 패키지에 첫 페이지만 저장/표시한다.
  - 파일은 `고지서 날짜 / 고지서묶음ID` 폴더 아래에만 모인다.
  - 앱은 해당 묶음 폴더 안에 등록된 파일만 보여준다.
  - 실제 문서24/fax/site 제출은 하지 않는다.
  - Android 공용 `Downloads` 폴더 저장은 MVP 필수가 아니며, 앱 내부 저장 후 열기/공유를 MVP 기준으로 한다.
- Explicit non-goals:
  - 외부 기관으로 자동 제출하지 않는다.
  - 모든 기관별 최종 양식을 완성하지 않는다.
  - 계약자 정보를 임의로 만들지 않는다.
  - 도장 이미지나 원본 고지서 파일을 앱에 무방비로 노출하지 않는다.
  - 현재 과태료 외 다른 업무 화면을 정리하지 않는다.
- Protected targets:
  - Mac mini SSD `storage/fine-notices`
  - `rc00_ops_fine_notice_files`
  - `rc00_ops_fine_notices`
  - 계약자 이름/전화/주소/신분정보
  - parser service `ai.otang.reservation-ai-parser`
- Execution scope includes:
  - 서버의 문서 생성 결과를 앱이 호출하는 길 만들기
  - 고지서 날짜별/묶음ID별 저장 폴더 만들기
  - 서버의 PDF 파일을 안전하게 내려주는 길 만들기
  - 앱 목록을 엑셀식 리스트로 표시
  - 리스트 행 클릭 시 상세 카드 모달 표시
  - 상세 모달 버튼을 `고지서수정`, `계약서 재검색`, `문서생성`, `공유` 중심으로 재정리
  - 단일/묶음 표시 규칙 반영
  - 검증용 실제 과태료 1묶음 smoke

## 1. Current State Evidence
- Repo status:
  - 작업트리에 기존 fine notice 관련 변경과 다른 문서/앱 변경이 섞여 있다.
  - commit 시 unrelated 파일을 같이 묶으면 안 된다.
- Existing implementation:
  - 앱에는 `계약서 PDF 저장` 버튼이 있다.
  - 사장님 정책상 이 버튼 이름은 `문서생성`으로 바꿔야 한다.
  - 앱에는 아직 `문서 생성` 버튼이 없다.
  - 앱에는 아직 생성된 PDF 목록 표시가 없다.
  - 앱에는 아직 PDF 다운로드/열기/공유 기능이 없다.
  - `pubspec.yaml`에는 `url_launcher`가 있지만, 앱 내부 저장/파일 공유를 위한 직접 의존성은 아직 없다.
  - 서버에는 `/fine-notices/generate-documents`가 있고 runtime smoke가 성공했다.
  - 서버는 `contract_with_stamps`, `renter_change_application`, `vehicle_application_list`를 생성할 수 있다.
  - 서버에는 아직 파일 다운로드 endpoint가 없다.
  - DB 파일 메타데이터에는 `local_path`가 있지만, 앱이 Mac local path를 직접 열 수는 없다.
  - 현재 생성 파일은 `storage/fine-notices/cases/{fine_notice_id}/...`에 저장된다.
  - 사장님이 잠근 새 저장 기준은 `고지서 날짜 폴더 / 고지서묶음ID 폴더 / 그 안 파일`이다.
- Existing docs/specs:
  - multi-row 정책은 "각 row는 독립 원장, batch/group은 제출 편의"다.
  - 묶음 제출 UI는 아직 확정 구현 전이다.
  - 현재 앱은 과태료 row를 카드로 표시한다.
  - 사장님 추가 정책:
    - 묶음 패키지는 신청서 1개, 고지서 묶음 1개, 계약서 1개가 기본이다.
    - 위반목록은 묶음일 때 후보로 생성해 두되 나중에 쓸지 말지 결정할 수 있다.
    - 단일은 위반목록이 필요 없다.
- Existing tests/harness:
  - `npm --prefix reservation_ai_parser run check`
  - `flutter analyze`
  - relevant Flutter tests if present
  - parser public/local smoke
  - actual generated PDF open/page check
- Known conflicts or drift:
  - 현재 generator는 단일/묶음 구분 없이 `vehicle_application_list`를 만든다.
  - 현재 generator는 대표 row만 `document_ready`로 바꾼다.
  - 앱 모델은 생성 파일 목록을 읽지 않는다.
  - 계약서 원본이 없으면 현재 서버는 `contract_original_missing`으로 문서 생성을 막는다.
  - 앱 상태칩은 raw status를 그대로 보여 `contract_confirmed`, `document_ready`처럼 영어로 보였다.
  - 2026-06-19 Gangnam 2-row smoke 기준 현재 DB 상태:
    - 대표 row `5ec6b200-d553-443c-85f6-03ba1e99b738`: `document_ready`
    - 두 번째 row `01747ecf-d9f7-4764-bc75-239532b4f639`: `contract_confirmed`
  - 즉 "묶음 전체 상태"와 "개별 row 상태"가 다르며, 앱에는 묶음 패키지 상태를 별도로 보여줘야 한다.

## 2. Change Summary
| Item | Before | After | Why |
| --- | --- | --- | --- |
| 앱 버튼 | 계약서 PDF 저장까지만 있음 | 계약서 저장 후 문서 생성까지 앱에서 가능 | 실제 사용자가 터미널 없이 쓸 수 있어야 함 |
| 화면 구조 | 카드 목록 | 엑셀식 리스트 + 행 클릭 상세 카드 모달 | 과태료 업무는 많은 row를 빠르게 확인해야 함 |
| 버튼 구성 | 계약검색/계약서 PDF 저장 중심 | 상세 모달 안에서 `고지서수정`, `계약서 재검색`, `문서생성`, 완료 후 `공유` | 목록은 상태 확인, 기능은 상세에서 작동 |
| 파일 보기 | DB/local path만 있음 | 앱에서 role별 PDF를 열거나 공유 | 현장 사용 MVP에 필요 |
| 파일 저장 | `cases/{fine_notice_id}` 중심 | `notices/{고지서날짜}/{고지서묶음ID}` 중심 | 앱이 "묶음 폴더 안 파일만 표시"하면 단순하고 안전함 |
| 계약서 PDF | IMS PDF 전체 페이지 저장/도장 가능 | 첫 페이지만 `contract_original`/`contract_with_stamps`로 저장 | 제출에 첫 장만 필요하고 파일이 커지는 것을 막음 |
| 단일/묶음 표시 | row 카드만 있음 | 단일 제출 / N건 묶음 제출로 표시 | 제출 패키지 단위를 사람이 이해해야 함 |
| 위반목록 | 항상 생성 | 2건 이상 묶음일 때만 생성 | 단일은 불필요하고 화면도 단순해야 함 |
| 파일 보안 | local path 노출 위험 | 서버가 허용된 파일만 내려줌 | 다른 사건 파일 열람/path 우회 방지 |

## 3. Impact Analysis
| Impact Area | Affected Modules/Docs | Schedule Impact | Risk | Mitigation |
| --- | --- | --- | --- | --- |
| 앱 통신 | new document/file clients | Medium | timeout/실패 메시지 부족 | 계약서 PDF client 패턴을 재사용 |
| 앱 화면 | `lib/features/fines/presentation/fine_notice_page.dart` | High | 표가 모바일에서 좁거나 복잡해질 수 있음 | 핵심 열만 고정하고 상세는 모달로 분리 |
| 앱 데이터 | `FineNoticeCase`, file metadata model/repository | Medium | 체크 상태 계산이 틀릴 수 있음 | 계약서확정/문서작성/발송완료 계산 기준을 명시 |
| 핸드폰 다운로드 | app file download/open/share helper | Medium | Android 권한/저장 위치 문제 | MVP는 앱 내부 저장 후 열기/공유. 공용 Downloads는 후속 |
| 서버 파일 제공 | `reservation_ai_parser/src/server.js` | High | local path 노출, 다른 파일 다운로드 | file id 기준, storage root 안 파일만 허용 |
| 서버 generator | `reservation_ai_parser/src/server.js` | Medium | 단일도 위반목록 생성, 파일이 흩어짐 | row count 조건으로 생성 여부 분리, 묶음 폴더로 저장 |
| DB/runtime | `rc00_ops_fine_notice_files`, parser service | Medium | 잘못된 file metadata | 실제 row smoke로 확인 |
| 외부 제출 | Not in scope | None | 실수로 발송하면 큰 문제 | 제출 endpoint/자동발송 구현 금지 |

## 4. Execution Policy
- Execution model:
  - `pa all`이면 이 문서 범위 안에서 서버, 앱, 검증, 문서 정리까지 순서대로 진행한다.
  - 중간에 별도 승인을 다시 묻지 않는다.
- Phase transition rule:
  - 저장 폴더 기준이 먼저 통과하지 않으면 파일 다운로드나 앱 UI로 넘어가지 않는다.
  - 파일 다운로드 보안이 통과하지 않으면 앱 UI로 넘어가지 않는다.
  - 앱에서 생성 버튼이 보여도 PDF를 열 수 없으면 MVP 완료로 보지 않는다.
- Review rule:
  - 보고서와 문서에는 민감정보 원문을 남기지 않는다.
  - PDF 내용은 파일 존재/페이지/role 기준으로 검증하고, 개인정보는 필요한 최소만 확인한다.
- Commit rule:
  - 완료 후 scoped commit을 목표로 하되, unrelated dirty 파일이 섞이면 commit 전 중단 보고한다.
- Rollback/compensation rule:
  - 앱 버튼/클라이언트는 되돌릴 수 있게 별도 파일/작은 변경으로 유지한다.
  - 서버 endpoint는 추가형으로 만들고 기존 계약서 저장 흐름은 유지한다.
- Stop conditions:
  - 파일 다운로드 endpoint가 storage root 밖 파일을 열 수 있다.
  - 앱이 local path를 그대로 사용자에게 노출해야만 동작한다.
  - 엑셀식 리스트에서 글자/열이 겹쳐 상태 확인이 어려워진다.
  - 핸드폰 저장을 위해 과한 Android 권한이나 공용 Downloads 접근이 필수로 바뀐다.
  - 고지서 날짜 또는 고지서묶음ID 기준이 애매해서 같은 묶음 파일을 한 폴더에 모을 수 없다.
  - 단일/묶음 판단이 불명확해서 잘못된 제출 패키지를 만들 수 있다.
  - parser restart 후 기존 `/health`, 계약서 저장, 문서 생성 smoke가 깨진다.

## 4.1 Exception Policy
이 MVP는 "불완전한 제출 패키지"를 정상 패키지처럼 만들지 않는다.

| Situation | Policy | App Display | Server Behavior | Reason |
| --- | --- | --- | --- | --- |
| 계약 확정 전 | 절대 불가. 앱에서 생성 흐름 진입 금지, 서버도 요청 거부 | `계약확정 필요` | hard reject | 누구에게 넘길 문서인지 확정 전에는 신청서를 만들면 안 됨 |
| 계약 확정됨, 계약서 원본 PDF 없음 | 문서 패키지 생성 불가. 대신 앱에서 먼저 계약서 저장을 유도하거나 자동으로 `계약서 저장 후 문서 생성`을 시도 | `계약서 저장 후 문서 생성` | first save `contract_original`; if save fails, stop | 계약서는 패키지 필수 파일. 없는데 신청서만 만들면 제출 착오 위험 |
| 계약서 저장 실패 | 문서 생성 중단 | `계약서 저장 실패` | no application/stamped contract package | 잘못된 계약서/없는 계약서로 패키지를 만들지 않음 |
| 고지서 원본 없음 | 문서 패키지 생성 불가 | `고지서 원본 필요` | generation reject or review-needed | 패키지 기본 구성이 `신청서+고지서+계약서`이므로 고지서 없이 제출 준비 불가 |
| 계약자 이름/전화/주소 일부 없음 | 초안 생성은 가능하되 `검토 필요`로 표시. 제출 준비 완료로 표시하지 않음 | `검토 필요` badge and missing fields | generate draft with warning metadata | 실제 계약서/PDF 확인으로 보강할 수 있으므로 작업 초안은 만들 수 있음 |
| 계약자 이름 자체 없음 | 문서 생성 보류 | `계약자 정보 필요` | generation reject unless manually overridden later by a separate policy | 이름 없는 신청서는 제출 가치가 낮고 오제출 위험이 큼 |
| 신분번호/면허번호 없음 | 초안 생성 가능, `검토 필요` | `신분정보 확인 필요` | generate warning | 기관마다 필수 여부가 달라 MVP에서는 초안 허용 |
| 같은 묶음 안 계약자가 다름 | 한 패키지로 만들지 않음. 계약자별로 묶음 분리 또는 중단 | `묶음 분리 필요` | generation reject for one-contract package | 패키지 원칙이 계약서 1개이므로 계약자가 다르면 1개 패키지 불가 |
| 같은 묶음 안 계약 source/id가 다름 | 한 패키지로 만들지 않음 | `계약서가 서로 다름` | generation reject | 계약서 1개 원칙 위반 |
| 단일 row | 위반목록 생성 안 함 | `단일 제출` | no `vehicle_application_list` | 불필요한 파일을 줄임 |
| 2개 이상 묶음 row | 위반목록 후보 생성 | `N건 묶음 제출` | generate `vehicle_application_list` | 나중에 제출처별로 첨부 여부 선택 가능 |
| not our vehicle | 문서 생성 불가 | `외부/지사 차량` | generation reject | 이 업무 흐름 대상이 아님 |
| 이미 생성된 패키지 있음 | 다시 생성하면 같은 묶음 폴더 안에서 같은 역할 파일을 교체하거나 새 버전 정책을 따른다. MVP는 같은 역할 교체 | `다시 생성` | replace same role metadata/file | 사용자는 최신 1세트만 보면 됨 |
| 파일 metadata는 있는데 실제 파일 없음 | 해당 파일은 표시하지 않고 재생성/오류 표시 | `파일 없음 - 재생성 필요` | download 404 | 깨진 링크를 정상처럼 보여주면 안 됨 |
| PDF 열기 실패 | 해당 파일만 오류, 전체 패키지는 `검토 필요` | `PDF 확인 실패` | no external submission | 파일 손상 가능성 |
| 계약서 PDF가 여러 페이지 | 첫 페이지만 저장/표시하고 나머지는 버림 | 표시 없음 | save first page only | 제출에 첫 장만 필요함 |

### Mandatory Package Rule
- 정상 패키지의 필수 구성:
  - 신청서 1개
  - 고지서 1개 또는 고지서 묶음 1개
  - 계약서 1개, 첫 페이지만
- 위반목록은 필수 구성에서 제외한다.
  - 단일: 만들지 않음
  - 묶음: 후보로 생성
- 필수 구성 중 하나가 없으면 앱은 `문서 준비 완료`가 아니라 `준비 필요` 또는 `검토 필요`로 표시한다.

### Recommended Button Flow
- 계약 미확정:
  - 버튼 없음 또는 완전 비활성: `계약확정 필요`
  - 계약서 저장/문서 생성 자동 시도도 하지 않음
- 계약 확정 + 계약서 원본 없음:
  - 버튼: `계약서 저장 후 문서 생성`
  - 동작: 계약서 저장 성공 시에만 문서 생성 진행
- 계약 확정 + 계약서 원본 있음:
  - 버튼: `문서 생성`
- 문서 생성 완료:
  - 버튼: `다시 생성`
  - 파일 영역: 같은 묶음 폴더 안 파일만 표시

## 4.2 Phone List and Download Policy
핸드폰 MVP의 목표는 "목록 확인 후 필요한 PDF를 폰에서 바로 여는 것"이다.

### Phone Storage Rule
- 앱은 서버에서 PDF bytes를 받아 핸드폰 안에 저장한다.
- MVP 저장 위치:
  - 앱 전용 문서/캐시 폴더
  - 파일명은 사람이 알아볼 수 있게 만든다.
- 공용 `Downloads` 폴더 저장:
  - MVP 필수 아님.
  - Android 버전별 권한/저장소 정책이 복잡하므로 후속 phase로 분리한다.
- 사용자가 파일을 외부로 빼야 하면:
  - 앱의 `공유` 버튼으로 카카오톡/메일/드라이브/파일앱 등에 넘긴다.

### Phone File Naming Rule
파일명은 local path가 아니라 제출 패키지 정보를 기준으로 만든다.

```text
{고지서날짜}_{차량번호}_{문서번호}_{파일종류}.pdf
```

Examples:
```text
20260619_142호5684_6418191_신청서.pdf
20260619_142호5684_6418191_계약서.pdf
20260619_142호5684_6418191_위반목록.pdf
```

### Phone UI Rule
- 먼저 파일 목록을 보여준다.
- 각 파일 row에는 아래 동작을 둔다.
  - `다운로드`
  - `열기`
  - `공유`
- 아직 다운로드하지 않은 파일:
  - `다운로드` 활성
  - `열기`는 다운로드 후 활성
- 이미 다운로드한 파일:
  - `열기`, `공유` 활성
  - `다시 다운로드` 가능
- 다운로드 실패:
  - 해당 파일만 `다운로드 실패`
  - 전체 패키지는 `검토 필요`

### Phone Download Guard
- 앱은 서버가 내려준 file id로만 다운로드한다.
- 앱은 Mac local path를 표시하거나 직접 사용하지 않는다.
- 서버는 같은 고지서묶음ID 폴더 안 파일만 내려준다.
- 서버가 PDF가 아닌 파일을 내려주면 앱은 저장하지 않는다.
- 파일 크기 0 byte면 저장하지 않는다.

### Share Rule
- 공유는 카카오톡 직접 자동발송이 아니다.
- 앱은 핸드폰 공유창을 연다.
- 사용자가 공유창에서 카카오톡, 메일, 드라이브, 파일앱 등을 선택한다.
- 카카오톡 채팅방 자동 선택/자동 발송은 MVP에서 하지 않는다.
- 공유 버튼은 문서생성이 정상 완료되고 공유할 PDF가 있을 때만 활성화한다.

## 4.3 Fine Notice List and Detail Modal Policy
과태료 메인 화면은 카드가 아니라 엑셀식 리스트로 표시한다.

### List Columns
MVP 리스트 열은 아래를 기본으로 한다.

| Column | Meaning |
| --- | --- |
| 선택/번호 | 행 식별 |
| 차량번호 | 과태료 차량 |
| 고지서 | 발행처/문서번호 |
| 통행/위반일시 | 계약검색 기준 날짜 |
| 장소 | 통행/위반 장소 |
| 금액 | 통행료/과태료 금액 |
| 계약서확정 | 계약자가 확정됐는지 체크 |
| 문서작성 | 문서 패키지가 만들어졌는지 체크 |
| 발송완료 | 실제 제출/발송 완료 여부 체크 |

### Check Columns
체크 표시는 텍스트보다 시각 체크를 우선한다.

| Check | Checked When | Unchecked When |
| --- | --- | --- |
| 계약서확정 | `confirmed_contract_source_type`이 있고 계약 id가 있음 | 계약 미확정 |
| 문서작성 | 묶음 폴더에 필수 파일이 있거나 row/package 상태가 `document_ready` 이상 | 문서 미생성 |
| 발송완료 | status가 `submitted` 또는 제출 영수증/receipt가 있음 | 아직 제출 전 |

### Row Click Rule
- 리스트 행을 누르면 상세 카드 모달이 열린다.
- 기능 버튼은 메인 리스트가 아니라 상세 모달 안에 둔다.
- 상세 모달에서 아래 기능을 작동한다.
  - `고지서수정`
  - `계약서 재검색`
  - `문서생성`
  - `공유`
  - 파일 목록/다운로드/열기

### Detail Modal Button Policy
상세 모달의 기본 버튼은 아래 4개 흐름으로 정리한다.

| Button | When Visible/Enabled | Action | Notes |
| --- | --- | --- | --- |
| `고지서수정` | 항상 표시. 단, 저장 중이면 잠금 | 수동 입력 모달을 열어 파싱된 고지서 내용을 수정 | 차량번호, 고지서번호, 통행일시, 장소, 금액, 발행처 등 수정 |
| `계약서 재검색` | 우리 차량이고 통행일시가 있을 때 | 현재 계약검색 흐름 그대로 실행 | 기존 `계약검색/계약 재검색` 기능의 이름을 `계약서 재검색`으로 통일 |
| `문서생성` | 계약 확정 후 활성. 계약 미확정이면 비활성/숨김 | 계약서 PDF 저장이 없으면 먼저 저장하고, 성공하면 문서 패키지 생성 | 기존 `계약서 PDF 저장` 버튼 이름을 대체 |
| `공유` | 문서생성이 정상 완료되고 공유할 PDF가 있을 때 활성 | 핸드폰 공유창을 열어 PDF 공유 | 카카오톡은 공유창에서 사용자가 선택 |

### Manual Notice Edit Rule
- `고지서수정`은 AI 파싱 결과를 사람이 고치는 모달이다.
- 수정 대상:
  - 고지서 종류/profile
  - 발행처
  - 문서번호/지로번호
  - 차량번호
  - 통행/위반일시
  - 장소
  - 금액
  - 메모/확인 필요 경고
- 수정 저장 후:
  - 아직 계약 확정 전이면 `ready_for_contract_search`로 돌아간다.
  - 이미 계약 확정 후 핵심값이 바뀌면 계약 재검색 필요 상태로 되돌릴지 검토한다.
  - MVP에서는 계약 확정 후 차량번호/통행일시/금액/문서번호를 바꾸면 `계약서 재검색 필요` 경고를 띄우고 문서생성은 막는다.
- 이유:
  - 고지서 내용이 바뀌었는데 기존 계약/문서를 그대로 쓰면 오제출 위험이 있다.

### Document Generate Button Rule
- 버튼 이름은 `문서생성`이다.
- 내부 동작은 아래 순서다.
  1. 계약 확정 여부 확인
  2. 계약서 원본 PDF 존재 확인
  3. 없으면 계약서 PDF 첫 페이지만 저장
  4. 고지서묶음 폴더에 신청서/계약서/필요 시 위반목록 생성
  5. 성공하면 파일 목록 새로고침
  6. 공유 버튼 활성화
- 실패하면 공유 버튼은 활성화하지 않는다.

### Share Button Rule
- 버튼 이름은 `공유`다.
- 공유 대상은 현재 고지서묶음 폴더 안의 제출 패키지 PDF다.
- MVP 선택지:
  - 한 번에 전체 PDF들을 공유
  - 또는 파일별 공유
- 기본 추천:
  - `공유` 버튼을 누르면 공유할 파일 체크 목록을 보여준다.
  - 기본 체크: 신청서, 고지서, 계약서
  - 묶음이면 위반목록도 체크 후보
  - 사용자가 확인하면 Android 공유창을 연다.

## 4.4 Status Display Policy
앱에는 DB status 원문을 그대로 보여주지 않는다.

| DB status | Korean Label | Meaning | Main Action |
| --- | --- | --- | --- |
| `draft` | 작성중 | 아직 저장/확정 전 | 고지서수정 |
| `review_needed` | 확인 필요 | AI 파싱 또는 입력값 확인 필요 | 고지서수정 |
| `ready_for_contract_search` | 계약서 검색 필요 | 고지서 row는 준비됐고 계약을 찾아야 함 | 계약서 재검색 |
| `contract_candidates_ready` | 계약 후보 있음 | 후보가 있으나 아직 확정 전 | 계약서 재검색/확정 |
| `contract_confirmed` | 계약 확정 | 임차인/계약은 확정됐고 문서 패키지는 아직 완료 전 | 문서생성 |
| `document_ready` | 문서 생성 완료 | 제출 패키지 PDF가 만들어짐 | 공유 |
| `submission_ready` | 제출 준비 완료 | 제출 직전 상태. MVP에서는 자동 제출하지 않음 | 사람이 제출 |
| `submitted` | 제출 완료 | 외부 제출까지 끝남 | 조회 |
| `on_hold` | 보류 | 사람이 멈춰둔 상태 | 확인 후 재개 |
| `not_our_vehicle` | 외부/지사 차량 | 우리 소유/관리 차량이 아님 | 이 업무 흐름 중단 |

### Bundle Status Rule
- row status와 묶음 패키지 상태는 다르다.
- 각 row는 독립 상태를 가진다.
- 묶음 패키지 영역은 파일 묶음 존재 여부로 별도 표시한다.

```text
묶음 폴더 안에 필수 파일 있음
→ 묶음 패키지: 문서 생성 완료

대표 row만 document_ready이고 sibling row는 contract_confirmed
→ 개별 row 상태는 다를 수 있음
→ 앱은 묶음 패키지 영역에 "2건 묶음 문서 생성 완료"를 별도로 표시
```

### Current Status Drift To Fix
- 지금 상태가 안 바뀐 것처럼 보이는 이유:
  - 앱이 raw 영어 status를 그대로 보여줬다.
  - generator가 대표 row만 `document_ready`로 바꿨다.
  - 두 번째 row는 정책상 독립 row라 `contract_confirmed`에 남아 있다.
- MVP 수정 방향:
  - 상태칩은 한글로 표시한다.
  - 묶음 패키지 완료 여부는 row status만 보지 말고 파일 묶음 존재 여부로 표시한다.
  - 공유 버튼은 `document_ready` raw status 하나만 보지 말고 공유 가능한 파일 묶음이 있는지로 활성화한다.
  - 메인 리스트에서는 raw 상태명 대신 체크컬럼으로 핵심 진행상태를 보여준다.

## 5. Phase Map
| Phase | Responsibility Unit | Owner | State Change | Scope Lock Summary | Parallelizable | Commit |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 저장 폴더 기준 잠금 | Codex | docs/code | 고지서 날짜/묶음ID 폴더 구조 확정 | No | Final only |
| 2 | 제출 패키지 표시 기준 잠금 | Codex | docs/code small | 단일/묶음/파일 role 기준 확정 | No | Final only |
| 3 | 서버 파일 목록/다운로드 안전문 | Codex | backend | 묶음 폴더 안 file id만 안전하게 PDF 제공 | No | Final only |
| 4 | 서버 생성 규칙 보정 | Codex | backend | 새 폴더에 생성, 단일은 위반목록 생략, 묶음은 생성 | No | Final only |
| 5 | 엑셀식 리스트/상세 모달 전환 | Codex | Flutter | 표 형태 목록, 체크컬럼, 행 클릭 상세 모달 | No | Final only |
| 6 | 상세 모달 버튼/상태 표시 재정리 | Codex | Flutter | 한글 상태, 고지서수정/계약서 재검색/문서생성/공유 버튼 구성 | No | Final only |
| 7 | 앱 문서 생성 버튼 동작 | Codex | Flutter | generate endpoint 호출, 완료 후 공유 활성화 | No | Final only |
| 8 | 앱 제출 패키지 목록 표시 | Codex | Flutter | 묶음 폴더 안 role별 PDF 목록 확인 | No | Final only |
| 9 | 핸드폰 다운로드/열기/공유 | Codex | Flutter | PDF를 폰 앱 내부에 저장 후 열기/공유창 호출 | No | Final only |
| 10 | 실제 핸드폰 묶음 smoke | Codex | runtime/DB/file/device | 폰에서 목록 확인 후 공유창까지 검증 | No | Final only |
| Final | 완료판정/문서정리/커밋 | Codex | docs/git | 검증 후 정리 | No | Yes |

## 6. Parallel Work Lanes
| Lane | Can Run In Parallel With | Subagent Prompt | Inputs | Outputs | Merge Gate |
| --- | --- | --- | --- | --- | --- |
| None | Not applicable | Not applicable | Not applicable | Not applicable | 서버 파일 접근, 앱 표시, 실제 smoke가 순서 의존이라 병렬 작업하지 않는다. |

## 7. Phases

### Phase 1. 저장 폴더 기준 잠금
Status: PLANNED

Purpose:
파일을 먼저 한 묶음 폴더 안에 모으는 기준을 잠근다.

Work:
1. 기본 폴더 구조를 아래처럼 잡는다.
   - `storage/fine-notices/notices/{고지서날짜}/{고지서묶음ID}/`
2. `고지서날짜`는 우선순위를 둔다.
   - 1순위: 고지서에 인쇄된 발행/고지 날짜를 구조화해서 확인할 수 있을 때
   - 2순위: 앱에 고지서를 등록한 날짜
   - 통행일/위반일은 폴더 날짜로 쓰지 않는다. 한 고지서 안에 여러 통행일이 있을 수 있기 때문이다.
3. `고지서묶음ID`는 `document_list_group_key`를 우선 사용한다.
   - 없으면 `source_batch_id`를 사용한다.
   - 둘 다 없으면 서버가 안전한 새 묶음ID를 만들고 DB에 저장한다.
4. 폴더 안은 아래처럼 나눈다.
   - `notice/`: 원본 고지서 이미지 또는 PDF
   - `contract/`: 원본 계약서 첫 페이지, 도장 계약서 첫 페이지
   - `documents/`: 신청서, 위반목록 후보
   - `manifest.json`: 사람이 보기 위한 파일 목록 요약 후보
5. 기존 `cases/{fine_notice_id}` 산출물은 다음 생성 시 새 폴더로 다시 만들거나, 승인된 smoke row만 새 폴더로 이관한다.

Reason:
앱은 "이 묶음 폴더 안 파일만 표시"하면 되므로, 파일 노출 범위가 단순하고 안전해진다.

Scope:
- In: storage folder rule, bundle id rule, existing smoke file handling policy.
- Out: 외부 제출, 대량 파일 정리, orphan 파일 삭제.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `rc00_ops_fine_notice_files`
- `rc00_ops_fine_notices.document_list_group_key`
- `storage/fine-notices/notices/`

Scope Lock:
- Modification allowed: generator path builder, file metadata local_path, bundle key assignment
- Creation allowed: `storage/fine-notices/notices/{date}/{bundleId}/...`
- Deletion allowed: none
- Read-only references: existing `storage/fine-notices/cases/*`
- Excluded targets: unrelated storage folders, old orphan file cleanup
- Behaviors not to change: 계약검색, 원장 생성, not_our_vehicle guard
- Outputs: one canonical bundle folder per notice package
- Scope drift criteria: 고지서 날짜 기준을 확정할 수 없거나 bundle id가 여러 row에서 갈라짐

Execution Steps:
1. Define date fallback rule.
2. Define bundle id generation/storage rule.
3. Add path builder rule to PM/code.
4. Verify resulting folder stays inside storage root.

Verification:
- Static checks: folder path examples review.
- Tests: path builder test if helper is extracted.
- Harness/smoke: real Gangnam bundle creates files under one bundle folder.
- Manual review: folder name is understandable enough without exposing 개인정보.

Completion Evidence:
- Code/doc evidence: folder rule exists.
- Test evidence: check/helper test.
- Runtime/DB/external evidence: generated files share one bundle root.

Review Gate:
- Reviewer: Codex
- Required checks: no file outside bundle root.
- Failure handling: stop before file download/app UI.

Completion Judgment:
- PASS criteria: one notice package maps to exactly one bundle folder.
- FAIL criteria: generated files remain scattered by fine notice id.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Bundle folder policy is locked.

Rollback/Compensation:
- Keep old `cases/{fine_notice_id}` files; disable new package display until fixed.

### Phase 2. 제출 패키지 표시 기준 잠금
Status: PLANNED

Purpose:
사장님이 보는 기준으로 `단일 제출`과 `묶음 제출`을 명확히 나눈다.

Work:
1. 단일은 `신청서 + 고지서 + 계약서`로 표시한다.
2. 묶음은 `신청서 + 고지서 묶음 + 계약서 + 위반목록 후보`로 표시한다.
3. 묶음 기준은 우선 `document_list_group_key` 또는 `source_batch_id`를 사용하고, 없으면 `차량번호 + 고지서 종류 + 문서번호`로 임시 묶는다.
4. 같은 묶음이어도 계약자가 다르면 같은 계약서 1개로 묶지 않는다.

Reason:
문서 생성은 파일 문제가 아니라 제출 단위를 사람이 이해할 수 있어야 끝난다.

Scope:
- In: 표시 기준, 파일 role 이름, 버튼 조건.
- Out: 외부 제출, 기관별 최종 양식.

Files/Targets:
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`

Scope Lock:
- Modification allowed: fine notice docs/model/UI only
- Creation allowed: none unless helper model file is needed
- Deletion allowed: none
- Read-only references: existing PM/completed docs
- Excluded targets: unrelated app screens
- Behaviors not to change: 계약검색, 원장 생성, not_our_vehicle guard
- Outputs: locked display rule in code/docs
- Scope drift criteria: group status propagation becomes necessary

Execution Steps:
1. Define user-facing labels.
2. Add helper naming if needed.
3. Keep row status independent.

Verification:
- Static checks: UI labels and conditions review.
- Tests: model/helper tests if helper is added.
- Harness/smoke: not yet.
- Manual review: 단일/묶음 문구가 사장님 기준에 맞는지 확인.

Completion Evidence:
- Code/doc evidence: package display rule exists.
- Test evidence: helper test or analyze.
- Runtime/DB/external evidence: none.

Review Gate:
- Reviewer: Codex
- Required checks: 단일은 위반목록 없음, 묶음은 위반목록 후보.
- Failure handling: stop and report wording/policy conflict.

Completion Judgment:
- PASS criteria: 앱에서 어떤 파일 묶음인지 헷갈리지 않는다.
- FAIL criteria: 단일과 묶음이 같은 표시로 보인다.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- 표시 기준이 잠겼다.

Rollback/Compensation:
- UI label/helper changes revert.

### Phase 3. 서버 파일 목록/다운로드 안전문
Status: PLANNED

Purpose:
앱이 Mac local path를 직접 만지지 않고, 서버를 통해 허용된 PDF만 받을 수 있게 한다.

Work:
1. 앱이 한 고지서묶음ID의 파일 목록을 받을 수 있는 길을 만든다.
2. 앱이 file id로 PDF를 받을 수 있는 다운로드 길을 만든다.
3. 서버는 `storage/fine-notices/notices/{고지서날짜}/{고지서묶음ID}` 안의 파일만 내려준다.
4. 파일 role이 허용 목록인지 확인한다.

Reason:
앱은 Mac 파일 경로를 직접 열 수 없고, local path를 그대로 노출하면 위험하다.

Scope:
- In: bundle folder file list/download endpoint, path guard, role guard.
- Out: 외부 제출, cloud upload, public anonymous file hosting.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `rc00_ops_fine_notice_files`
- `storage/fine-notices`

Scope Lock:
- Modification allowed: parser server file routes only
- Creation allowed: helper functions inside server or small server module
- Deletion allowed: none
- Read-only references: file metadata table
- Excluded targets: Supabase schema migration unless absolutely required
- Behaviors not to change: existing parse/contract/generate endpoints
- Outputs: guarded bundle file list/download routes
- Scope drift criteria: auth/public sharing model becomes required

Execution Steps:
1. Add file list route.
2. Add file download route.
3. Add storage root/path traversal guard.
4. Add role allowlist.

Verification:
- Static checks: `npm --prefix reservation_ai_parser run check`
- Tests: valid file id returns PDF, invalid file id returns JSON error, path escape fails.
- Harness/smoke: generated file download from real row.
- Manual review: response headers and filename are sensible.

Completion Evidence:
- Code/doc evidence: routes and guards exist.
- Test evidence: node check and curl smoke.
- Runtime/DB/external evidence: valid/invalid download smoke.

Review Gate:
- Reviewer: Codex
- Required checks: cannot download outside storage root.
- Failure handling: do not proceed to app UI.

Completion Judgment:
- PASS criteria: 앱 can receive PDFs without local path exposure.
- FAIL criteria: local path leaks as the only usable mechanism or unsafe path works.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Safe download is verified.

Rollback/Compensation:
- Remove added routes/helpers.

### Phase 4. 서버 생성 규칙 보정
Status: PLANNED

Purpose:
새 묶음 폴더 아래에 문서를 만들고, 단일 건은 위반목록을 만들지 않으며, 묶음 건만 위반목록 후보를 만든다.

Work:
1. generator가 묶음 row 수를 판단한다.
2. generator가 `notices/{고지서날짜}/{고지서묶음ID}` 아래에 파일을 저장한다.
3. 계약서 원본/도장본은 첫 페이지만 저장한다.
4. row가 1개면 `vehicle_application_list`를 만들지 않는다.
5. row가 2개 이상이면 `vehicle_application_list`를 만든다.
6. 생성 결과에 `packageType`, `bundleId`, `bundleRoot` 또는 유사한 설명을 넣어 앱이 단일/묶음을 표시할 수 있게 한다.

Reason:
단일 제출은 신청서/고지서/계약서로 충분하고, 위반목록은 묶음 때만 의미가 있다.

Scope:
- In: document generator response, bundle folder path, file role generation.
- Out: group status auto propagation.

Files/Targets:
- `reservation_ai_parser/src/server.js`
- `rc00_ops_fine_notice_files`

Scope Lock:
- Modification allowed: generator logic only
- Creation allowed: none unless small helper function
- Deletion allowed: generated metadata replacement only for same role during generator route
- Read-only references: current generated PDFs
- Excluded targets: app UI until Phase 4
- Behaviors not to change: contract_original role name remains; stored PDF content becomes first-page-only by policy
- Outputs: correct generated files by row count inside one bundle folder
- Scope drift criteria: requires changing DB schema

Execution Steps:
1. Calculate sibling row count.
2. Skip list generation for single.
3. Preserve list generation for multi.

Verification:
- Static checks: node check.
- Tests: single fixture/row smoke if available; multi real row smoke.
- Harness/smoke: real 2-row Gangnam still creates list.
- Manual review: generated files match expected roles.

Completion Evidence:
- Code/doc evidence: conditional generation.
- Test evidence: node check.
- Runtime/DB/external evidence: file roles after smoke.

Review Gate:
- Reviewer: Codex
- Required checks: contract PDFs are 1 page; single does not produce list; multi does.
- Failure handling: stop before app display.

Completion Judgment:
- PASS criteria: file set matches single/multi policy and contract PDFs are first-page-only.
- FAIL criteria: list always created/never created, or contract PDF keeps extra pages.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Generator file roles are policy-correct.

Rollback/Compensation:
- Revert generator conditional logic.

### Phase 5. 엑셀식 리스트/상세 모달 전환
Status: PLANNED

Purpose:
과태료 메인 화면을 카드 목록에서 엑셀식 리스트로 바꾸고, 행 클릭 시 상세 카드 모달을 열게 한다.

Work:
1. 기존 카드 목록을 엑셀식 리스트로 바꾼다.
2. 리스트에 핵심 열을 둔다: 차량번호, 고지서, 통행/위반일시, 장소, 금액.
3. 리스트에 체크 열을 둔다: `계약서확정`, `문서작성`, `발송완료`.
4. 행을 누르면 상세 카드 모달을 연다.
5. 상세 모달은 기존 카드 정보와 이후 기능 버튼을 담는 작업 공간이 된다.

Reason:
과태료 업무는 row가 많아질 수 있으므로 카드보다 표처럼 한눈에 상태를 보는 편이 맞다.

Scope:
- In: fine notice main list and detail modal shell.
- Out: full redesign, external submission button.

Files/Targets:
- `lib/features/fines/data/`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`
- `lib/features/fines/shared/fine_notice_providers.dart` if needed

Scope Lock:
- Modification allowed: fine notice feature only
- Creation allowed: detail modal widget/helper if needed
- Deletion allowed: none
- Read-only references: existing contract PDF client pattern
- Excluded targets: unrelated screens/routes
- Behaviors not to change: create flow, contract search
- Outputs: list view with check columns and row-click detail modal
- Scope drift criteria: app needs auth/session redesign

Execution Steps:
1. Build table/list row layout.
2. Add check columns for contract/document/submission.
3. Move detailed card content into a modal.
4. Wire row tap to open modal.

Verification:
- Static checks: `flutter analyze`
- Tests: existing tests or focused widget/model tests if practical.
- Harness/smoke: app/manual list and modal visibility check.
- Manual review: list columns fit and row tap opens modal.

Completion Evidence:
- Code/doc evidence: list/check columns and detail modal exist.
- Test evidence: analyze passes.
- Runtime/DB/external evidence: none yet.

Review Gate:
- Reviewer: Codex
- Required checks: list does not overlap on target phone width; row modal opens reliably.
- Failure handling: keep old card view hidden behind rollback only if list is unusable.

Completion Judgment:
- PASS criteria: main view is a usable list and detail modal opens per row.
- FAIL criteria: cards remain the main UI or check columns are unreadable.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- List/modal shell is usable.

Rollback/Compensation:
- Revert to previous card list if table layout is unusable.

### Phase 6. 상세 모달 버튼/상태 표시 재정리
Status: PLANNED

Purpose:
상세 모달 안에서 상태를 한글로 보여주고, 기능 버튼을 `고지서수정`, `계약서 재검색`, `문서생성`, `공유`로 정리한다.

Work:
1. DB status raw 값을 한글 상태칩으로 바꾼다.
2. `고지서수정` 버튼을 추가하고 수동 입력 모달을 연결한다.
3. 기존 계약검색/계약 재검색 버튼 이름을 `계약서 재검색`으로 통일한다.
4. 기존 `계약서 PDF 저장` 버튼 이름을 `문서생성`으로 바꾼다.
5. 문서생성이 정상 완료되기 전에는 `공유` 버튼을 비활성화한다.
6. 문서생성이 정상 완료되고 공유할 PDF가 있으면 `공유` 버튼을 활성화한다.

Reason:
기능은 리스트 안에 늘어놓지 않고 상세 모달에서 정확히 실행해야 실수가 적다.

Scope:
- In: detail modal status labels and function buttons.
- Out: external submission button.

Files/Targets:
- `lib/features/fines/data/`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`
- `lib/features/fines/shared/fine_notice_providers.dart` if needed

Scope Lock:
- Modification allowed: fine notice feature only
- Creation allowed: small manual edit helper/client if needed
- Deletion allowed: none
- Read-only references: existing contract PDF client pattern
- Excluded targets: unrelated screens/routes
- Behaviors not to change: create flow, contract search
- Outputs: modal button layout matches policy
- Scope drift criteria: app needs auth/session redesign

Execution Steps:
1. Map DB status values to Korean labels.
2. Add/route `고지서수정`.
3. Rename contract search button to `계약서 재검색`.
4. Rename PDF save action surface to `문서생성`.
5. Add disabled/enabled `공유` based on package files.

Verification:
- Static checks: `flutter analyze`
- Tests: existing tests or focused widget/model tests if practical.
- Harness/smoke: app/manual button visibility check.
- Manual review: status labels and button labels match 사장님 requested wording.

Completion Evidence:
- Code/doc evidence: Korean status labels and buttons exist with requested labels.
- Test evidence: analyze passes.
- Runtime/DB/external evidence: none yet.

Review Gate:
- Reviewer: Codex
- Required checks: 계약 미확정 row cannot enter document generation/share flow.
- Failure handling: disable button and report.

Completion Judgment:
- PASS criteria: modal exposes Korean statuses and the four-button workflow correctly.
- FAIL criteria: raw English statuses or old `계약서 PDF 저장` wording remains as the main action.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Modal button workflow is visible and correct.

Rollback/Compensation:
- Remove client/button changes.

### Phase 7. 앱 문서 생성 버튼 동작
Status: PLANNED

Purpose:
앱에서 `문서생성` 버튼을 누르면 계약서 저장과 문서 패키지 생성이 이어지게 한다.

Work:
1. 문서 생성용 앱 client를 만든다.
2. 계약 확정 전에는 실행하지 않는다.
3. 계약서 원본 PDF가 없으면 먼저 계약서 첫 페이지만 저장한다.
4. 계약서 저장 성공 시 서버 `/fine-notices/generate-documents`를 호출한다.
5. 성공하면 과태료 목록과 파일 목록을 새로고침한다.
6. 공유할 PDF가 있으면 `공유` 버튼을 활성화한다.

Reason:
사장님은 `계약서 PDF 저장`과 `문서 생성`을 따로 신경 쓰지 않고 `문서생성` 하나로 진행하면 된다.

Scope:
- In: fine notice document generation client and button action.
- Out: external submission button.

Files/Targets:
- `lib/features/fines/data/`
- `lib/features/fines/presentation/fine_notice_page.dart`
- `lib/features/fines/shared/fine_notice_providers.dart` if needed

Scope Lock:
- Modification allowed: fine notice feature only
- Creation allowed: `fine_notice_document_generation_client.dart`
- Deletion allowed: none
- Read-only references: existing contract PDF client pattern
- Excluded targets: unrelated screens/routes
- Behaviors not to change: contract search result selection
- Outputs: app can trigger full document generation
- Scope drift criteria: app needs background job system

Execution Steps:
1. Copy the contract PDF client pattern.
2. Add generation client.
3. Wire `문서생성` button to save-contract-if-needed then generate.
4. Refresh list and enable share after success.

Verification:
- Static checks: `flutter analyze`
- Tests: existing tests or focused tests if practical.
- Harness/smoke: app/manual or client smoke against local parser.
- Manual review: button appears only after contract confirmation.

Completion Evidence:
- Code/doc evidence: client and button action exist.
- Test evidence: analyze passes.
- Runtime/DB/external evidence: generation call succeeds for approved row.

Review Gate:
- Reviewer: Codex
- Required checks: no generation for not_our_vehicle or unconfirmed row.
- Failure handling: keep share disabled and report.

Completion Judgment:
- PASS criteria: user can generate documents from app and share becomes available after success.
- FAIL criteria: terminal/API call still required.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- App can trigger document generation and refresh package files.

Rollback/Compensation:
- Remove generation client/button action; keep button disabled.

### Phase 8. 앱 제출 패키지 목록 표시
Status: PLANNED

Purpose:
생성 후 앱에서 같은 고지서묶음ID 폴더 안 파일 목록을 확인할 수 있게 한다.

Work:
1. 과태료 row가 속한 고지서묶음ID의 파일 목록을 앱에서 가져온다.
2. role별로 사람이 읽는 이름을 붙인다.
3. 단일/묶음 패키지 요약을 표시한다.
4. 파일별 다운로드 상태를 표시한다.
5. 파일이 없거나 깨졌으면 `재생성 필요`를 표시한다.

Reason:
핸드폰에서 어떤 PDF가 준비됐는지 먼저 확인해야 다운로드도 안전하다.

Scope:
- In: fine notice bundle file list UI.
- Out: automatic external submit.

Files/Targets:
- `lib/features/fines/data/`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`

Scope Lock:
- Modification allowed: fine notice feature and necessary dependency only
- Creation allowed: file client/helper
- Deletion allowed: none
- Read-only references: pubspec existing dependencies
- Excluded targets: broad app navigation redesign
- Behaviors not to change: existing fine notice create/search/save flow
- Outputs: visible document package file list from one bundle folder
- Scope drift criteria: requires native platform permission redesign

Execution Steps:
1. Add file metadata model fields if missing.
2. Add file list client.
3. Add package panel in card.
4. Show per-file download state.

Verification:
- Static checks: flutter analyze.
- Tests: model mapping test if added.
- Harness/smoke: actual generated PDFs listed.
- Manual review: labels match 사장님 policy.

Completion Evidence:
- Code/doc evidence: package panel exists.
- Test evidence: analyze passes.
- Runtime/DB/external evidence: real generated files listed.

Review Gate:
- Reviewer: Codex
- Required checks: no raw Mac local path is displayed.
- Failure handling: keep package panel but show `파일 목록 확인 실패`.

Completion Judgment:
- PASS criteria: app shows generated PDF list by bundle.
- FAIL criteria: user still needs terminal/Finder path to know available files.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- App can show package and open/share files.

Rollback/Compensation:
- Remove package panel/client.

### Phase 9. 핸드폰 다운로드/열기/공유
Status: PLANNED

Purpose:
핸드폰에서 파일 목록을 확인한 뒤 PDF를 내려받고 열거나 공유할 수 있게 한다.

Work:
1. 파일 다운로드 client를 만든다.
2. 다운로드한 PDF를 앱 내부 저장 위치에 저장한다.
3. 저장된 파일명을 사람이 알아볼 수 있게 만든다.
4. 다운로드 완료 후 `열기`와 `공유`를 제공한다.
5. 실패 시 해당 파일만 실패로 표시한다.

Reason:
사장님이 폰에서 바로 PDF를 확인하거나 다른 앱으로 넘길 수 있어야 실사용 MVP다.

Scope:
- In: phone download/open/share flow for generated PDF files.
- Out: Android 공용 Downloads 저장, 외부 자동 제출.

Files/Targets:
- `lib/features/fines/data/`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`
- `pubspec.yaml` and `pubspec.lock` only if direct file save/open/share dependency is required

Scope Lock:
- Modification allowed: fine notice feature and required dependency only
- Creation allowed: phone file download helper/client
- Deletion allowed: none
- Read-only references: current generated file metadata
- Excluded targets: unrelated app screens, Android manifest broad permission changes unless unavoidable
- Behaviors not to change: external submission remains absent
- Outputs: phone PDF download/open/share actions
- Scope drift criteria: public Downloads permission becomes required for MVP

Execution Steps:
1. Choose minimal package/helper for app-internal file save.
2. Download PDF by file id.
3. Save to app-controlled folder.
4. Open/share from saved file.
5. Show per-file state.

Verification:
- Static checks: flutter analyze.
- Tests: helper/model tests if practical.
- Harness/smoke: actual generated PDF downloads on phone or emulator/device-capable path.
- Manual review: downloaded filename and buttons are understandable.

Completion Evidence:
- Code/doc evidence: download/open/share flow exists.
- Test evidence: analyze passes.
- Runtime/DB/external evidence: real PDF downloaded and opened/shared from phone.

Review Gate:
- Reviewer: Codex + 사장님 device check when possible
- Required checks: no broad storage permission unless separately approved.
- Failure handling: keep list visible, disable download/open/share, report exact blocker.

Completion Judgment:
- PASS criteria: phone can download and open/share package PDFs.
- FAIL criteria: phone can list files but cannot download/open them.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: all phases verify

Next Phase Entry Criteria:
- Phone download/open/share works for generated PDF files.

Rollback/Compensation:
- Remove download buttons/helper; keep file list display.

### Phase 10. 실제 핸드폰 묶음 Smoke
Status: PLANNED

Purpose:
이번 강남순환도로 2건 묶음으로 실제 핸드폰 앱 흐름이 끝까지 되는지 확인한다.

Work:
1. approved row `5ec6b200-d553-443c-85f6-03ba1e99b738`로 문서 생성.
2. 핸드폰 앱에서 파일 목록 확인.
3. PDF 다운로드 확인.
4. 다운로드한 PDF 열기/공유 확인.
5. 묶음 표시가 `2건 묶음 제출`로 보이는지 확인.
6. 파일들이 같은 `고지서날짜/고지서묶음ID` 폴더 안에 있는지 확인.
7. 두 번째 row가 독립 상태를 유지하는지 확인.

Reason:
MVP는 실제 케이스로 한 번 돌아야 의미가 있다.

Scope:
- In: approved Gangnam 2-row case and phone app check.
- Out: other notices, live submission.

Files/Targets:
- parser service
- Supabase fine notice/file rows
- generated PDFs
- fine notice app screen

Scope Lock:
- Modification allowed: runtime generated files/metadata for approved row only
- Creation allowed: generated document files
- Deletion allowed: same-role replacement by generator only
- Read-only references: second row status/file metadata
- Excluded targets: external submit
- Behaviors not to change: second row status auto-propagation
- Outputs: verified phone list/download smoke evidence
- Scope drift criteria: requires changing row group policy

Execution Steps:
1. Run server/app generation.
2. Query file roles.
3. Open/download PDFs.
4. Check app display.

Verification:
- Static checks: npm check, flutter analyze.
- Tests: available focused tests.
- Harness/smoke: real row generation/list/download/open.
- Manual review: phone display, filename, and PDF readability.

Completion Evidence:
- Code/doc evidence: smoke notes.
- Test evidence: checks pass.
- Runtime/DB/external evidence: generated/opened files.

Review Gate:
- Reviewer: Codex + 사장님 visual review when possible
- Required checks: no live submit.
- Failure handling: report exact failed step.

Completion Judgment:
- PASS criteria: phone app can generate, list, download, open/share actual package.
- FAIL criteria: any step needs terminal/Finder/manual path.

Commit Gate:
- Stage scope: final only
- Commit message: final phase decides
- Commit only after: final phase.

Next Phase Entry Criteria:
- MVP smoke passes.

Rollback/Compensation:
- Keep generated files, disable app button if unsafe.

### Final Phase. Completion Judgment / Documentation Cleanup / Commit
Status: PLANNED

Purpose:
검증된 범위만 완료 처리하고, 섞인 작업트리에서 잘못된 커밋을 막는다.

Work:
- Review all phase outputs:
  - 서버 파일 안전문
  - 단일/묶음 생성 규칙
  - 앱 생성 버튼
  - 앱 파일 표시/열기
  - 실제 smoke
- Make completion judgment:
  - 사장님이 앱에서 실제로 문서 생성/확인까지 할 수 있으면 PASS.
- Update or archive completion documents:
  - 이 PM을 완료 문서로 이동.
  - 부모 문서 생성 PM에 앱 MVP 완료 근거 반영.
- Commit:
  - unrelated dirty file 제외가 확실할 때만 commit.

Reason:
지금 작업트리가 섞여 있어서 마지막 정리가 특히 중요하다.

Scope Lock:
- Modification allowed:
  - this PM/completion archive
  - parent fine notice PM evidence
  - fine notice app files
  - parser server file/document endpoints
  - package files only if dependency was actually needed
- Creation allowed:
  - completed PM archive
- Deletion allowed:
  - none, except PM move from PHASE to COMPLETED
- Read-only references:
  - git status/diff
  - DB/file smoke evidence
- Excluded targets:
  - unrelated app screens
  - unrelated docs
  - external submission code
  - `.env` secrets
  - stamp image binaries
- Behaviors not to change:
  - contract search policy
  - not_our_vehicle guard
  - row-independent status policy
- Outputs:
  - completion report
  - optional scoped commit
- Scope drift criteria:
  - commit would include unrelated dirty files.

Verification:
- Review evidence: phase evidence complete.
- Test/build/harness evidence:
  - `npm --prefix reservation_ai_parser run check`
  - `flutter analyze`
  - valid/invalid file download smoke
  - actual phone app document package list/download smoke
- Documentation evidence:
  - PM archived with date.
- Git status evidence:
  - scoped files identified before staging.

Completion Judgment:
- PASS criteria:
  - 앱에서 문서 생성, 목록 확인, PDF 열기/공유가 가능하다.
  - 핸드폰에서 PDF 다운로드가 가능하다.
  - 단일은 위반목록 없음.
  - 묶음은 위반목록 후보 있음.
  - 파일 endpoint가 storage root 밖 파일을 열 수 없다.
- FAIL criteria:
  - 파일 보안이 불명확하다.
  - 앱에서 PDF 확인이 안 된다.
  - 실제 외부 제출 동작이 섞였다.

Commit Gate:
- Stage scope:
  - only files changed for this PM and previously approved fine notice generator scope.
- Commit message:
  - `feat: add fine notice document package app flow`
- Commit only after:
  - all verification passes and unrelated files are excluded.

Rollback/Compensation:
- Disable/hide app document button.
- Remove file routes if unsafe.
- Keep existing contract PDF save flow.

## Final Completion Report
- Completed phases: implemented through MVP smoke on 2026-06-19.
- Commits: not committed; worktree contains unrelated/pre-existing dirty files and should be staged separately.
- Verification summary:
  - `node --check reservation_ai_parser/src/server.js` passed.
  - `flutter analyze lib/features/fines` passed.
  - Local service restarted with `launchctl kickstart -k gui/$UID/ai.otang.reservation-ai-parser`.
  - `GET /health` passed on `127.0.0.1:43110`.
  - `POST /fine-notices/generate-documents` passed for `5ec6b200-d553-443c-85f6-03ba1e99b738`.
  - Generated bundle folder: `storage/fine-notices/notices/2026-06-19/bundle-1858936513e4cb64/`.
  - Bundle files present: `notice/notice_original.jpg`, `contract/contract_original.pdf`, `contract/contract_with_stamps.pdf`, `documents/renter_change_application.pdf`, `documents/vehicle_application_list.pdf`.
  - `GET /fine-notice-file-packages` returned 5 files with empty `localPath` values.
  - `GET /fine-notice-files/download` returned `200 OK`, `Content-Type: application/pdf`, and a valid PDF for `renter_change_application`.
- Residual risks:
  - Physical phone share sheet was not manually tapped in this agent run; server download and Flutter share/open integration are wired and analyzed.
  - Current bundle date uses app record `created_at` fallback, not a separately parsed printed issue date field.
  - Generated PDFs remain MVP drafts and still require human visual review before external submission.
- Follow-up work:
  - Add submitted/발송완료 persistence after real Kakao/email/manual send workflow is decided.
  - Add profile-specific official templates and submission channel rules.
  - Add automated tests for single notice no-list generation and invalid file-id download denial.
