# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 운영 기준, 다음 수정 전 기준점, 리스크만 짧게 고정한다.
완료 상세는 `docs/COMPLETED/rentcar00_OPS-completed.md`에 누적하고, 애매하거나 오래된 자료는 `docs/ARCHIVE/`에 둔다.

---

## 현재 active 작업

### 과태료/주정차/통행료 임차인 변경 플로우
MVP foundation은 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`로 완료 처리했다.
후속 구현은 `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`의 운영 게이트와 필요한 작은 MVP PM 기준으로 진행한다.
b51/b52 실기기 hotfix는 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`로 완료 처리했고, b53 과태료 문서패키지 MVP APK는 `docs/COMPLETED/rentcar00_OPS-completed.md`에 배포 기록을 남겼다.
intake 재정의와 롤백 기준은 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_intake_policy_and_rollback_pm.md`로 완료 처리했다.
강남순환도로 4건 다중 row parser 검증은 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_gangnam_multi_parser_micro_pm.md`로 완료 처리했다.

진행 완료:
- 상단 `예약 / 일정 / 과태료` 구조 반영
- 과태료 수동 입력 모달과 AI파서 보조 버튼 추가
- `fine_notice_ai_parser` 추가
- Mac mini SSD `storage/fine-notices` 기반 사진 원본 저장 정책 반영
- remote Supabase migration 적용:
  - `rc00_ops_fine_notices`
  - `rc00_ops_fine_notice_files`
- 과태료 원장 저장/조회 repository 연결
- IMS 일반/보험 계약 후보 검색 MVP 구현
- IMS 보험배차 가져오기 건을 예약원장 lifecycle에 연결하고, 가져온 직후 배차완료/차량상태 `보험` 유지/반납완료 대기 흐름으로 정리
- 계약자 수동 확정값 저장과 action log 기록
- 확정 계약의 IMS 계약서 PDF 저장 endpoint와 OPS 버튼 구현
- b53 과태료 문서패키지 MVP APK 배포
- 과태료 intake rollback 기준 잠금
- 납부기한 primary UI/required warning 제거
- 우리 소유/관리 차량 guard:
  - `rc00_ops_cars.car_number`에 없는 차량은 `not_our_vehicle`로 저장/표시
  - 해당 차량은 IMS 계약검색 진행 불가
- 강남순환도로 4건 다중 고지서 실사진 fixture 확보:
  - fixture 기준 4개 split ledger 후보 검증 통과
  - 실제 public parser smoke는 4 row 개수/차량/장소/금액은 잡았지만 row별 날짜가 누락됨
  - local parser Phase 2 보강 후 실사진 1회 smoke는 4 row 날짜까지 모두 인식
  - public parser restart 후 5회 연속 검증 통과:
    - `noticeProfile: toll_fee.gangnam_sunhwan`
    - `noticeType: toll_fee`
    - row dates 4개 모두 일치
    - warnings 없음
- 강남순환도로 profile은 split ledger UI 진입 Go로 결정
- intake route 정책 잠금:
  - 수동 입력은 기본 루트
  - AI parser 성공 시 단일/다중 row 자동 입력 또는 추가
  - AI parser 실패 시 `parse_failed`로 보고 추출값만 모달에 채운 뒤 수동 입력으로 계속 진행
- 과태료 통합 PM Phase 1-3 구현:
  - parser 결과를 `autoSingle` / `autoMulti` / `parseFailedManualPrefill`로 매핑
  - AI 성공 시 단일/다중 row를 원장 draft로 자동 저장 흐름에 전달
  - AI 실패 시 추출값만 모달에 채우고 수동 저장으로 계속 진행
- 과태료 실전 MVP 모드 전환:
  - 2026-06-19부터 남은 대형 phase 진행은 일시정지
  - 실제 고지서 처리에 필요한 최소 단위부터 만들고, 사용하면서 정책을 잠금
  - `pa all`식 전체 phase 승인 대신 MVP increment별로 승인/검증
  - 수동 fallback은 항상 유지
