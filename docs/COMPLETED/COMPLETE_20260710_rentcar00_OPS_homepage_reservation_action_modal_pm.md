# 홈페이지 예약 상단 액션 모달 PM

## 0. 문서 정보
- 작성일: 2026-07-10
- 작성자/agent: OpenClaw rentcar00_ops_developer
- 상태: Draft
- 승인 범위: PM 문서 작성만 승인됨. 코드 수정/APK build/커밋은 아직 미승인.
- 관련 문서:
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md`
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-importer-normalization-pm.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
- 완료 후 문서명: `docs/COMPLETED/COMPLETE_20260710_rentcar00_OPS_homepage_reservation_action_modal_pm.md`
- 상태/정책문서 업데이트 대상:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - 필요 시 `docs/COMPLETED/rentcar00_OPS-completed.md`

## 1. 목적
- 목표:
  - 상단 홈페이지 확인 버튼/배지를 눌렀을 때 바로 홈페이지로 나가지 않고 선택 모달을 띄운다.
  - 선택지는 `홈페이지 진입`과 `예약확인` 두 개로 고정한다.
  - `예약확인`을 누르면 홈페이지 예약 pending 건만 카드 리스트로 보여주는 모달을 띄운다.
  - 카드에서 예약을 선택하면 해당 예약상세로 이동한다.
- 성공 기준:
  - pending 건수가 0이어도 홈페이지 진입 선택지는 유지된다.
  - pending 건수가 1건 이상이면 예약확인 선택지에서 홈페이지 예약 카드 리스트를 볼 수 있다.
  - 예약 카드 선택 시 `/reservation/{reservationId}` 상세로 이동한다.
  - 기존 홈페이지 pending 배지 count는 유지된다.
- 제외 범위:
  - 홈페이지 예약 importer 수정
  - 홈페이지 송신부 수정
  - FCM/OS 푸쉬
  - DB/schema 변경
  - parser restart/deploy
  - APK build/upload

## 2. 현재 상태
- 확인한 파일/docs:
  - `lib/app/view/app_shell.dart`
  - `lib/features/reservations/shared/providers/reservation_providers.dart`
  - `lib/app/router/app_routes.dart`
  - `lib/app/router/app_router.dart`
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md`
- 현재 git 상태:
  - branch: `fix/ops-return-complete-end-at`
  - latest commit: `2006e0f docs: record b54 APK release`
  - untracked:
    - `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md`
    - `docs/PHASE/rentcar00_OPS-ims-insurance-dispatch-return-action-issue-20260707.md`
    - `docs/PHASE/rentcar00_OPS-ims-insurance-longterm-dispatch-lifecycle-pm-20260707.md`
    - `output/`
- 기존 구현/문서 상태:
  - `AppShell` 상단 앱바에 `_HomepagePendingButton`이 있다.
  - 현재 버튼 클릭은 `homepageLauncherProvider(Uri.parse(rentcar00HomepageUri))`로 홈페이지를 바로 연다.
  - pending count는 `homepagePendingReservationsProvider`의 `checkPayload['homepage_review'] == 'pending'` 기준이다.
  - 예약상세 route는 `/reservation/:reservationId`이며 리스트/검색에서도 `context.push('/reservation/${item.reservationId}')`를 사용한다.
- 확인 필요:
  - 카드 표시 필드 우선순위: 고객명/전화/차량/대여일/반납일/예약번호.
  - `예약확인` 리스트가 empty일 때 문구와 홈페이지 진입 버튼을 같이 보여줄지 여부.

## 3. 전체 변경 요약
- 변경점:
  - 상단 홈페이지 버튼 onPressed를 바로 외부 링크 실행에서 액션 선택 모달 호출로 변경한다.
  - 액션 모달에 두 선택지 제공:
    1. 홈페이지 진입
    2. 예약확인
  - 예약확인 선택 시 홈페이지 pending 예약만 카드 리스트로 표시한다.
  - 예약 카드 선택 시 모달을 닫고 예약상세로 이동한다.
- 변경대상:
  - `lib/app/view/app_shell.dart`
  - 필요 시 새 파일: `lib/app/view/homepage_reservation_action_modal.dart`
