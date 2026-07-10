# 홈페이지 예약 인앱알림 PM

## 0. 문서 정보
- 작성일: 2026-07-10
- 작성자/agent: OpenClaw rentcar00_ops_developer
- 상태: Draft
- 승인 범위: PM 문서 작성만 승인됨. 코드 수정/APK build/커밋은 아직 미승인.
- 관련 문서:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-importer-normalization-pm.md`
- 완료 후 문서명: `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_homepage_reservation_inapp_notification_pm.md`
- 상태/정책문서 업데이트 대상:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - 필요 시 `docs/COMPLETED/rentcar00_OPS-completed.md`

## 1. 목적
- 목표:
  - 앱이 실행 중일 때 홈페이지 예약이 새로 들어오면 사용자가 즉시 알 수 있는 인앱 알림을 띄운다.
  - FCM/OS 푸쉬 없이 현재 Supabase Realtime 기반 새로고침 흐름을 활용한다.
- 성공 기준:
  - 앱 foreground 상태에서 홈페이지 예약 pending 건수가 증가하면 알림이 1회 표시된다.
  - 기존 상단 홈페이지 확인 배지와 예약 데이터 refresh는 유지된다.
  - 앱 백그라운드/종료 상태 알림은 범위 밖임을 명확히 한다.
- 제외 범위:
  - Firebase/FCM 추가
  - OS push notification
  - 기기 token 저장
  - Supabase schema 변경
  - parser restart/deploy
  - 홈페이지 송신부 변경
  - APK build/upload

## 2. 현재 상태
- 확인한 파일/docs:
  - `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
  - `lib/app/view/app_shell.dart`
  - `lib/features/reservations/shared/providers/reservation_providers.dart`
  - `pubspec.yaml`
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
- 현재 git 상태:
  - branch: `fix/ops-return-complete-end-at`
  - latest commit: `2006e0f docs: record b54 APK release`
  - untracked:
    - `docs/PHASE/rentcar00_OPS-ims-insurance-dispatch-return-action-issue-20260707.md`
    - `docs/PHASE/rentcar00_OPS-ims-insurance-longterm-dispatch-lifecycle-pm-20260707.md`
    - `output/`
- 기존 구현/문서 상태:
  - `pubspec.yaml`에 `firebase_messaging`/`firebase_core` 없음.
  - 앱은 Supabase Realtime으로 핵심 테이블 변경을 감지한다.
  - Realtime 감지 테이블:
    - `rc00_ops_reservations`
    - `rc00_ops_reservation_states`
    - `rc00_ops_schedules`
    - `rc00_ops_cars`
  - Realtime 이벤트 발생 시 `allReservationsProvider`, `allStatusBoardRecordsProvider`를 invalidate한다.
  - 상단 앱바에는 `homepagePendingReservationsProvider` 기반 홈페이지 확인 배지가 이미 있다.
  - 홈페이지 pending 기준은 `checkPayload['homepage_review'] == 'pending'`이다.
- 확인 필요:
  - 알림 UI 형태: SnackBar, MaterialBanner, top overlay 중 선택.
  - 앱 시작 직후 기존 pending 건에 알림을 띄울지, 신규 증가분에만 띄울지 확정.

## 3. 전체 변경 요약
- 변경점:
  - 홈페이지 pending count 이전값/현재값을 비교하는 foreground 감지 로직 추가.
  - count가 증가한 경우 인앱 알림 표시.
  - Realtime refresh/상단 배지 기존 흐름은 유지.
- 변경대상:
  - `lib/app/view/app_shell.dart` 또는 별도 작은 widget/controller 파일
  - 필요 시 `lib/features/reservations/shared/providers/reservation_providers.dart`
- 예상 영향:
  - 앱 foreground UX만 변경.
  - DB/schema/parser/홈페이지 송신부 영향 없음.
- 주요 리스크:
  - 앱 첫 실행 시 기존 pending 건으로 불필요한 알림이 뜰 수 있음.
  - Realtime 재연결/refresh 중 같은 예약에 중복 알림이 뜰 수 있음.
  - count 감소/증가가 빠르게 반복될 때 알림 타이밍이 어색할 수 있음.

## 4. Phase 목록

### Phase 1. 인앱알림 기준점 잠금
- 목적: 알림이 뜨는 조건과 중복 방지 기준을 작게 고정한다.
- 변경점:
  - 코드 수정 전 기준만 확정.
  - 권장 기준: 앱 시작 시 기존 pending은 조용히 반영, 이후 pending count 증가분에만 알림.
- 변경대상:
  - 문서/계획 기준. 코드 수정 없음.
- 실행방법:
  - `homepagePendingReservationsProvider` count 증가 조건을 기준으로 삼는다.
  - 알림 문구 후보: `홈페이지 예약이 새로 들어왔습니다.`
- 종료조건:
  - 신규 증가분만 알림이라는 기준이 확정됨.
- 검증방법:
  - 코드 흐름 inspection.
- 리스크:
  - count 기반은 여러 건 동시 유입 시 상세 개별 알림이 아니라 묶음 알림이 됨.
- 되돌릴 방법:
  - 계획 취소. 코드 변경 없음.
- 출력보고:
  - 최종 알림 조건, 표시 문구, 제외 범위.