- 제출정책 매핑 병목 초안:
  - `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
  - profile별 제출 채널, 필요서류, 묶음/문서리스트 필요 여부를 `LOCKED / CANDIDATE / UNKNOWN`으로 분리
- 경찰/교통 과태료 명의변경통보 공문 후보:
  - `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
  - `traffic_fine.seoul_seocho_police` 계열 manual-ready 공문 PDF 후보
- 과태료 문서생성 MVP PM:
  - `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
  - IMS 일반/보험/파트너일반 source 확인, 계약자 스냅샷 DB, 계약서 원본대조필+회사인장, 신청서 인감, manual-ready PDF 패키지 생성 기준
  - `mvp-doc-probe` 1차 결과:
    - 일반/보험 후보 조회에서 이름/전화/주소 후보는 확인
    - 후보 조회 응답에는 주민번호/면허번호 없음
    - 보험계약 PDF 텍스트에서 주소/면허/전화/생년월일 후보 존재 확인
    - 일반계약 PDF는 current import `detailId` 직접 호출 시 실패하므로 `/v2/normal-contracts/group` 기반 PDF id 경로로 보강 완료
    - 일반계약 PDF용 id는 `contractList[].id` 또는 `details[].normal_contract_id`
    - 과태료 계약검색은 `POST /ims/search-fine-notice-contracts` 전용 endpoint에서 일반/보험 후보를 통합 조회
    - 기존 `POST /ims/search-reservations`는 예약 가져오기 전용으로 유지
    - 기존 detail id 확정 원장은 PDF 저장 시 group fallback으로 PDF id를 재해석
    - 경찰공문과 신청서는 별도 산출물이 아니라 같은 `renter_change_application` 문서이며 `수신 - 참조`만 바꿈
- 과태료 workflow integrity correction:
  - `docs/PHASE/rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
  - `pa all`로 Phase 1-5 로컬 구현/검증 완료
  - `not_our_vehicle` status migration draft 추가. remote Supabase 적용은 별도 승인 필요
  - `/fine-notices/save-contract-pdf`는 별도 내부 비밀번호 없이 기존 parser/Supabase/storage 설정으로 저장 시도
  - b53 APK build/upload/commit 완료
- 과태료 next operational phases PM:
  - `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
  - 남은 작업을 read-only 이상점 점검, remote DB status migration, parser restart, 실제 `contract_original.pdf` 저장 smoke, 문서생성 정책 잠금 순서로 재정렬
  - `pa all`은 사용하지 않고 phase별 승인으로만 진행

아직 미구현/보호 구간:
- b53 APK 실기기 설치 후 과태료 리스트/문서생성/공유 시트 확인
- `not_our_vehicle` status migration remote Supabase 적용 상태 재확인
- 다중 row batch/grouping schema의 운영 DB 기준 최종 잠금
- 제출용 문서리스트/신청서 양식의 기관별 공식 템플릿 잠금
- 기관별 제출 정책 `Phase 13`
- fax/문서24/기관 사이트 실제 제출 `Phase 14`
- push

자동차 그룹별 가격 정책 재설정은 즉시 구현 phase가 아니라
`docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`의 PM 문서 기준으로만 남긴다.
코드/DB/운영 반영은 별도 승인 전까지 진행하지 않는다.

## 현재 기준점
- repository: `rentcar00_OPS`
- branch: `fix/ops-return-complete-end-at`
- APK code commit: `a8f3e63 chore: bump android build to b53`
- 앱 버전/build: `1.0.0+53`
- 업로드 상태: GDrive `rentcar00_OPS/apk/`에 `rentcar00_ops-app-release-arm64-b53-a8f3e63.apk` 1개만 존재. 실기기 확인 필요
- 문서 구조: `docs/GOAL`, `docs/PHASE`, `docs/COMPLETED`, `docs/ARCHIVE` 네 영역만 사용
- `docs/current`, `docs/completed`, `docs/past` 구조는 더 이상 active 기준으로 쓰지 않는다.
- 파일 보관 정책:
  - 공식 파일 보관소는 Mac mini SSD `/Volumes/MAC_MINI_SSD/projects/rentcar00_OPS/storage/fine-notices`
  - project path는 `storage/fine-notices`
  - Supabase Storage와 핸드폰 갤러리는 공식 보관소가 아니다.
  - 핸드폰 다운로드/공유는 기존 HTTPS 통로 `https://parser.00rentcar.com`에 붙일 API로 처리한다.

