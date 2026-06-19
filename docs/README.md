# rentcar00_OPS docs

문서 구조는 `GOAL / PHASE / COMPLETED / ARCHIVE` 네 영역만 사용한다.

## 바로 볼 문서
1. `docs/GOAL/rentcar00_OPS-current.md`
   - 현재 목표, 기준점, 실전 투입 전 확인사항, 다음 작업 후보
2. `docs/COMPLETED/rentcar00_OPS-completed.md`
   - 완료된 기능의 운영/검증/장애 대응 누적
3. `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`
   - 자동차 그룹별 가격 정책 재설정 PM 문서
   - 상태: `In Review`
   - 코드/DB/운영 반영은 아직 승인되지 않았다.
4. `docs/PHASE/README.md`
   - 남은 PM 문서 인덱스
   - 다음 과태료 MVP 승인 후보와 완료로 이동한 문서를 구분한다.
5. `docs/PHASE/rentcar00_OPS-fine-notice-mvp-handoff-20260619.md`
   - 다음 세션 handoff 문서
   - 결정사항, 남은 작업, 다음 첫 행동, 건드리면 안 되는 영역을 정리한다.
6. `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
   - 남은 과태료 MVP 운영 반영 게이트 PM 문서
   - 다음 실행 후보: `pa fine-notice-next-p0`
7. `docs/PHASE/rentcar00_OPS-fine-notice-document-generation-mvp-pm.md`
   - 과태료 계약서 PDF 저장/문서생성 MVP PM 문서
   - 다음 실행 후보: `pa mvp-doc-runtime-contract-pdf`
8. `docs/PHASE/rentcar00_OPS-fine-notice-contract-search-boundary-correction-pm.md`
   - 과태료 계약검색 전용 endpoint와 PDF 저장 경계 정리 PM 문서
   - 남은 실행 후보: `pa workflow-integrity-db-apply`, parser restart, 실제 PDF 저장 smoke
9. `docs/PHASE/rentcar00_OPS-fine-notice-integrated-intake-to-submission-pm.md`
   - 과태료/주정차/통행료 임차인 변경 통합 PM 문서
   - 상태: 큰 phase map paused, 실전 MVP increment 모드
10. `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_b51_ui_parser_hotfix_pm.md`
   - b51/b52 UI/parser hotfix 완료 문서. 최신 APK는 b53 문서패키지 MVP 배포본이다.
11. `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_mvp_foundation_pm.md`
   - 기존 과태료 MVP foundation 로드맵 완료 문서
   - Phase 1-10 완료 상태로 닫았다.
12. `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_intake_policy_and_rollback_pm.md`
   - 과태료 intake 정책/롤백 기준 완료 문서
13. `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_gangnam_multi_parser_micro_pm.md`
   - 강남순환도로 4건 다중 row parser 5/5 검증 완료 문서
14. `docs/ARCHIVE/fine-notice-superseded-2026-06-19/`
   - 통합 PM으로 대체된 fine notice 과거 PM 문서 묶음
15. `docs/ARCHIVE/current-archive-2026-05-16/rentcar00_OPS-main.md`
   - 과거 main 기준 문서 archive. 현재 active 문서로 취급하지 않는다.

## 폴더 역할
- `docs/GOAL/`
  - 현재 목표 문서만 둔다.
- `docs/PHASE/`
  - 진행 예정/진행 중 phase 또는 PM 문서를 둔다.
  - 현재 fine notice active 구현 기준은 `docs/PHASE/README.md` 인덱스와 작은 MVP PM 문서다.
- `docs/COMPLETED/`
  - 완료 기능 단일 누적 문서를 둔다.
- `docs/ARCHIVE/`
  - 과거 설계 / 아이디어 / 스냅샷 / 구버전 문서 보관.

## 잠금 규칙
- 현재 목표는 `GOAL`에 둔다.
- 진행/예정 phase는 `PHASE`에 둔다.
- 완료 사실은 `COMPLETED`에 누적한다.
- 더 이상 안 쓰는 설계, 스냅샷, 아이디어 문서는 `ARCHIVE`로 보낸다.
- 새 분류 폴더를 늘리지 않는다.