- 예상 영향:
  - 상단 홈페이지 버튼 UX만 변경.
  - 예약 데이터, DB, importer, Realtime 구조 영향 없음.
- 주요 리스크:
  - 모달 중첩 처리 미흡 시 상세 이동 전 context가 dispose될 수 있음.
  - 카드 리스트가 길어질 경우 화면 overflow 가능.
  - 기존 버튼의 “바로 홈페이지 열기” 동작이 한 단계 늘어남.

## 4. Phase 목록

### Phase 1. 액션 모달 UX 기준 잠금
- 목적: 상단 버튼 클릭 후 선택 흐름을 명확히 고정한다.
- 변경점:
  - 기준만 확정. 코드 수정 없음.
  - 선택지:
    - `홈페이지 진입`: 기존 외부 홈페이지 열기 유지
    - `예약확인`: 홈페이지 pending 예약 카드 리스트 모달 열기
- 변경대상:
  - 문서/계획 기준. 코드 수정 없음.
- 실행방법:
  - 기존 `_HomepagePendingButton`의 역할을 “홈페이지 관련 액션入口”로 재정의한다.
  - pending count는 기존 provider 그대로 사용한다.
- 종료조건:
  - 버튼 클릭 UX와 모달 선택지가 확정됨.
- 검증방법:
  - 코드 흐름 inspection.
- 리스크:
  - 사용자가 홈페이지 바로가기를 기대하던 기존 습관이 바뀜.
- 되돌릴 방법:
  - 기존 바로 홈페이지 열기 정책으로 유지.
- 출력보고:
  - 최종 선택지, pending 0건 처리, 카드 필드 기준.

### Phase 2. 상단 액션 선택 모달 구현
- 목적: 상단 홈페이지 버튼 클릭 시 두 선택지를 보여준다.
- 변경점:
  - `_HomepagePendingButton.onPressed`에서 `showModalBottomSheet` 또는 `showDialog` 호출.
  - `홈페이지 진입` 선택 시 기존 `homepageLauncherProvider` 실행.
  - `예약확인` 선택 시 카드 리스트 모달로 연결.
- 변경대상:
  - `lib/app/view/app_shell.dart`
  - 필요 시 새 widget 파일
- 실행방법:
  - 액션 모달은 작고 단순한 2-button/list tile 구조로 구현한다.
  - 홈페이지 열기 실패 SnackBar는 기존 동작 유지.
- 종료조건:
  - 상단 버튼 클릭 시 선택 모달이 뜬다.
  - 홈페이지 진입 선택 시 기존처럼 외부 홈페이지가 열린다.
- 검증방법:
  - 정적 코드 확인.
  - `flutter analyze`.
  - 수동 시나리오: 버튼 클릭 → 홈페이지 진입 선택.
- 리스크:
  - `ScaffoldMessenger` context가 모달 context와 꼬일 수 있음.
- 되돌릴 방법:
  - onPressed를 기존 direct launcher로 원복.
- 출력보고:
  - 변경 파일, 모달 방식, 홈페이지 진입 동작 유지 여부.

### Phase 3. 홈페이지 예약 카드 리스트 모달 구현
- 목적: `예약확인` 선택 시 홈페이지 pending 예약만 카드로 보여준다.
- 변경점:
  - `homepagePendingReservationsProvider` 값을 모달에 전달하거나 모달 내부에서 watch한다.
  - pending 예약을 카드 리스트로 표시한다.
  - 카드 필드 후보:
    - 고객명
    - 전화번호
    - 차량번호/차량명
    - 대여일/반납일
    - 예약번호
    - `홈페이지 확인` badge
  - empty 상태에서는 `확인할 홈페이지 예약이 없습니다.` 표시.
- 변경대상:
  - `lib/app/view/app_shell.dart`
  - 필요 시 새 widget 파일
  - 필요 시 card formatting helper
- 실행방법:
  - bottom sheet 높이를 제한하고 `ListView`로 overflow 방지.
  - 카드 tap 시 먼저 모달을 닫고 `context.push('/reservation/${reservation.reservationId}')` 실행.
