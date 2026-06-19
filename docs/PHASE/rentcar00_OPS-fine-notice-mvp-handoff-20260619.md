# rentcar00_OPS Fine Notice MVP Handoff 2026-06-19

## 1. 현재 목표
과태료/주정차/통행료 고지서를 원장화하고, IMS 계약검색으로 임차인을 확정한 뒤 계약서 PDF와 임차인 변경 신청/통보 문서 패키지를 만들 수 있게 한다.

현재 우선순위는 문서 생성 전체가 아니라 실전 MVP의 다음 병목이다.
1. `not_our_vehicle` status migration remote 적용
2. 운영 parser restart
3. 실제 fine notice 원장 1건으로 `contract_original.pdf` 저장 runtime 확인
4. 계약자 구조화 schema와 신청서/도장 문서 생성으로 진행

## 2. 현재 상태
- 원장 생성: 수동 입력과 AI parser intake 흐름이 코드 기준 준비됨.
- 다중 고지서: 강남순환도로 4건 row parser 5/5 검증 완료. 각 row는 개별 원장으로 들어가는 정책.
- 비소유/비관리 차량: 앱은 `not_our_vehicle`로 저장/표시하고 계약검색을 막음. remote DB constraint 적용은 아직.
- 계약검색: 과태료 전용 `POST /ims/search-fine-notice-contracts`로 일반/보험 후보 조회.
- 계약자 확정: 후보 확정 후 source type, `contractId` 또는 `claimId`, renter snapshot 저장.
- 계약서 PDF 저장: 코드상 `/fine-notices/save-contract-pdf`가 `fineNoticeId`만 받아 IMS PDF를 받아 `contract_original.pdf`로 저장하도록 열려 있음.
- 운영 반영: parser restart, remote DB apply, APK build/upload, commit은 아직 하지 않음.

## 3. 이미 결정된 사항
- 과태료 계약검색은 `POST /ims/search-reservations`를 쓰지 않는다.
- `/ims/search-reservations`는 예약 가져오기 전용이다.
- 일반계약 PDF id는 `/v2/normal-contracts/group`의 `contractList[].id` 또는 `details[].normal_contract_id`를 사용한다.
- `details[].id`는 PDF endpoint에 직접 넣으면 실패할 수 있으므로 PDF용 id로 쓰지 않는다.
- 보험계약 PDF id는 claim id다.
- PDF 저장용 별도 내부 비밀번호/토큰 가드는 사용하지 않는다.
- 계약서 원본은 `contract_original`, 도장 찍은 계약서는 `contract_with_stamps`로 분리한다.
- 경찰공문과 신청서는 별도 산출물이 아니라 같은 `renter_change_application` 문서이며 `수신 - 참조`만 바뀐다.
- 원본 사진/생성 문서 공식 보관소는 Mac mini SSD `storage/fine-notices` 기준이다.
- Supabase Storage와 핸드폰 갤러리는 공식 보관소가 아니다.

## 4. 관련 파일/모듈
- Active PM index: `docs/PHASE/README.md`
- Current goal: `docs/GOAL/rentcar00_OPS-current.md`
- Completed log: `docs/COMPLETED/rentcar00_OPS-completed.md`
- Contract search correction PM: `docs/PHASE/rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
- Next operational gate PM: `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
- Document generation PM: `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
- Integrated PM: `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
- Submission policy draft: `docs/PHASE/rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
- Police template: `docs/PHASE/rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
- Parser server: `reservation_ai_parser/src/server.js`
- Parser config: `reservation_ai_parser/src/parser-core.js`
- Fine notice models/client/repository/UI: `lib/features/fines/`
- App env: `lib/shared/config/app_env.dart`
- Fine notice migration base: `supabase/migrations/20260619153000_add_fine_notice_tables.sql`
- Pending status migration: `supabase/migrations/20260619190000_add_not_our_vehicle_fine_notice_status.sql`

