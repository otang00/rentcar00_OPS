# rentcar00_OPS 3개 PM 번들 실행 준비

## 0. 문서 정보
- 작성일: 2026-07-10
- 작성자/agent: OpenClaw rentcar00_ops_developer
- 상태: Draft / Bundle execution ready
- 승인 범위: 번들 실행 준비 문서 작성만 승인됨. 코드 수정, 문서 COMPLETE 이동, 커밋은 아직 미실행.
- 대상 PM 문서:
  1. `docs/PHASE/rentcar00_OPS-ims-insurance-longterm-dispatch-lifecycle-pm-20260707.md`
  2. `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md`
  3. `docs/PHASE/rentcar00_OPS-homepage-reservation-action-modal-pm-20260710.md`
- 관련 이슈 문서:
  - `docs/PHASE/rentcar00_OPS-ims-insurance-dispatch-return-action-issue-20260707.md`
- 완료 후 문서명: `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_three_pm_bundle_execution_plan.md`

## 1. 목적
- 목표:
  - 세 PM 문서를 한 번에 섞어 구현하지 않고, 문서 1개씩 순서대로 실행한다.
  - 각 PM마다 `실행 → 완료판정 → 문서 COMPLETE 처리 → 커밋`을 끝낸 뒤 다음 PM으로 넘어간다.
- 성공 기준:
  - 각 PM의 변경 범위와 커밋이 분리된다.
  - 이전 PM 검증/커밋 전에는 다음 PM 코드 수정에 들어가지 않는다.
  - 실패 시 어느 PM/Phase에서 멈췄는지 명확하다.
- 제외 범위:
  - 운영 DB backfill
  - Supabase schema 변경
  - parser restart/deploy
  - APK build/upload
  - Firebase/FCM
  - 외부 서비스 write

## 2. 현재 상태
- branch: `fix/ops-return-complete-end-at`
- latest commit: `2006e0f docs: record b54 APK release`
- 현재 untracked:
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-action-modal-pm-20260710.md`
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md`
  - `docs/PHASE/rentcar00_OPS-ims-insurance-dispatch-return-action-issue-20260707.md`
  - `docs/PHASE/rentcar00_OPS-ims-insurance-longterm-dispatch-lifecycle-pm-20260707.md`
  - `output/`
- 주의:
  - `output/`은 이번 번들 커밋 대상에서 제외한다. 필요 시 별도 확인 후 처리한다.
  - 세 PM 문서는 아직 Draft/untracked이므로 각 PM 완료 커밋에 문서 이동/정리까지 포함한다.

## 3. 번들 실행 순서

### Bundle Step 1. IMS 보험배차/장기 배차 lifecycle PM
- 대상 문서: `docs/PHASE/rentcar00_OPS-ims-insurance-longterm-dispatch-lifecycle-pm-20260707.md`
- 이유:
  - 데이터 lifecycle/예약상세 버튼 조건에 직접 영향을 주는 가장 큰 변경이다.
  - 먼저 처리해야 이후 홈페이지 UI 변경과 섞이지 않는다.
- 실행 범위:
  - 배차완료 차량상태 정책 분리
  - 보험배차 IMS 가져오기 → 예약원장 생성 + 배차 자동완료
  - 장기 배차 상태 보존 정책 준비
  - 중복 방지 기준 적용
- 완료판정:
  - 일반 예약 배차완료는 기존처럼 차량상태 `일반` 유지
  - 보험배차 IMS 가져오기는 예약원장/배차/반납 일정 생성
  - 생성 직후 예약상태 `배차중`, 차량상태 `보험`, 예약상세 `반납완료` 표시 조건 충족
  - 중복 claim import 방지 기준 존재
- 검증:
  - `git diff --check`
  - `flutter analyze`
  - 관련 호출부 inspection
  - 가능 시 관련 테스트 실행
- 커밋:
  - 문서 COMPLETE 이동/정리 후 1개 커밋
  - 커밋 메시지 후보: `feat: normalize insurance dispatch lifecycle`