### Phase 2. Foreground 인앱알림 구현
- 목적: 앱 실행 중 홈페이지 예약 pending 증가를 감지해 알림을 띄운다.
- 변경점:
  - `AppShell` 또는 하위 전용 widget에서 `homepagePendingCountProvider`를 listen한다.
  - 이전 count와 현재 count를 비교한다.
  - `current > previous`이고 초기 로딩이 아닌 경우 SnackBar 또는 MaterialBanner 표시.
- 변경대상:
  - `lib/app/view/app_shell.dart`
  - 필요 시 새 파일: `lib/app/view/homepage_inapp_notification_listener.dart`
- 실행방법:
  - `ConsumerStatefulWidget` 또는 Riverpod listener로 count 변화 감지.
  - ScaffoldMessenger로 알림 표시.
  - 알림 action은 `홈페이지 확인` 또는 `예약 보기` 후보.
- 종료조건:
  - foreground 상태에서 홈페이지 pending count 증가 시 알림이 1회 표시된다.
  - 기존 홈페이지 확인 배지는 계속 정상 표시된다.
- 검증방법:
  - 정적 코드 확인.
  - `flutter analyze`.
  - 가능 시 provider 상태 변화에 대한 widget/unit 테스트 또는 수동 시나리오 확인.
- 리스크:
  - `AppShell` rebuild와 listener 위치가 맞지 않으면 중복 표시 가능.
- 되돌릴 방법:
  - listener widget/코드 제거.
- 출력보고:
  - 변경 파일, 알림 조건, 중복 방지 방식.

### Phase 3. UX 문구/중복 방지 보강
- 목적: 운영 중 거슬리지 않는 알림으로 다듬는다.
- 변경점:
  - 동시에 여러 건 증가 시 `홈페이지 예약 N건이 새로 들어왔습니다.` 표시.
  - 알림 duration/action 조정.
  - 필요 시 최근 알림 timestamp를 두어 짧은 시간 중복 표시를 줄인다.
- 변경대상:
  - Phase 2 구현 파일
- 실행방법:
  - count delta 기반 문구 분기.
  - SnackBar action으로 홈페이지 버튼과 같은 launcher 또는 예약 탭 이동 제공 후보.
- 종료조건:
  - 1건/복수건 문구가 자연스럽고, 빠른 refresh에도 과도하게 반복되지 않음.
- 검증방법:
  - 정적 확인.
  - `flutter analyze`.
  - 수동 시나리오: 0→1, 1→2, 2→1, 앱 재시작.
- 리스크:
  - action을 홈페이지 외부 링크로 연결하면 앱 내부 예약 확인보다 동선이 길 수 있음.
- 되돌릴 방법:
  - 문구/중복 방지 보강만 제거하고 Phase 2 기본 알림으로 복귀.
- 출력보고:
  - 최종 문구, action, 중복 방지 기준.

### Final Phase. 검수·완료판정·상태/정책문서 정리·문서 COMPLETE 변경·커밋
- 목적: 승인된 구현 후 검수, 완료판정, 문서 정리, 커밋을 마무리한다.
- 변경점:
  - 전체 변경 검수
  - 완료판정
  - 상태변경/정책변경 여부 판단
  - `docs/GOAL/rentcar00_OPS-current.md`, `docs/PHASE/README.md`, 필요 시 `docs/COMPLETED/rentcar00_OPS-completed.md` 업데이트
  - PM 문서를 완료 위치로 이동 또는 이름 변경
  - 파일명에 `COMPLETE_20260710` 반영
  - 최종 커밋
- 변경대상:
  - 승인된 코드 파일
  - 관련 docs
- 실행방법:
  - diff 검수 → `flutter analyze` → 필요 시 테스트/수동 시나리오 → 문서 업데이트 → PM COMPLETE 이동 → 커밋.
- 종료조건:
  - 승인된 phase가 모두 완료됨.
  - 검증 결과가 보고됨.
  - 문서 최신화 여부가 판단됨.
  - 커밋 해시가 보고됨. 단, 커밋 미승인 시 `커밋 제외`로 보고.
- 검증방법:
  - `git diff --check`
  - `flutter analyze`
  - 가능 시 앱 foreground 수동 smoke
- 리스크:
  - APK build/upload는 별도 승인 없이는 수행하지 않음.
- 되돌릴 방법:
  - 커밋 전 diff 원복 또는 커밋 revert.
- 출력보고:
  - 완료 phase, 변경 파일, 검증 결과, 완료 문서 경로, 커밋 여부, 남은 리스크.

## 5. 승인 및 중단 조건
- 승인 요청:
  - 이 문서는 PM 준비 문서이며, 코드 수정 실행 승인이 아니다.
  - 실행하려면 `홈페이지 인앱알림 Phase 1부터 진행`처럼 phase 범위를 명시해 승인 필요.
- 중단 조건:
  - 인앱알림만으로는 요구사항을 만족하지 못하고 OS 푸쉬가 필요해짐.
  - Realtime 이벤트가 홈페이지 예약 생성 시 안정적으로 들어오지 않는 증거 발견.
  - protected target, Firebase 설정, DB schema, parser restart, APK build가 필요해짐.
- protected target 별도 승인 필요 여부:
  - `.env`, secret, runtime config 수정 없음.
  - Supabase schema/운영 DB 변경 없음.
  - Firebase/FCM 설정 없음.
  - APK build/upload는 별도 승인 필요.

## 6. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- 완료 문서 경로:
- 상태/정책문서 업데이트:
- 커밋:
- 남은 리스크:
