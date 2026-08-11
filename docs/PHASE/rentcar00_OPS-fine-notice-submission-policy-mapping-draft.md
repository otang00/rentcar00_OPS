# rentcar00_OPS Fine Notice Submission Policy Mapping Draft

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료/주정차/통행료 실전 MVP 제출정책 병목 해소
- Related docs:
  - `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
- Current status: Draft / Research Baseline
- Approval scope: 문서 초안만 작성. DB migration, code change, parser restart, APK build/upload, login/session change, live submission, commit은 별도 승인 필요.

## 0. Goal Lock
- Objective: 고지서 종류/발행기관별로 필요한 서류와 제출 채널을 매핑해 OPS 실전 MVP의 최대 병목을 줄인다.
- MVP success condition:
  - 실제 받은 고지서 profile마다 제출 채널을 하나 이상 특정한다.
  - 필요서류가 `LOCKED / CANDIDATE / UNKNOWN`으로 구분된다.
  - 자동 제출 전까지는 `manual-ready package` 생성만 허용한다.
  - 묶음 제출과 문서리스트 출력 필요 여부를 profile별로 표시한다.
- Non-goals:
  - 정책 없는 자동 제출
  - 기관 사이트 로그인 자동화
  - 문서24/fax 실제 발송
  - 모든 지자체 전국 단위 완성
- Protected targets:
  - 문서24 계정/session
  - 이파인/하이패스/민자도로 법인계정
  - fax/email credential
  - live external submission state

## 1. Research Baseline
- IMS 과태료:
  - 공개 채용공고에서 `IMS 과태료`가 "렌터카 과태료 청구 및 명의 이전 관리 플랫폼"으로 확인됨.
  - 공개 매뉴얼/API/제출처 매핑표는 현재 미확인.
  - Source: `https://www.wanted.co.kr/wd/90040`
- 문서24:
  - 렌터카 업체가 주정차위반/속도위반 과태료/범칙금에 대해 임차인 거주지 관할 시군구청/경찰서로 `납부의무자 변경요청` 문서를 제출하는 공식 흐름 확인.
  - Source: `https://www.korea.kr/news/policyNewsView.do?newsId=148828353`
- 경찰/이파인:
  - `렌트카위반자변경` 메뉴, 샘플 다운로드, 업로드, 상세, 엑셀저장 흐름 확인.
  - Source: `https://www.efine.go.kr/notification/help/helpPop.do?contentType=040104&contentUrl=rentCarChangeList`
- 한국도로공사/하이패스:
  - 임차인변경시스템에서 임대차량 업체가 직접 변경해야 한다는 안내 확인.
  - Source: `https://www.hipass.co.kr/rental/com/forword.do?path=rtur%2Flogin`
- 민자도로:
  - 신공항하이웨이, 용마터널, 구리포천고속도로, 만덕센텀고속화도로에서 각기 다른 전용 사이트/네이버폼/이메일 흐름 확인.

## 2. Policy Vocabulary
| Term | Meaning |
| --- | --- |
| `profile` | 앱/파서가 식별하는 고지서 처리 단위. 예: `toll_fee.gangnam_sunhwan` |
| `submission_channel` | 실제 제출 방식. `fax`, `email`, `document24`, `efine`, `hipass`, `issuer_site`, `naver_form`, `manual_visit_or_mail` |
| `manual_ready` | 파일/서류/수신처까지 준비됐지만 실제 외부 발송은 사람이 하는 상태 |
| `batch_group` | 한 사진/한 고지서에서 나온 여러 원장을 묶는 추적 단위 |
| `document_list` | 묶음 제출 시 차량/일시/계약자/첨부서류를 행 단위로 정리한 제출용 목록 |
| `confidence` | `LOCKED`: 사장님/공식 출처로 확정, `CANDIDATE`: 공식 출처 기반 후보, `UNKNOWN`: 확인 필요 |