- 중단 조건:
  - 보험 claim id 저장 기준이 코드상 확정 불가
  - `returnAt` 누락/파싱 실패 처리 기준 불명확
  - 일반 예약 배차완료 regression 가능성 발견

### Bundle Step 2. 홈페이지 예약 인앱알림 PM
- 대상 문서: `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md`
- 이유:
  - Step 3의 상단 액션 모달과 연결되지만, 알림 발생 기준을 먼저 고정해야 한다.
- 실행 범위:
  - 앱 foreground 상태에서 홈페이지 pending count 증가 감지
  - 신규 증가분에만 인앱알림 표시
  - 1건/복수건 문구와 중복 방지 보강
- 완료판정:
  - 앱 시작 시 기존 pending은 조용히 반영
  - 이후 pending count 증가 시 알림 1회 표시
  - 기존 상단 홈페이지 배지 유지
  - FCM/OS 푸쉬 미도입
- 검증:
  - `git diff --check`
  - `flutter analyze`
  - 수동 시나리오 후보: 0→1, 1→2, 2→1, 앱 재시작
- 커밋:
  - 문서 COMPLETE 이동/정리 후 1개 커밋
  - 커밋 메시지 후보: `feat: add homepage reservation in-app alert`
- 중단 조건:
  - Realtime refresh로 pending 증가 감지가 안정적으로 불가
  - 알림 구현에 FCM/OS 권한이 필요해지는 경우

### Bundle Step 3. 홈페이지 예약 상단 액션 모달 PM
- 대상 문서: `docs/PHASE/rentcar00_OPS-homepage-reservation-action-modal-pm-20260710.md`
- 이유:
  - Step 2 알림 이후 사용자가 눌러 확인할 실제 동선을 완성한다.
- 실행 범위:
  - 상단 홈페이지 배지/버튼 클릭 시 액션 모달 표시
  - 선택지 2개 고정: `홈페이지 진입`, `예약확인`
  - 예약확인 선택 시 홈페이지 pending 예약 카드 리스트 모달 표시
  - 카드 선택 시 예약상세 이동
- 완료판정:
  - 기존 홈페이지 외부 진입 동작은 선택지로 유지
  - 홈페이지 pending 예약만 카드 리스트에 표시
  - pending 0건 화면도 정상
  - 카드 선택 시 `/reservation/{reservationId}` 이동
- 검증:
  - `git diff --check`
  - `flutter analyze`
  - 수동 시나리오 후보: 홈페이지 진입, 예약확인 리스트, empty, 카드 선택 상세 이동
- 커밋:
  - 문서 COMPLETE 이동/정리 후 1개 커밋
  - 커밋 메시지 후보: `feat: add homepage reservation action modal`
- 중단 조건:
  - modal context/navigation 오류가 정적 점검 또는 테스트에서 발견
  - 기존 direct 홈페이지 버튼 유지가 필요하다는 결정 발생

## 4. 공통 실행 규칙
- 각 Step은 독립 커밋으로 끝낸다.
- 한 Step의 검증/완료판정/커밋 전 다음 Step 코드 수정 금지.
- 예상 밖 구조, protected target 필요, DB/schema/restart/APK 필요가 나오면 즉시 중단 후 보고한다.
- `output/`은 기본 커밋 제외.
- APK build/upload는 이 번들 범위 밖이다.

## 5. 최종 완료 기준
- Step 1, 2, 3 각각 커밋 완료.
- 각 PM 문서가 `docs/COMPLETED/COMPLETE_...` 규칙으로 이동 또는 이름 변경됨.
- `docs/GOAL/rentcar00_OPS-current.md`, `docs/PHASE/README.md`, 필요 시 `docs/COMPLETED/rentcar00_OPS-completed.md`가 최신화됨.
- 최종 보고에 각 커밋 해시, 검증 결과, 남은 리스크를 기록.

## 6. 승인 요청 문구
- 전체 번들 실행 승인 예:
  - `세 PM 번들 Step 1부터 Step 3까지 순서대로 실행, 각 Step 완료판정 후 커밋까지 진행`
- 부분 실행 승인 예:
  - `번들 Step 1만 실행하고 커밋까지 진행`