- 종료조건:
  - 홈페이지 pending 예약만 리스트에 표시된다.
  - 예약 선택 시 예약상세로 이동한다.
  - pending 0건 화면도 깨지지 않는다.
- 검증방법:
  - 정적 코드 확인.
  - `flutter analyze`.
  - 수동 시나리오: pending 0건, 1건, 여러 건, 카드 선택.
- 리스크:
  - 상세 이동 전 modal pop 순서가 틀리면 navigation 오류 가능.
  - provider loading/error 상태 처리 누락 가능.
- 되돌릴 방법:
  - 예약확인 선택지를 제거하거나 리스트 모달 코드 제거.
- 출력보고:
  - 카드 표시 필드, empty/loading/error 처리, 상세 이동 경로.

### Phase 4. 인앱알림 PM과 동선 연결 검토
- 목적: 앞서 만든 인앱알림 PM과 버튼/모달 동선이 충돌하지 않게 맞춘다.
- 변경점:
  - 인앱알림의 action 후보를 이 액션 모달 또는 예약확인 리스트로 연결할 수 있는지 검토한다.
  - 즉시 구현 범위는 상단 버튼 액션 모달로 제한하고, 알림 action 연결은 필요 시 별도 phase로 둔다.
- 변경대상:
  - `docs/PHASE/rentcar00_OPS-homepage-reservation-inapp-notification-pm-20260710.md` 검토 후보
  - 코드 변경은 승인 범위에 따라 제한
- 실행방법:
  - 중복 UI가 되지 않도록 “상단 버튼 = 홈페이지 관련 액션 허브” 기준을 유지한다.
- 종료조건:
  - 인앱알림과 상단 액션 모달 역할이 분리/연결 기준으로 정리됨.
- 검증방법:
  - 문서/코드 inspection.
- 리스크:
  - 두 PM을 동시에 구현할 때 action 중복 또는 문구 불일치 가능.
- 되돌릴 방법:
  - 인앱알림 action 연결은 제외하고 상단 버튼만 유지.
- 출력보고:
  - 인앱알림 PM과의 연결 여부, 제외/후속 여부.

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
  - diff 검수 → `flutter analyze` → 수동 시나리오 후보 확인 → 문서 업데이트 → PM COMPLETE 이동 → 커밋.
- 종료조건:
  - 승인된 phase가 모두 완료됨.
  - 검증 결과가 보고됨.
  - 문서 최신화 여부가 판단됨.
  - 커밋 해시가 보고됨. 단, 커밋 미승인 시 `커밋 제외`로 보고.
- 검증방법:
  - `git diff --check`
  - `flutter analyze`
  - 수동 시나리오: 홈페이지 진입, 예약확인 리스트, 예약상세 이동
- 리스크:
  - APK build/upload는 별도 승인 없이는 수행하지 않음.
- 되돌릴 방법:
  - 커밋 전 diff 원복 또는 커밋 revert.
- 출력보고:
  - 완료 phase, 변경 파일, 검증 결과, 완료 문서 경로, 커밋 여부, 남은 리스크.

## 5. 승인 및 중단 조건
- 승인 요청:
  - 이 문서는 PM 준비 문서이며, 코드 수정 실행 승인이 아니다.
  - 실행하려면 `홈페이지 예약 액션 모달 Phase 1부터 진행`처럼 phase 범위를 명시해 승인 필요.
- 중단 조건:
  - 기존 홈페이지 버튼 동선을 반드시 direct launch로 유지해야 한다는 결정이 생김.
  - 예약상세 navigation이 현재 라우터 구조와 충돌함.
  - protected target, DB schema, parser restart, APK build가 필요해짐.
- protected target 별도 승인 필요 여부:
  - `.env`, secret, runtime config 수정 없음.
  - Supabase schema/운영 DB 변경 없음.
  - parser restart/deploy 없음.
  - APK build/upload는 별도 승인 필요.

## 6. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- 완료 문서 경로:
- 상태/정책문서 업데이트:
- 커밋:
- 남은 리스크:
