# rentcar00_OPS PHASE

진행 예정/진행 중 phase 문서를 두는 위치다.

## 현재 실행 기준
- 과태료 실전 MVP는 큰 `pa all` 트랙이 아니라 작은 increment별 승인으로 진행한다.
- 코드/DB/parser restart/APK/commit/외부 제출은 문서에 적혀 있어도 별도 승인 전 실행하지 않는다.
- PDF 저장용 별도 내부 비밀번호/토큰 가드는 사용하지 않는다. `/fine-notices/save-contract-pdf`는 기존 parser/Supabase/storage 설정으로 저장 시도한다.

## 과태료 남은 PM
- `rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
  - 상태: `In Review`
  - 역할: 남은 과태료 MVP를 운영 반영 전 점검, DB status migration, parser restart, 실제 계약서 PDF 저장 smoke, 문서생성 진입 순서로 재정렬한 게이트 PM.
  - 다음 승인 후보: `pa fine-notice-next-p0`로 read-only 기준점/이상점 점검부터 시작.
  - 직접 `pa all` 대상으로 쓰지 않는다. DB/restart/runtime write/APK/commit은 phase별 별도 승인으로만 진행한다.

- `rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
  - 상태: `Local Implementation Verified / DB apply and deployment pending`
  - 남은 일: `not_our_vehicle` remote migration apply 상태 재확인과 필요 시 후속 운영 smoke. b53 APK build/upload/commit은 완료.
  - 다음 승인 후보: 운영 게이트 기준 `pa fine-notice-next-db-apply`.
  - 문서 단독 alias: `pa workflow-integrity-db-apply`.

- `rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
  - 상태: `Normal PDF path fixed / contract search endpoint corrected / contract PDF runtime smoke next`
  - 남은 일: 실제 원장 1건 `contract_original.pdf` 저장 확인, 계약자 구조화 schema, 도장 asset lock, 신청서/통보서/차량리스트 생성.
  - 다음 승인 후보: 운영 게이트 기준 `pa fine-notice-next-contract-pdf-smoke`.
  - 문서 단독 alias: `pa mvp-doc-runtime-contract-pdf`.

- `rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
  - 상태: `Phase Map Paused / Real MVP Execution Mode`
  - 역할: 큰 통합 로드맵 기준 문서. Phase 1-3 intake는 완료됐고, 이후는 작은 MVP PM 문서로 쪼개 진행한다.
  - 직접 `pa all` 대상으로 쓰지 않는다.

- `rentcar00_OPS-fine-notice-submission-policy-mapping-draft.md`
  - 상태: `Draft / Research Baseline`
  - 역할: 발행기관/profile별 제출 채널과 필요서류 매핑 초안.
  - 남은 일: 사장님이 실제 제출처/서류 기준을 알려주면 `LOCKED`로 승격.

- `rentcar00_OPS-fine-notice-traffic-police-name-change-letter-template.md`
  - 상태: `Draft from legacy sample / needs current legal wording review`
  - 역할: 경찰/교통 과태료 명의변경 통보/신청서 템플릿 후보.
  - 남은 일: 법령 문구, 수신-참조, 주민번호/면허번호 표시 방식, 도장 위치 확인.

## 비과태료 PM
- `rentcar00_OPS-vehicle-group-pricing-policy.md`
  - 상태: `In Review`
  - 역할: 자동차 그룹별 가격 정책 재설정 PM.
  - 과태료 MVP와 별개다. 코드/DB/운영 반영은 아직 승인되지 않았다.

## 완료로 이동한 PM
- `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_homepage_reservation_action_modal_pm.md`
  - 상단 홈페이지 버튼을 액션 모달로 바꾸고 홈페이지 예약 카드 리스트/예약상세 이동을 추가했다.
- `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_three_pm_bundle_execution_plan.md`
  - IMS 보험배차 lifecycle, 홈페이지 인앱알림, 홈페이지 액션 모달 3개 PM 번들 실행을 완료했다.
- `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_homepage_reservation_inapp_notification_pm.md`
  - 앱 foreground 상태에서 홈페이지 pending 예약 증가분을 SnackBar로 알린다.
- `docs/COMPLETED/COMPLETE_20260707_rentcar00_OPS_ims_insurance_longterm_dispatch_lifecycle_pm.md`
  - IMS 보험배차 가져오기를 예약원장 lifecycle에 연결하고 배차완료 후 차량 상태 `보험` 유지 정책을 반영했다.
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
  - b51 상단 메뉴/API parser hotfix PM. b52 APK build/upload 완료 기록이며, 최신 배포는 b53이다.
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
  - 기존 과태료 MVP foundation 로드맵.
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_intake_policy_and_rollback_pm.md`
  - 과태료 intake 정책/롤백 기준.
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_gangnam_multi_parser_micro_pm.md`
  - 강남순환도로 4건 다중 row parser 5/5 검증.
- `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_required_fields_gate_pm.md`
  - `확인 필요` 항목이 남은 문서 패키지 생성을 서버에서 차단하고 앱에서 수동수정으로 유도.
- `docs/COMPLETED/COMPLETE_20260620_rentcar00_OPS_fine_notice_manual_bundle_merge_pm.md`
  - 리스트 상단 `묶기` 선택모드, 서버 dry-run/write 검증 API, `document_list_group_key` 수동 병합 저장.

## 다음 세션 handoff
- `rentcar00_OPS-fine-notice-mvp-handoff-20260619.md`
