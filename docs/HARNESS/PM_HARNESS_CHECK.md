# PM Harness Check

작성일: 2026-06-11  
대상: `rentcar00_OPS` OPS 앱 + reservation_ai_parser + 홈페이지 예약 이벤트 수신 경계  
현재 기준: 브랜치 `fix/ops-return-complete-end-at`, HEAD `f0ea3c1`, 앱 `1.0.0+49`

## 작업 요약

현재 시스템은 예약/차량/일정/직원/IMS/홈페이지 이벤트가 한 저장소와 Supabase 상태를 공유한다. 다음 기능 수정 전에는 상태 owner와 이벤트 흐름을 고정해야 한다.

현재 즉시 관련 작업 후보:
- 예약 상세 `상세정보` 표시 누락 수정
- b50 APK 배포
- 홈페이지 실제 송신부 확인
- 차량 그룹별 가격 정책 재설정

## 영향 범위

- 상태:
  - 예약 상태: `rc00_ops_reservations`, `rc00_ops_reservation_states`
  - 일정 상태: `rc00_ops_schedules`
  - 차량 상태: `rc00_ops_cars`
  - 직원/권한 상태: `rc00_ops_staff_accounts`, Supabase Auth
  - 외부 IMS 연결 상태: `rc00_ops_external_reservation_links`
  - 홈페이지 이벤트 상태: `rc00_ops_reservation_events`
  - 감사 로그: `rc00_ops_action_logs`
- 이벤트 흐름:
  - OPS 앱 사용자 command → Supabase 상태 변경 → Realtime refresh
  - 홈페이지 reservation.created event → parser 수신/검증 → Supabase 원장/일정 생성
  - OPS 앱 IMS command → parser → IMS API → OPS 외부링크/상태 갱신
- 런타임:
  - Flutter 앱
  - Supabase DB/Auth/Realtime
  - `reservation_ai_parser` Node 서버
  - Cloudflare Tunnel
  - IMS 외부 API
  - Google Drive APK 배포
- UI/API 경계:
  - Flutter UI는 repository method를 통해 상태 변경 command를 보낸다.
  - parser API는 외부 이벤트/IMS command를 받아 DB 또는 IMS API를 호출한다.
  - 홈페이지는 OPS 내부 상태를 직접 바꾸지 않고 signed event를 보내야 한다.
- live/replay/test 의미:
  - live: 운영 Supabase/IMS/홈페이지/GDrive
  - test: Flutter widget/unit test, parser simulate/check
  - replay: 홈페이지 event dedupe 재처리 가능성은 제한적이며 `event_id` 기준이다.

## 핵심 질문

- 새 상태를 만드는가:
  - 예약 상세 UI 수정은 새 상태 없음.
  - 가격 정책 재설정은 새 정책 상태 또는 기존 가격 필드 기준 변경 가능성이 있음.
  - 홈페이지 송신부 보강은 event 상태를 만들거나 재처리 정책을 바꿀 수 있음.
- 기존 상태를 바꾸는가:
  - 예약/일정/차량 lifecycle 작업은 기존 상태를 직접 변경한다.
  - APK 배포는 외부 배포 상태를 바꾼다.
- 상태 owner:
  - 예약/일정/차량: `SupabaseOpsRepository`가 앱 내 primary writer.
  - 홈페이지 이벤트 원장 생성: `reservation_ai_parser/src/server.js`가 writer.
  - IMS 외부 상태: IMS API가 owner, parser는 command adapter.
  - 직원 Auth: Supabase Auth와 staff tables가 분리되어 있음.
- 판단과 실행 혼재 여부:
  - repository method 안에서 tab/status 재계산과 DB update가 함께 수행된다.
  - parser server 안에서 HMAC 검증, dedupe 판단, Supabase insert가 함께 수행된다.
  - UI 일부 dialog flow에서 IMS 실패 후 unlink/change 같은 보상 판단이 포함된다.
- event / decision / command:
  - 홈페이지 `reservation.created`는 Event.
  - 탭 재계산은 Decision.
  - 배차완료/반납완료/차량변경/IMS 등록은 Command.
  - Realtime postgres change는 Event/Projection refresh trigger.
- runtime loop 영향:
  - Realtime bridge는 core table change를 debounce 후 provider invalidate한다.
  - parser는 request-response형이며 background queue는 확인되지 않음.
- UI/API 직접 상태 변경 여부:
  - UI는 Supabase client/repository를 통해 직접 DB command를 수행한다.
  - 관리자 차량관리 일부는 presentation에서 Supabase table insert/update/delete가 직접 보인다. 경계 혼재 후보.
- live/replay/test 의미 변화:
  - 홈페이지 event는 dedupe되지만 replay 정책이 문서상 제한적이다.
  - IMS command는 외부 live 상태 변경이라 replay 금지에 가깝다.

## 결론

- 예약 상세 `상세정보` UI 수정: 진행 가능
- APK 배포: 보완 후 진행
  - 기존 미커밋 변경 포함 여부를 먼저 확정해야 한다.
- 홈페이지 실제 상태 점검: 먼저 Event Flow Map 필요
- 차량 그룹별 가격 정책: 먼저 State Map 필요
  - 가격 정책 owner와 저장 위치가 아직 잠기지 않았다.

## 보완 필요 사항

1. 현재 미커밋 변경 3개 파일의 목적/포함 여부 확정
2. 홈페이지 실제 repo/URL/배포 플랫폼/예약 송신부 확인
3. 가격 정책 상태 owner 확정
4. 관리자 차량관리처럼 UI에서 DB를 직접 만지는 경로를 repository 경계로 정리할지 결정
5. IMS live command는 항상 승인/대상 확인 후 실행