---

## 최근 완료된 큰 기능 묶음

### 1. 예약/차량/일정 기본 운영판
- 예약판 5개 탭과 차량 현황판을 운영 기준으로 정리했다.
- 예약 원장, 차량 상태, 배차/반납 일정, 검색/상세 진입 흐름이 연결돼 있다.
- 차량상세에서 즉시배차/상태수정/연관일정/예약생성 흐름을 사용할 수 있다.

### 2. 관리자/직원/차량관리
- 관리자 `rentcar00` 기준 직원관리 MVP를 구현했다.
- 직원 활성상태, 권한, 위치/활동 정보, 관리자 표시용 비밀번호 확인 UI가 있다.
- 관리자 차량관리에서 차량 추가/수정/삭제, 기본/고급 컬럼 관리를 할 수 있다.

### 3. IMS 연동
- 일반예약 IMS 가져오기: 차량번호/날짜 기준 조회, 후보 선택, OPS 예약 생성 흐름을 구현했다.
- 파트너콜 형태 예약은 상세 API까지 조회해 고객명/번호/생년월일/소개처/가격/배차지/반납지를 채운다.
- 보험배차 IMS 가져오기와 IMS 생성/차량변경/삭제 연동 기준을 잡았다.

### 4. 홈페이지 예약 이벤트 수신
- endpoint: `POST /api/integrations/rentcar00/reservation-events`
- HMAC 서명, timestamp, eventId, payload schema 검증을 넣었다.
- 정상 payload는 이벤트 저장 후 예약 원장/상태/배차·반납 일정까지 자동 생성한다.
- 앱은 홈페이지 검토 배지와 예약 상세 확인 처리를 제공한다.
- 앱 foreground 상태에서는 홈페이지 pending 예약 증가분을 인앱 SnackBar로 알린다.

### 5. UI/실사용 보강
- 상단 통합 검색, 차량 선택, 주소 네이버지도 링크, 당겨서 새로고침, 핵심 Realtime을 반영했다.
- 일정탭 예약 연결 일정은 배차 파랑 / 반납 빨강 강조 카드로 구분한다.
- 차량상세 연관일정은 시간순 세로 카드로 정리했다.
- linked schedule 위치 수정 동기화까지 반영됐다.

### 6. 시간 처리 KST 통일
- 앱 입력/표시는 KST 벽시계 시간으로 통일했다.
- DB 저장 시에만 KST → UTC timestamp 변환한다.
- DB 조회/표시는 UTC → KST로 복원한다.
- 공통 helper: `lib/shared/utils/ops_kst_datetime.dart`

### 7. 운영 DB 정리
- 차량번호 오기 `141호4780 → 142호4780`을 차량/예약/일정 연결 기준으로 정리했다.
- 신규 차량 2대 추가 완료:
  - `165허8095` / 모닝 / 상태 `대기중`
  - `175호2135` / 스타리아 / 상태 `대기중`

---

## 문서 정리 기준
- 현재 목표/기준점: `docs/GOAL/rentcar00_OPS-current.md`
- 진행 예정/진행 중 phase: `docs/PHASE/`
- 완료 누적: `docs/COMPLETED/rentcar00_OPS-completed.md`
- 오래됨/애매함/참고용/구버전: `docs/ARCHIVE/`
- 확실하지 않은 문서는 active에 두지 않고 ARCHIVE로 보낸다.

---

## 가격 정책 현재 기준
- 현재 OPS 앱의 가격 저장 기준은 예약 원장 `rc00_ops_reservations.payment_amount`다.
- 앱 직접 예약 생성/수정은 입력값에서 숫자만 추출해 `payment_amount`에 저장한다.
- AI파서는 원문에 명시된 `총요금`만 가격 후보로 보고, 없으면 가격 누락 경고를 낸다.
- IMS 가져오기는 IMS 응답의 `price/total_price/payment_amount/paid_cost/response_car.price` 후보를 가격 입력으로 가져온다.
- 홈페이지 이벤트 importer는 `quotedTotalAmount/totalAmount/paymentAmount` 후보를 `payment_amount`로 저장한다.
- IMS 생성 payload는 예약 `payment_amount`를 `totalFee`로 보내며, 0보다 큰 숫자가 아니면 생성 전 검증에서 막는다.
- 자동차/차종별 가격표, 자동 계산, DB 정책 테이블, 운영 DB 보정은 현재 구현 기준으로 확인되지 않았다.