## 3. Submission Policy Matrix Draft
| Profile | Notice Class | Issuer / Site | Single/Multi | Required Docs Draft | Channel Candidate | Batch / Doc List | Confidence | Source / Evidence | Blocker |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `toll_fee.woomyeonsan` | 미납통행료 | 우면산인프라웨이 | 보통 단일 | 고지서, 임대차계약서, 임차인변경 신청서 후보 | UNKNOWN: issuer site/fax/email 확인 필요 | 낮음, 단일 위주 | UNKNOWN | 실사진 profile만 있음 | 공식 제출 경로 확인 필요 |
| `toll_fee.gangnam_sunhwan` | 미납통행료 | 강남순환도로 | 다중 가능 | 고지서, 임대차계약서, 임차인변경 신청서 후보, 문서리스트 필수 후보 | UNKNOWN: issuer site/fax/email 확인 필요 | 높음. 한 고지서 4건 분리 + 묶음 추적 필수 | UNKNOWN | 실사진 4-row fixture | 공식 제출 경로 확인 필요 |
| `parking.namdong` | 주정차위반 과태료 | 남동구청 | 단일 | 고지서, 임대차계약서, 납부자/의견진술 변경 신청서 후보 | document24 또는 지자체 fax/site 후보 | 낮음 | CANDIDATE | 문서24 공식 흐름 + 지자체 일반 주정차 의견진술 구조 | 남동구 전용 서식/팩스 확인 필요 |
| `parking.seoul_yongsan` | 주정차위반 과태료 | 서울시/용산구 | 단일 | 고지서, 임대차계약서, 납부의무자 변경요청서 후보 | document24 또는 서울 교통위반 단속조회/구청 채널 후보 | 낮음 | CANDIDATE | 문서24 공식 흐름, 서울시 주정차 인터넷 의견제출 링크 계열 | 용산구/서울시 렌터카 변경 전용 경로 확인 필요 |
| `traffic_fine.seoul_seocho_police` | 교통 과태료/범칙금 | 서울서초경찰서 | 단일 | 명의변경 통보/신청서, 임대차계약서 사본, 위반사실통지 원본/사본, 임차인 정보 | efine 또는 document24/경찰서 후보 | 낮음 | CANDIDATE | 이파인 렌트카위반자변경, 문서24 경찰서 제출 흐름, legacy 공문 샘플 | 법령문구/주민번호 표기/이파인 병행 여부 확인 필요 |
| `toll_fee.hipass_korea_expressway` | 미납통행료 | 한국도로공사/하이패스 | 다중 가능 | 고지서, 계약서, 차량/임차인 정보, 시스템 입력 자료 | hipass rental system | 중간. 시스템 조회/업로드 방식 확인 필요 | CANDIDATE | 하이패스 임차인변경시스템 | 법인 로그인 후 입력/업로드 필드 확인 필요 |
| `toll_fee.incheon_airport_highway` | 미납통행료 | 신공항하이웨이 | 다중 가능 | 계약서 사본, 사업자등록증, 보유차량 등록, 고지서 후보 | issuer dedicated site | 중간 | CANDIDATE | 신공항하이웨이 안내 | 로그인 후 실제 신청 양식 확인 필요 |
| `toll_fee.yongma_tunnel` | 미납통행료 | 용마터널 | 다중 가능 | 고지서, 계약서, 신청업체 정보, 임차인 정보 | issuer site login | 중간 | CANDIDATE | 용마터널 안내 | 로그인/첨부 요구 필드 확인 필요 |
| `toll_fee.guri_pocheon` | 미납통행료 | 구리포천고속도로 | 다중 가능 | 엑셀 양식, 임차인변경정보, 임대차계약서 첨부 | naver_form | 높음. 엑셀/문서리스트 가능성 높음 | CANDIDATE | 구리포천 안내 | 네이버폼 첨부/엑셀 양식 실제 확인 필요 |
| `toll_fee.mandeok_centum` | 미납통행료 | 만덕센텀고속화도로 | 다중 가능 | 미납고지서, 차량계약서 사본 | email | 중간 | CANDIDATE | 만덕센텀 공지 | 이메일 접수 양식/제목/본문 규칙 확인 필요 |
| `parking.bucheon` | 주정차위반 과태료 | 부천시 | 단일 | 대여차량 과태료 납부자 변경 서식, 고지서, 계약서 후보 | city form / document24 후보 | 낮음 | CANDIDATE | 부천시 대여차량 과태료 납부자 변경 안내 | 서식 다운로드 후 필드 분석 필요 |

