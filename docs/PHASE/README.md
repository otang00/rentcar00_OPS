# rentcar00_OPS PHASE

진행 예정/진행 중 phase 문서를 두는 위치다.

## 현재 실행 기준
- 과태료 실전 MVP는 큰 `pa all` 트랙이 아니라 작은 increment별 승인으로 진행한다.
- 코드/DB/parser restart/APK/commit/외부 제출은 문서에 적혀 있어도 별도 승인 전 실행하지 않는다.
- Parser API Auth Hardening 이후 OPS 앱용 parser/IMS/과태료 endpoint는 `X-Ops-Parser-Token` 가드를 사용한다. 홈페이지 예약 이벤트는 기존 HMAC 인증을 유지한다.
- 2026-08-04 기준 parser는 `127.0.0.1:43110`에서 active PID `54807`로 재시작 확인됐다. 추가 runtime 변경/APK/commit은 별도 승인 전 실행하지 않는다.
- 2026-08-10 기준 최신 완료 앱 배포는 b59 `rentcar00_ops-app-release-arm64-b59-a5bb856.apk`다.
- 2026-08-10 예약 이벤트 runtime 기준: parser는 `reservation.created`에서 IMS exact binding을 먼저 확보한 뒤 OPS projection을 만든다. 홈페이지/카모아/찜카는 imported/link/schedule evidence가 있고, IMS partner 5684 / IMS `4452946`은 기존 OPS link 때문에 duplicate-link 409로 안전 거부되어 신규 projection 성공 대상에서 제외됐다.

## 문서 드리프트 정리 준비
- `rentcar00_OPS_doc_drift_fix_preparation_20260731.md`
  - 상태: `Prepared`
  - 역할: b59 이전 배포 기록, parser runtime, HARNESS/GOAL/PHASE stale 표현을 전체 정리하기 전 확인된 기준점과 수정 후보를 고정한다.
  - 다음 승인 후보: 과태료/parser 쪽 남은 문서 드리프트 정리 실행.

## 과태료 남은 PM
- `rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
  - 상태: `In Review`
  - 역할: 남은 과태료 MVP를 운영 반영 전 점검, DB status migration, parser restart, 실제 계약서 PDF 저장 smoke, 문서생성 진입 순서로 재정렬한 게이트 PM.
  - 다음 승인 후보: `pa fine-notice-next-p0`로 read-only 기준점/이상점 점검부터 시작.
  - 직접 `pa all` 대상으로 쓰지 않는다. DB/restart/runtime write/APK/commit은 phase별 별도 승인으로만 진행한다.

- `rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
  - 상태: `Local Implementation Verified / DB apply and deployment pending`
  - 남은 일: remote migration은 2026-07-11 기준 적용 확인됐으며, 필요 시 후속 운영 smoke만 남았다. b53 과태료 APK build/upload은 완료했고, 최신 완료 배포 기록은 b59다.
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


## Parser/Auth PM
- `rentcar00_OPS-parser-cloudflare-access-hardening-pm-20260723.md`
  - 상태: `Local Implementation Pending Verification / Operational apply pending`
  - 역할: 공개 parser API의 OPS 앱용 endpoint에 `X-Ops-Parser-Token` 가드를 추가하고 앱 client가 동일 header를 보내도록 하는 보안 선행 PM.
  - 로컬 범위: parser guard, OPS 앱 client header, README 정책 정리.
  - 남은 운영 게이트: OPS 앱 token env 준비, APK build/upload, parser `.env` token 설정, parser restart, public smoke, commit.
  - 운영 `.env`/restart/APK/commit은 별도 승인 전 실행하지 않는다.

## 비과태료 PM
- `rentcar00_OPS-vehicle-group-pricing-policy.md`
  - 상태: `In Review`
  - 역할: 자동차 그룹별 가격 정책 재설정 PM.
  - 과태료 MVP와 별개다. 코드/DB/운영 반영은 아직 승인되지 않았다.

## 완료로 이동한 PM
- Booking docs `docs/COMPLETED/2026-08-10_RESERVATION_EVENT_RUNTIME_ACTIVATION_RELEASE_AND_DOC_DRIFT_PM_COMPLETE_20260810.md`
  - 홈페이지/카모아/찜카 reservation event runtime을 IMS-first OPS projection 기준으로 검증했다. IMS partner는 자동 bulk가 아니라 candidate-report + target-only project-ops로 운용하며, 5684는 기존 linked target으로 기록했다.
- `docs/COMPLETED/rentcar00_OPS_vehicle_availability_active_reservation_policy_PM_COMPLETE_20260810.md`
  - 예약상세 차량변경 overlap 검사에서 `예약취소`/`완료`를 차량 점유에서 제외하고 b59 APK build/upload까지 완료했다.
- `docs/COMPLETED/rentcar00_OPS-external-reservation-ims-existing-search-fallback_PM_COMPLETE_20260804.md`
  - 카모아/찜카 외부예약 handoff의 동일일·1일미만 IMS 기존예약 검색 window와 폴백을 보강했다. target `2172_2026080301000`은 기존 IMS `4431253` 재사용으로 OPS 예약/일정/link와 booking-system intake `completed/linked` 확인 완료.
- `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_homepage_reservation_action_modal_pm.md`
  - 상단 홈페이지 버튼을 액션 모달로 바꾸고 홈페이지 예약 카드 리스트/예약상세 이동을 추가했다.
- `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_three_pm_bundle_execution_plan.md`
  - IMS 보험배차 lifecycle, 홈페이지 인앱알림, 홈페이지 액션 모달 3개 PM 번들 실행을 완료했다.
- `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_homepage_reservation_inapp_notification_pm.md`
  - 앱 foreground 상태에서 홈페이지 pending 예약 증가분을 SnackBar로 알린다.
- `docs/COMPLETED/COMPLETE_20260707_rentcar00_OPS_ims_insurance_longterm_dispatch_lifecycle_pm.md`
  - IMS 보험배차 가져오기를 예약원장 lifecycle에 연결하고 배차완료 후 차량 상태 `보험` 유지 정책을 반영했다.
- `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
  - b51 상단 메뉴/API parser hotfix PM. b52 APK build/upload 완료 기록이며, 최신 완료 배포 기록은 b59다.
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