---

## 현재 리스크 / 주의점
1. 자동차 그룹 기준이 불명확하면 가격 정책이 앱/홈페이지/IMS 사이에서 어긋날 수 있다.
2. 가격 정책은 생성 경로가 여러 개라 한 번에 넓게 고치면 누락/충돌 위험이 있다.
3. 홈페이지 차량 추가/동기화는 OPS repo 안에 현재 active 구현 기준이 없다.
4. IMS 실제 운영 예약 생성/변경/삭제는 외부 상태 변경이므로 대상 예약 확인 후 진행한다.
5. 문서 archive 자료는 참고용이며 현재 기준으로 그대로 사용하지 않는다.
6. 과태료 계약확정 MVP는 전용 `POST /ims/search-fine-notice-contracts` endpoint를 사용한다. 계약서 PDF 저장 코드는 준비됐고, 선택된 `contractId/claimId`가 실제 계약서 PDF 저장과 이어지는지 확정 원장 1건으로 runtime 확인해야 한다.
7. Mac mini SSD 파일은 공식 보관소지만 NAS 백업 정책은 아직 잠기지 않았다.
8. 모바일 다운로드/공유는 HTTPS 통로만 확인됐고, endpoint 인증/권한/path guard 구현은 아직 남아 있다.
9. 기관별 제출 채널과 필요서류 정책은 사장님 입력 전까지 미정이다. 제출 adapter는 정책 잠금 전 구현하지 않는다.

---

## 다음 작업 후보

### 1순위: 과태료 계약서 PDF runtime 확인
- `docs/PHASE/rentcar00_OPS-fine-notice-mvp-handoff-20260619.md` handoff 기준
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md` Phase 1.5 기준
- 먼저 `not_our_vehicle` status migration remote 적용 여부 결정
- parser restart 후 실제 확정 계약 원장 1건으로 `contract_original.pdf` 저장 확인
- 별도 내부 비밀번호/토큰 가드는 다시 추가하지 않는다.

### 2순위: 과태료 문서생성 MVP
- `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md` 문서생성 MVP PM 리뷰
- 계약자 스냅샷 DB schema와 문서 생성 구현 범위 확정
- 원본대조필/회사 인장 asset 위치 확정
- 신청서·신청차량리스트 양식 잠금
- 문서 패키지 생성과 모바일 다운로드/공유 구현

### 3순위: 과태료 제출정책 잠금
- `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md` 매핑 초안 리뷰
- `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md` 경찰 공문 후보 리뷰
- 기관별 제출 채널과 필요서류를 사장님 확인 후 `LOCKED` 처리
- 외부 제출은 기관별 정책이 잠긴 뒤 제출 adapter phase에서만 진행

### 4순위: 자동차 그룹별 가격 정책 재설정
- `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md` PM 문서 리뷰
- 자동차/차종 그룹 기준 확정
- 수동 입력 유지 / 자동 계산 도입 / DB 정책 테이블 도입 중 하나를 선택
- 승인된 phase 전까지 코드/DB/운영 반영 없음

### 5순위: b53 과태료 문서패키지 MVP 실기기 확인
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md` 완료 문서 참고
- 상단 메뉴 icon-first 구조 육안 확인
- 과태료 AI parser 연결상태와 실제 고지서 사진 파싱 확인
- b53 APK 설치 확인

### 6순위: 실전 투입 피드백 반영
- UI/데이터/시간/IMS 문제를 짧은 phase로 처리한다.

### 7순위: 회계/정산 프로그램
- 예약별 매출/입금/미수, 차량별 수익/비용, 월별 손익 리포트는 별도 큰 phase로 분리한다.
