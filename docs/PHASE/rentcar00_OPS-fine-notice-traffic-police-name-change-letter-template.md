# Traffic Police Fine Name Change Application Template

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related profile: `traffic_fine.seoul_seocho_police`
- Related policy doc: `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
- Current status: Draft from legacy sample / unified notice-application template / needs current legal wording review
- Approval scope: 문서 템플릿 초안만 작성. 실제 제출, 자동 생성 구현, 법령문구 확정, 직인/인감 처리, commit은 별도 승인 필요.

## 0. Purpose
경찰서 교통 과태료/범칙금 계열에서 렌터카 임차인에게 과태료/범칙금 납부의무 또는 명의 변경을 요청하기 위한 명의변경 통보/신청 문서 템플릿이다.

이 템플릿은 사장님이 제공한 기존 공문 샘플을 기반으로 하며, 실전 MVP에서는 사람이 검토한 뒤 PDF/출력물로 사용한다.

이 문서는 경찰공문과 신청서를 별도 산출물로 나누지 않는다. 같은 문서를 사용하고 제출처에 따라 `수신 - 참조`만 바꾼다.

## 1. Template Variables
| Variable | Meaning | Source Candidate |
| --- | --- | --- |
| `company_name` | 발신 회사명 | 고정값: 빵빵카(주) |
| `company_website` | 회사 사이트 | 고정값: rentcar00.com |
| `company_address` | 회사 주소 | 고정값 |
| `company_tel` | 회사 전화 | 고정값 |
| `company_fax` | 회사 팩스 | 고정값 |
| `company_email` | 회사 이메일 | 고정값 |
| `document_number` | 문서번호 | 자동 채번 또는 수동 입력 |
| `issued_date` | 시행일자 | 작성일 |
| `sender_department_person` | 발신/담당 | 고정 또는 사용자 선택 |
| `recipient_org` | 수신 기관 | 고지서 발행 경찰서/교통과 |
| `violation_clause` | 제목/본문의 도로교통법 위반 사항. 예: `제15조3항 속도` | 고지서 parser/manual |
| `notice_reference_number` | 위반 사실 통지서 통지번호 | 고지서 parser/manual |
| `notice_car_number` | 고지서 차량번호 | 원장 확정값 |
| `violation_car_number` | 위반 차량 | 원장 확정값 |
| `violation_at` | 위반 일시 | 원장 확정값 |
| `violation_location` | 위반 장소 | 원장 확정값 |
| `violation_detail` | 위반 내용. 예: `제15조3항 속도위반` | 고지서 parser/manual |
| `renter_name` | 위반일시 차량의 계약자 | 확정 계약자 |
| `renter_identity_no` | 계약자 주민번호 | IMS 계약서/수동 입력, 민감정보 |
| `renter_phone` | 계약자 전화번호 | IMS 계약서/수동 입력 |
| `attachments` | 별첨 목록 | 계약서, 위반사실통지 원본 등 |

## 2. Draft Template
```text
{{company_name}}   ({{company_website}})

"(우) {{company_postcode}} {{company_address}}
Tel : {{company_tel}}  Fax : {{company_fax}}  mail : {{company_email}}"

문 서 번 호  : {{document_number}}
시 행 일 자  : {{issued_date}}
발신 - 담당  : {{sender_department_person}}
수신 - 참조  : {{recipient_org}}
제      목  : 도로교통법( {{violation_clause}} )위반 과태료 명의변경통보.

1, 귀 관청의 무궁한 발전을 진심으로 기원합니다.

2, 귀 관청에서 발행한 위반 사실 통지서( 통지번호 : {{notice_reference_number}} )
도로 교통법( {{violation_clause}} 위반 ) 적발 ( {{notice_car_number}} )차량의 과태료 부과 건에 대하여
당사는 자동차대여 사업체로서 당시 내용대로 위반 임차인을 다음과 같이 통보하오니
조치하여 회신 주시기 바랍니다.