## 4. Channel Matrix
| Channel | When Used | Required App Output | MVP Handling |
| --- | --- | --- | --- |
| `document24` | 시군구청/경찰서로 납부의무자 변경요청 문서 제출 | 명의변경 통보/신청서, 계약서, 고지서, 문서리스트 optional | manual-ready only |
| `efine` | 경찰 교통 과태료/범칙금 렌트카위반자변경 | 이파인 업로드 샘플 형식, 계약/임차인 정보, 대상 목록 | sample 확보 전 blocked |
| `hipass` | 한국도로공사 미납통행료 | 하이패스 입력/업로드용 임차인 정보, 계약서 | 로그인 필드 확인 전 blocked |
| `issuer_site` | 민자도로/터널 전용 사이트 | 사이트별 입력값, 첨부파일 | profile별 manual-ready |
| `naver_form` | 구리포천 등 네이버폼 접수 | 엑셀/첨부파일/폼 입력값 | 사람이 제출 |
| `email` | 만덕센텀 등 이메일 접수 | 이메일 제목/본문, 첨부파일 패키지 | mailto/manual-ready |
| `fax` | 지자체/기관이 팩스 허용 시 | 팩스용 병합 PDF, 수신번호, 표지 | actual fax send blocked |
| `manual_visit_or_mail` | 온라인 불가/예외 | 출력용 PDF package | manual-ready only |

## 4.1 Document Template Candidates
| Template Key | Applies To | Output | Status | File |
| --- | --- | --- | --- | --- |
| `traffic_police_name_change_letter` | 경찰서 교통 과태료/범칙금 명의변경 통보/신청 | `renter_change_application` PDF/출력물 | CANDIDATE | `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md` |

## 5. Required Data Model Draft
### Profile Policy Fields
```text
profile_key
issuer_name
notice_class
submission_channel
submission_url
submission_contact
login_required
credential_type
required_documents[]
requires_batch_group
requires_document_list
document_list_template_key
package_output_mode
receipt_capture_mode
confidence
source_url
notes
```

### Fine Notice Batch Fields Candidate
```text
source_batch_id
source_batch_label
source_notice_file_id
source_notice_profile
source_notice_issuer
source_notice_document_number
source_row_index
source_row_count
document_list_group_key
```

### Document List Minimum Columns
```text
row_no
notice_profile
issuer_name
document_number
car_number
occurred_at
location
amount
contract_source_type
ims_contract_id_or_claim_id
renter_name
renter_phone
rental_at
return_at
required_documents_status
```

## 6. MVP Lock Order
1. Pick one real profile from incoming notices.
2. Confirm official submission channel and required docs.
3. Mark the row `LOCKED`.
4. Generate manual-ready document package only.
5. Submit manually and store receipt/capture.
6. Backfill the exact output/receipt rules into this matrix.
7. Only after 2-3 locked profiles, implement reusable adapter shape.

## 7. Immediate Bottlenecks
| Bottleneck | Why It Blocks | Next Evidence Needed |
| --- | --- | --- |
| issuer-specific channels differ | same "임차인 변경" but site/email/document24/efine/hipass differ | profile별 official page or actual submitted case |
| required docs differ | some need only 고지서+계약서, others need 신청서/엑셀/공문 | accepted package sample |
| batch/document-list format unknown | 다중 고지서와 묶음 제출에서 핵심 | 구리포천 엑셀, 이파인 샘플, 실제 민자도로 양식 |
| login-only forms hidden | public pages don't show all fields | 사장님 계정 화면 확인 or manual screenshot |
| 범칙금 vs 과태료 split | 경찰/이파인/문서24 흐름이 달라질 수 있음 | 고지서 문구와 이파인 대상 여부 |

## 8. Stop Rules
- `UNKNOWN` profile은 자동 제출 adapter 구현 금지.
- `CANDIDATE` profile은 manual-ready package까지만 허용.
- `LOCKED` 전에는 DB schema를 과하게 확장하지 않는다.
- 로그인/인증/세션이 필요한 사이트는 자동화 전 별도 승인.
- 실제 fax/email/document24/site submission은 사장님 명시 승인 전 금지.

## 9. First MVP Candidate Recommendation
- 1순위: `toll_fee.gangnam_sunhwan`
  - 이유: 다중 row, batch, 문서리스트 병목을 가장 빨리 드러냄.
  - 필요한 다음 자료: 강남순환도로 임차인변경 공식 제출 경로 또는 실제 접수 경험.
- 2순위: `traffic_fine.seoul_seocho_police`
  - 이유: 경찰/이파인/문서24 분기를 빨리 확인해야 함.
  - 필요한 다음 자료: 실제 고지서 상세, 이파인 렌트카위반자변경 대상 여부.
- 3순위: `parking.namdong` 또는 `parking.seoul_yongsan`
  - 이유: 지자체 주정차 과태료의 문서24/팩스/지자체 사이트 분기 확인.
