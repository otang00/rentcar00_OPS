# rentcar00_OPS Realtime Refresh Call Volume Reduction PM

## 0. 문서 정보
- 작성일: 2026-08-03
- 작성자/agent: Codex
- 상태: Draft
- 승인 범위: OPS 앱 Realtime refresh 호출량 축소 준비 문서 작성만 승인됨. 코드 수정, DB 변경, APK, deploy, restart, commit은 미승인.
- 관련 문서:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - `docs/README.md`
  - `PROJECT_DOCUMENTATION_RULES.md`
- 관련 코드:
  - `lib/app/app.dart`
  - `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
  - `lib/features/reservations/shared/providers/reservation_providers.dart`
  - `lib/data/repositories/supabase_ops_repository.dart`
- 완료 후 문서명: `docs/COMPLETED/COMPLETE_20260803_rentcar00_OPS_realtime_refresh_call_volume_reduction_pm.md`

## 1. 목적
- 목표:
  - OPS 앱의 빠른 초기 로딩 구조는 유지한다.
  - Supabase Realtime 관련 호출량을 줄인다.
  - 데이터 변경 후 화면 반영 지연을 최소화한다.
- 성공 기준:
  - 앱 foreground 상태에서 예약/차량/일정 변경이 계속 자동 반영된다.
  - Realtime 구독 성공 자체가 전체 목록 재조회로 이어지지 않는다.
  - 이벤트가 온 테이블에 맞춰 필요한 provider만 refresh된다.
  - 현재 Supabase Realtime publication에 없는 테이블 구독으로 인한 retry/등록 낭비를 제거한다.
  - `flutter analyze`와 관련 테스트가 통과한다.
- 제외 범위:
  - Supabase DB publication 변경.
  - `.env`, secret, parser runtime, deploy/restart, APK build/upload.
  - OPS 전체 데이터 로딩 구조의 대형 리팩터링.
  - Booking/homepage 프로젝트의 sync/raw 적재 구조.

## 2. 현재 상태
- 확인한 파일/docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - `docs/README.md`
  - `lib/app/app.dart`
  - `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
  - `lib/features/reservations/shared/providers/reservation_providers.dart`
  - `lib/data/repositories/supabase_ops_repository.dart`
- 현재 git 상태:
  - branch: `fix/ops-return-complete-end-at`
  - `git status --short --branch` 기준 working tree 변경 없음.
- 기존 구현/문서 상태:
  - `Rentcar00OpsApp`가 `OpsRealtimeRefreshBridge`로 앱 전체를 감싼다.
  - Realtime bridge는 테이블별 channel을 생성한다.
  - Realtime 이벤트나 subscribe 성공 시 `allReservationsProvider`, `allStatusBoardRecordsProvider`, `reservationCancellationNoticesRawProvider`를 함께 invalidate한다.
  - AppShell은 예약 카운트, 차량/일정 카운트, 홈페이지 확인, 취소 알림을 동시에 watch한다.
  - 빠른 체감 로딩은 전역 provider cache와 앱 내부 필터링 구조에 의존한다.
- Supabase OPS 호출량 확인:
  - 통계 기준: `pg_stat_statements` reset `2026-05-08 02:55:21 UTC`, 확인 시점 `2026-08-03`, 약 86.88일 누적.
  - Realtime `realtime.list_changes`: 4,007,326 calls, 약 46,124 calls/day.
  - Realtime subscription registration: 102,849 calls, 약 1,184 calls/day.
  - OPS PostgREST/API table calls: 282,657 calls, 약 3,253 calls/day.
  - Auth schema DB calls: 252 calls, 약 2.9 calls/day.
  - Edge Functions: 없음.
  - 현재 `realtime.subscription` row는 0개로, 확인 순간 열린 구독은 없음.
  - `supabase_realtime` publication에는 `rc00_ops_cars`, `rc00_ops_reservation_states`, `rc00_ops_reservations`, `rc00_ops_schedules`만 있음.
  - 코드의 `_coreRealtimeTables`에는 `rc00_ops_reservation_events`가 포함되어 있으나 현재 publication에는 없음.
- Goal/State:
  - 현재 문서 기준 OPS는 실사용 앱이며, runtime/deploy/DB 변경은 별도 승인 대상이다.
- Harness:
  - Realtime/event flow, UI/API boundary, persisted state 관찰이 필요하다.
  - Harness 문서 수정은 이번 PM 실행 범위에는 기본 포함하지 않고, 구현 후 drift가 확인되면 Final Phase에서 필요 여부를 판단한다.
- 확인 필요:
  - Supabase Dashboard의 Realtime message/request 과금 그래프와 DB `pg_stat_statements` 수치의 정확한 청구 항목 매핑.
  - 취소 알림(`rc00_ops_reservation_events`)을 실시간으로 꼭 받아야 하는지, 아니면 앱 열기/resume/manual refresh 기준으로 충분한지.

## 3. 전체 변경 요약
- 변경점:
  - Realtime 구독 성공 시 전체 refresh를 제거한다.
  - Realtime callback을 테이블별 provider refresh로 분리한다.
  - stale channel callback과 정상 unsubscribe가 retry storm을 만들지 않도록 세대/generation guard를 둔다.
  - 현재 publication에 없는 `rc00_ops_reservation_events` 구독은 code-only 기본안에서 제거한다.
  - 앱 resume 시 refresh는 유지해, 앱을 다시 열 때 최신 상태를 받는다.
- 변경대상:
  - `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
  - 필요 시 `lib/features/reservations/shared/providers/reservation_providers.dart`
  - 필요 시 테스트 파일 추가 또는 보강.
- 예상 영향:
  - Realtime 내부 polling/list_changes 자체는 Supabase Realtime 서비스 특성상 완전 제거되지 않는다.
  - 구독 등록/재등록과 불필요한 전체 provider 재조회는 줄어든다.
  - 핵심 테이블 변경의 실시간 반영은 유지된다.
  - 취소 알림은 DB publication 변경 없이는 실시간 반영 대상에서 제외될 수 있다.
- 주요 리스크:
  - provider mapping 누락 시 특정 화면이 늦게 갱신될 수 있다.
  - `rc00_ops_reservation_events` 구독 제거로 취소 알림 즉시 반영 기대가 있으면 운영 체감이 바뀔 수 있다.
  - Supabase Realtime 과금 지표는 DB statement 호출만으로 완전히 검증하기 어렵다.

## 4. Phase 목록

### Phase 1. Realtime 구독/Retry 정상화
- 목적:
  - Realtime 구독 등록과 retry 관련 호출 낭비를 줄인다.
- 변경점:
  - `_coreRealtimeTables`를 현재 publication과 일치시킨다.
  - `rc00_ops_reservation_events`는 code-only 기본안에서 제거한다.
  - `subscribe` 성공 콜백에서 전체 refresh를 실행하지 않는다.
  - 정상 unsubscribe/old channel callback이 `_scheduleRetry()`로 이어지지 않도록 generation guard를 추가한다.
- 변경대상:
  - `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
- Scope Lock:
  - DB publication 변경 금지.
  - parser/restart/deploy/APK 금지.
  - Realtime 자체 제거 금지.
- 실행방법:
  - channel 생성 시 generation id를 캡처한다.
  - callback/status 처리 전 현재 generation인지 확인한다.
  - `closed`는 정상 해제일 수 있으므로, 기대한 close와 오류성 close를 구분한다.
  - `subscribed` 상태에서는 debug log만 남기고 강제 refresh하지 않는다.
- 종료조건:
  - 앱 최초 진입 시 Realtime 구독이 생성되지만 subscribe 성공만으로 목록 전체 재조회가 추가 발생하지 않는다.
  - publication에 없는 테이블 구독 시도가 없다.
  - dispose/force resubscribe 중 stale callback이 재시도 루프를 만들지 않는다.
- 검증방법:
  - `flutter analyze`
  - `flutter test`
  - 코드 inspection: `_scheduleRetry()`가 오류성 상태에만 제한되는지 확인.
- 리스크:
  - 구독 성공 직후 초기 데이터를 기대하던 숨은 경로가 있으면 초기 표시가 늦어질 수 있다.
  - 초기 데이터는 기존 FutureProvider watch가 담당하므로, 실사용 영향은 낮을 것으로 판단한다.
- 되돌릴 방법:
  - 해당 파일 변경분 revert.
- 출력보고:
  - 제거한 구독 테이블.
  - retry guard 방식.
  - subscribe 성공 refresh 제거 여부.

### Phase 2. 테이블별 Targeted Refresh 적용
- 목적:
  - 데이터 변경 이벤트는 유지하되, 매 이벤트마다 모든 provider를 refresh하지 않게 한다.
- 변경점:
  - `rc00_ops_reservations` 변경:
    - `allReservationsProvider` refresh.
    - `allStatusBoardRecordsProvider` refresh.
  - `rc00_ops_reservation_states` 변경:
    - `allReservationsProvider` refresh.
  - `rc00_ops_schedules` 변경:
    - `allReservationsProvider` refresh.
    - `allStatusBoardRecordsProvider` refresh.
  - `rc00_ops_cars` 변경:
    - `allStatusBoardRecordsProvider` refresh.
  - `reservationCancellationNoticesRawProvider`는 Realtime publication 없이 무조건 refresh하지 않는다.
- 변경대상:
  - `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
- Scope Lock:
  - 빠른 앱 내부 필터링 구조 유지.
  - 목록 조회 repository 대형 리팩터링 금지.
  - DB view/RPC 추가 금지.
- 실행방법:
  - refresh debounce를 provider group 기준으로 분리하거나, table event에서 필요한 provider만 invalidate한다.
  - 같은 짧은 시간 안에 같은 provider를 여러 번 invalidate하지 않도록 debounce를 유지한다.
- 종료조건:
  - 이벤트 테이블별 invalidate 대상이 명시적으로 분리된다.
  - 핵심 화면 카운트/목록/상세가 기존처럼 갱신된다.
- 검증방법:
  - `flutter analyze`
  - `flutter test`
  - 수동 inspection:
    - 예약 수정 후 예약 탭과 일정 탭에 반영되는 경로 확인.
    - 차량 상태 변경 후 일정/차량 탭에 반영되는 경로 확인.
- 리스크:
  - provider 간 암묵적 의존 관계를 놓치면 특정 badge/count가 늦게 갱신될 수 있다.
- 되돌릴 방법:
  - table-to-provider mapping 변경분 revert.
- 출력보고:
  - 테이블별 refresh mapping.
  - 유지한 실시간성.
  - 의도적으로 제외한 provider.

### Phase 3. 취소 알림 Refresh 정책 잠금
- 목적:
  - `rc00_ops_reservation_events`가 publication에 없는 상태에서 취소 알림을 어떻게 최신화할지 정책을 명확히 한다.
- 변경점:
  - 기본안:
    - 앱 open/resume/manual refresh 시 취소 알림을 갱신한다.
    - Realtime 구독 대상에는 넣지 않는다.
  - 선택안:
    - 취소 알림도 즉시 반영이 필요하면 별도 DB publication 변경 PM/phase로 분리한다.
- 변경대상:
  - 기본안: `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
  - 선택안: Supabase DB publication. 단, 이 PM의 기본 실행 범위에서는 제외.
- Scope Lock:
  - 기본 실행에서는 DB 변경 금지.
  - DB publication 추가가 필요하면 별도 승인 전 중단.
- 실행방법:
  - `didChangeAppLifecycleState(resumed)` 경로의 refresh는 유지한다.
  - manual pull-to-refresh 경로는 기존 화면 동작을 유지한다.
  - 취소 알림 실시간 필요성이 확인되면 문서에 별도 protected phase로 분리한다.
- 종료조건:
  - 취소 알림이 실시간 제외인지, DB 변경을 통해 실시간 포함할지 결정 기록이 남는다.
  - 기본안 실행 시 unsupported Realtime 구독이 없다.
- 검증방법:
  - 코드 inspection.
  - 앱 resume 시 refresh 대상에 취소 알림이 포함되는지 확인.
- 리스크:
  - DB 변경 없이 기본안을 선택하면 취소 이벤트 발생 직후 앱 foreground에서 즉시 보이지 않을 수 있다.
- 되돌릴 방법:
  - 기존 `_coreRealtimeTables` 구성을 복원하거나, 별도 승인 후 DB publication을 맞춘다.
- 출력보고:
  - 취소 알림 refresh 정책.
  - DB 변경 필요 여부.

### Final Phase. 검수·완료판정·문서 COMPLETE 변경·인덱스·커밋
- 목적:
  - 구현 완료 여부와 호출량 축소 기대치를 검수하고 문서를 닫는다.
