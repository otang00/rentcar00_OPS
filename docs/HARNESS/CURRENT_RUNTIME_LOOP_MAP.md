# Current Runtime Loop Map

작성일: 2026-06-11  
생성 사유: OPS 앱은 Supabase Realtime, parser API, 외부 IMS API, APK 배포가 함께 얽혀 있어 runtime 경계가 개발 판단에 직접 영향을 준다.

## Runtime: Flutter OPS 앱

- 역할: 운영자 UI, projection 조회, command 발행
- 주요 진입:
  - 로그인 gate
  - 예약/현황판/검색/상세
  - 관리자 직원/차량/작업로그
- 상태 읽기:
  - Supabase query via providers/repository
- 상태 쓰기:
  - `SupabaseOpsRepository`
  - `AdminStaffRepository`
  - 일부 관리자 차량관리 UI 직접 Supabase write
- loop:
  - 사용자 action → Supabase write → provider invalidate/refresh
  - 앱 복귀 → refresh
- 실패 처리:
  - 화면별 snackbar/dialog 중심
- guardrail:
  - live DB command는 승인된 UI action에서만 수행
  - 긴급 수정 시 repository boundary 우선

## Runtime: Supabase Realtime Bridge

- 위치: `lib/shared/realtime/ops_realtime_refresh_bridge.dart`
- 역할: 핵심 테이블 변경 event를 projection refresh trigger로 변환
- 구독 테이블:
  - `rc00_ops_reservations`
  - `rc00_ops_reservation_states`
  - `rc00_ops_schedules`
  - `rc00_ops_cars`
- loop:
  - auth session 확인
  - channel subscribe
  - postgres change 수신
  - debounce 후 provider invalidate
  - channelError/timedOut/closed 시 재구독
- 실패 처리:
  - 2초 뒤 재구독
  - 앱 복귀 시 refresh
  - 수동 새로고침 유지
- guardrail:
  - realtime은 source of truth가 아니라 refresh trigger다.

## Runtime: reservation_ai_parser Node 서버

- 위치: `reservation_ai_parser/src/server.js`
- 역할:
  - AI 예약 원문 파서
  - IMS API adapter
  - 홈페이지 예약 event receiver
- 바인딩 기준:
  - `127.0.0.1:43110`
  - 외부 공개는 Cloudflare Tunnel
- 주요 endpoint:
  - `/health`
  - `/parse-reservation`
  - `/ims/*`
  - `/api/integrations/rentcar00/reservation-events`
- loop:
  - request 수신
  - 검증
  - 외부 API 또는 Supabase REST 호출
  - response 반환
- 실패 처리:
  - HTTP error response
  - event inbox error/dedupe 기준 일부 존재
- guardrail:
  - secret 값 문서화 금지
  - 운영 반영 후 launchd restart는 별도 승인 필요

## Runtime: 홈페이지 예약 이벤트 Producer

- 위치: 확인 필요
- 역할: 실제 서비스 홈페이지 예약 확정 시 `reservation.created` event 발행
- loop:
  - 예약 확정
  - payload 생성
  - timestamp/eventId/signature 생성
  - parser endpoint POST
- 실패 처리: 확인 필요
- guardrail:
  - 홈페이지는 OPS DB를 직접 쓰지 않는다.
  - HMAC secret은 양쪽 runtime config에서만 보관한다.

## Runtime: IMS 외부 API

- 위치: `https://api.rencar.co.kr`, `https://imsform.com` 관련 호출
- 역할: 외부 예약/차량/반납 상태 owner
- loop:
  - OPS command
  - parser adapter
  - IMS API 호출
  - 외부 id/result 수신
  - OPS link/update
- 실패 처리:
  - command별 error 반환
  - 일부 UI 보상 선택
- guardrail:
  - 테스트/replay 목적으로 live command 반복 호출 금지
  - 대상 예약 확인 후 실행

## Runtime: APK Build/Distribution

- 위치:
  - local: `build/releases/`
  - remote: `gdrive:rentcar00_OPS/apk/`
- 역할: Android arm64 release 배포
- loop:
  - versionCode 증가
  - test/build
  - release APK rename
  - GDrive upload
  - 최신 1개 확인
- 실패 처리:
  - 빌드 실패 시 업로드 중단
  - GDrive 확인 실패 시 완료 보고 금지
- guardrail:
  - 미커밋 변경 범위 확정 전 배포 금지
  - GDrive 외부 상태 변경은 명시 승인 필요