3, 운수사업법 제56조6, 시행규칙 제49조 준용 교통부 장관이 인가한 자동차 대여약관
제19조 2항(임차인은 교통법규 및 주,정차 위반 범칙금은 렌트카 반납 후에도 임차인이 부담한다.)
및 자동차 운수 사업법 제31조 등에 관한 처분 요령 중 개정령 제7조 5항 신설내용
(자동차 대여 사업자가 대여한 자동차로서 자동차만을 임대한 것이 명백한 경우에는
고용주에게 과태료에 처하지 아니한다.)을 참조하여 주시기 바랍니다.

------   다           음  ------

1 위 반 차 량 : {{violation_car_number}}
2 위 반 일 시 : {{violation_at}}
3 위 반 장 소 : {{violation_location}}
4 위 반 내 용 : {{violation_detail}}
5 위  반  자 : {{renter_name}}
6 주민등록No : {{renter_identity_no}}
7 연  락  처 : {{renter_phone}}

*별 첨 :
1, 차량임대차 계약서 사본 1부
2, 위반 사실통지 원본 1부
```

## 3. Provided Variable Sample
```text
빵 빵 카 (주)   (rentcar00.com)

"(우) 137-070 서울시 서초구 신반포로 23길 78-9, 빵빵카(주)
Tel : (02)592-0079  Fax : (02)592-7900  mail : rentcar00@daum.net"

문 서 번 호  : 04-12-03-1
시 행 일 자  : 04-12-03
발신 - 담당  : 빵빵카㈜ - 오연균
수신 - 참조  : 서울 서초경찰서-교통
제      목  : 도로교통법( ** 위반 사항 ** )위반 과태료 명의변경통보.

1, 귀 관청의 무궁한 발전을 진심으로 기원합니다.

2, 귀 관청에서 발행한 위반 사실 통지서( 통지번호 : ) 도로 교통법( **위반 사항** 위반 ) 적발 ( ** 차량번호 ** )차량의 과태료 부과 건에대하여 당사는 자동차대여 사업체로서 당시 내용대로 위반 임차인을 다음과 같이통보 하오니 조치하여 회신 주시기 바랍니다.

3, 운수사업법 제56조6, 시행규칙 제49조 준용 교통부 장관이 인가한 자동차 대여약관 제19조 2항(임차인은 교통법규 및 주,정차 위반 범칙금은 렌트카 반납 후에도 임차인이 부담한다.)및 자동차 운수 사업법 제31조 등에 관한 처분 요령 중 개정령 제7조 5항 신설내용(자동차 대여 사업자가 대여한 자동차로서 자동차만을 임대한 것이 명백한 경우에는 고용주에게 과태료에 처하지 아니한다.)을 참조하여 주시기 바랍니다.

------   다           음  ------

1 위 반 차 량 : **차량번호**
2 위 반 일 시 : **위반일시**
3 위 반 장 소 : **위반장소**
4 위 반 내 용 : **위반내용**
5 위  반  자 : **위반일시 차량의 계약자**
6 주민등록No : **계약자 주민번호**
7 연  락  처 : **계약자 전화번호**

*별 첨 :
1, 차량임대차 계약서 사본 1부
2, 위반 사실통지 원본1부
```

## 4. MVP Handling
- This template is a candidate for:
  - `traffic_fine.seoul_seocho_police`
  - 경찰서 교통과 대상 과태료/범칙금 명의변경 통보/신청
  - 문서24 또는 수동 제출용 PDF
  - file role: `renter_change_application`
- Required attachments:
  - 차량임대차 계약서 사본
  - 위반 사실통지/고지서 원본 또는 사본
- Sensitive fields:
  - 주민등록번호는 표시/저장/출력 정책을 별도 잠금해야 한다.
  - MVP에서는 사람이 확인 후 문서 생성한다.

## 5. Open Questions
| Question | Status |
| --- | --- |
| 현재 법령 문구를 그대로 써도 되는가 | UNLOCKED |
| 주민등록번호 전체 표기 여부 | UNLOCKED |
| 문서24 제출 시 수신처/제목/본문 필드 규칙 | UNLOCKED |
| 이파인 업로드 방식과 이 공문 PDF가 병행 필요한지 | UNLOCKED |
| 회사 주소/전화/fax/email 최신값 | NEEDS_CONFIRMATION |