- 변경점:
  - 구현 diff review.
  - `docs/PHASE/README.md` 인덱스 업데이트.
  - 필요 시 `docs/GOAL/rentcar00_OPS-current.md` 또는 HARNESS 문서 업데이트 후보 보고.
  - PM 문서를 `docs/COMPLETED/COMPLETE_20260803_rentcar00_OPS_realtime_refresh_call_volume_reduction_pm.md`로 이동 또는 완료 문서 생성.
  - 승인된 경우 commit.
- 변경대상:
  - 코드 변경 파일.
  - `docs/PHASE/README.md`
  - 완료 문서 경로.
- Scope Lock:
  - commit은 명시 승인 범위에 있을 때만 수행.
  - deploy/restart/APK/DB 변경은 별도 승인 없이는 제외.
- 실행방법:
  - `git diff` 검수.
  - `flutter analyze`, `flutter test` 결과 정리.
  - Realtime mapping과 취소 알림 정책을 완료 문서에 기록.
  - commit 승인 시 non-interactive git commit.
- 종료조건:
  - 검증 결과가 완료 보고에 포함된다.
  - 완료 문서 또는 완료 처리 방식이 정리된다.
  - commit 수행 또는 `커밋 제외`가 명시된다.
- 검증방법:
  - `flutter analyze`
  - `flutter test`
  - `git status --short`
- 리스크:
  - 로컬 테스트만으로 Supabase Dashboard 청구 지표 감소를 즉시 확정할 수 없다.
  - 운영 APK 배포 후 일정 시간 관찰이 필요하다.
- 되돌릴 방법:
  - commit 전: git diff 기반 revert.
  - commit 후: revert commit.
- 출력보고:
  - 변경 파일.
  - 검증 결과.
  - 남은 운영 관찰 항목.
  - commit 여부.

## 5. 승인 및 중단 조건
- 승인 요청:
  - 문서 작성 이후 실행하려면 사용자가 `pa`, `pa all`, `pa+mcg`, `cg7-pa-mcg`, `hold`, `replan` 중 하나를 명시한다.
- `pa` 의미:
  - Phase 1부터 하나씩 실행하고 각 phase 검증 후 보고한다.
- `pa all` 의미:
  - Phase 1-3과 Final Phase를 연속 실행한다. 단, DB/deploy/APK/restart/commit은 별도 명시가 없으면 제외한다.
- 중단 조건:
  - Realtime 변경 후 특정 화면 최신화 경로가 불명확해짐.
  - 취소 알림 실시간성이 필수로 확인되어 DB publication 변경이 필요함.
  - protected target 수정 필요 발생.
  - 테스트/분석 실패.
  - Supabase API/Realtime SDK 동작이 현재 코드 가정과 다름.
- protected target 별도 승인 필요 여부:
  - DB publication 변경: 별도 승인 필요.
  - `.env`, secret, runtime config: 별도 승인 필요.
  - parser restart/deploy/APK: 별도 승인 필요.
  - commit: 별도 승인 필요.

## 6. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- PROJECT_STATE 업데이트:
- 완료 문서 경로:
- phase index:
- 커밋:
- 남은 리스크:

## 7. 실행 승인 옵션

### Agent Recommendation
- 추천 실행 방식: `pa+mcg`
- 추천 이유:
  - 코드 변경 범위는 작지만 Realtime 최신화 체감과 직접 연결된다.
  - Phase별 실행 후 사후 검수로 누락 provider를 잡는 편이 안전하다.
- 위험도: 중간
- 필요한 검증:
  - `flutter analyze`
  - `flutter test`
  - Realtime bridge 코드 inspection
  - 운영 배포 후 Supabase Dashboard Realtime/API 지표 관찰
- protected target 여부:
  - 기본안은 protected target 없음.
  - 취소 알림 실시간화를 위해 DB publication 변경을 선택하면 protected target에 해당한다.

### User Selection
아래 중 하나를 사용자가 선택해야 실행한다.

- `pa`: Phase 1개씩 실행 후 보고
- `pa all`: 전체 Phase 연속 실행
- `pa+mcg`: 각 Phase 실행 후 MCG 검수
- `cg7-pa-mcg`: 각 Phase마다 사전 CG7, 실행 PA, 사후 MCG
- `cg7-pa-mcg+bigm`: 고위험/장기/운영 영향/누적 drift 작업
- `hold`: 실행 보류
- `replan`: PM 재작성