## 5. 완료된 작업
- b51/b52 hotfix PM을 `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`로 이동.
- `docs/PHASE/README.md`를 남은 PM 기준으로 재작성.
- 계약검색 correction PM에서 남은 token/env guard 표현 제거.
- 문서생성 PM에 `Phase 1.5 Contract Original PDF Runtime Smoke` 추가.
- 통합 PM final report를 Phase 1-3 완료/실전 MVP paused 기준으로 정리.
- current 문서에서 b51/b52 hotfix 위치와 다음 기준 PM 정정.

## 6. 남은 작업
- Remote Supabase에 `not_our_vehicle` status migration 적용.
- 운영 parser restart.
- 실제 확정 계약이 있는 fine notice 원장 1건으로 `/fine-notices/save-contract-pdf` runtime smoke.
- 저장된 `contract_original.pdf`가 올바른 계약서인지 사람이 확인.
- 계약자명, 주민번호 또는 면허번호, 실제 주소, 전화번호 구조화 schema 확정.
- 원본대조필/회사 인장 asset 위치와 사용 규칙 확정.
- `contract_with_stamps.pdf`, `renter_change_application.pdf`, `vehicle_application_list` 생성 구현.
- 기관/profile별 제출 채널과 필요서류 `LOCKED` 처리.
- APK build/upload와 commit.

## 7. 알려진 리스크
- `not_our_vehicle`는 앱에서 쓰지만 remote DB constraint에 아직 반영되지 않았을 수 있다.
- 운영 parser가 아직 재시작되지 않았으므로 현재 코드가 public runtime에 반영됐다고 보면 안 된다.
- 실제 PDF 저장은 파일/DB write를 하므로 승인된 원장 1건으로만 확인해야 한다.
- 보험계약 후보 hit가 있는 smoke는 아직 부족하다.
- 문서 생성에는 민감정보가 들어가므로 raw 값을 문서나 로그에 남기면 안 된다.
- 제출 정책은 profile별로 다르며, 사장님 확인 전 자동 제출로 넘어가면 안 된다.

## 8. 다음 첫 행동
사장님이 바로 기능 진행을 원하면 첫 실행 후보는 아래 순서다.

0. 기준점부터 다시 확인할 경우:
   - 승인 문구: `pa fine-notice-next-p0`
   - 할 일: dirty tree, PM 문서, endpoint/status/schema 정책을 read-only로 다시 대조하고 이상점이 있으면 중단 보고.

1. DB부터 맞출 경우:
   - 승인 문구: `pa fine-notice-next-db-apply`
   - 할 일: `20260619190000_add_not_our_vehicle_fine_notice_status.sql` remote 적용 후 상태 저장 실패 위험 제거.

2. 운영 parser를 현재 코드로 맞출 경우:
   - 승인 문구: `pa fine-notice-next-parser-restart`
   - 할 일: parser restart와 public endpoint smoke만 수행.

3. 계약서 다운로드를 확인할 경우:
   - 승인 문구: `pa fine-notice-next-contract-pdf-smoke`
   - 할 일: 실제 확정 계약 원장 1건으로 `contract_original.pdf` 저장 smoke.

## 9. 건드리면 안 되는 영역
- PDF 저장용 별도 내부 비밀번호/토큰 가드를 다시 추가하지 않는다.
- `/ims/search-reservations`에 과태료 계약검색 mode나 normal-contract group 조회를 다시 섞지 않는다.
- 정책 확정 전 fax/문서24/기관 사이트 live submission을 하지 않는다.
- 승인 없이 remote DB migration, parser restart, APK build/upload, commit/push를 하지 않는다.
- 회사 인감/원본대조필 이미지 원본을 git에 넣지 않는다.
- 계약자 주민번호/면허번호/주소/전화번호 raw 값을 docs나 일반 로그에 남기지 않는다.
- unrelated dirty files를 되돌리거나 정리하지 않는다.
