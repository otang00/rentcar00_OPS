# Current Event Flow Map

작성일: 2026-06-11  
대상: `rentcar00_OPS`

## Event/Decision/Command: OPS 예약 생성

- 유형: Command
- 생성 위치: Flutter UI 예약 생성/차량 상세 예약 생성
- 처리 위치: `SupabaseOpsRepository.createReservationFromVehicle` 등 예약 저장 경로
- 결과 상태:
  - `rc00_ops_reservations` 생성
  - `rc00_ops_reservation_states` 생성
  - `rc00_ops_schedules` 배차/반납 2건 생성
  - `rc00_ops_action_logs` 기록
- 다음 흐름:
  - 예약/현황판 provider 갱신
  - Realtime event로 다른 기기 refresh
- 실패 기준:
  - Supabase insert 실패
  - 필수값 누락
- 재처리 기준:
  - 사용자가 다시 생성. 중복 방지 키는 예약번호/예약ID 기준 확인 필요.

## Event/Decision/Command: 홈페이지/sync 예약 생성 이벤트 수신

- 유형: Event
- 생성 위치:
  - 실제 빵빵카 홈페이지 예약 확정 flow
  - booking-system sync/orchestrator 외부 provider 예약 handoff
- 처리 위치: `reservation_ai_parser/src/server.js` `/api/integrations/rentcar00/reservation-events`
- 결과 상태:
  - `rc00_ops_reservation_events` 기록
  - HMAC/timestamp/eventId 검증
  - eventId 및 provider reservation id 기반 dedupe 판단
  - `rc00_ops_reservations` 생성 또는 기존 예약 reuse
  - `rc00_ops_reservation_states` 생성
    - 홈페이지: `homepage_review=pending`
    - 카모아/찜카: `provider_source`, `provider_check_status`, `{provider}_check_status`, `ims_create_status=not_started`
  - `rc00_ops_schedules` 배차/반납 2건 생성
  - `rc00_ops_action_logs`에 `reservation.sync_imported` 기록
- 다음 흐름:
  - 앱에서 홈페이지 또는 provider 확인 배지 표시
  - 직원이 예약 상세에서 확인 처리
  - IMS 예약등록은 기존 OPS `/ims/create-reservation` 경로 재사용 대상이며, 실제 IMS write는 별도 승인/실행 단계
- 실패 기준:
  - signature 불일치
  - timestamp 허용오차 초과
  - payload schema/필드 매핑 실패
  - 필수값 누락
  - Supabase insert 실패
  - provider reservation id dedupe 충돌
- 재처리 기준:
  - 같은 eventId는 dedupe 처리
  - 같은 `sourceProvider + sourceReservationId`는 같은 OPS reservation id로 매핑
  - 실패 event 재처리 정책은 확인 필요

## Event/Decision/Command: 홈페이지 예약 확인 처리

- 유형: Command
- 생성 위치: 예약 상세 UI `홈페이지확인`
- 처리 위치: `SupabaseOpsRepository.markHomepageReservationReviewed`
- 결과 상태:
  - `rc00_ops_reservation_states.check_payload_json.homepage_review` 갱신
  - action log 기록
- 다음 흐름:
  - 목록 배지 제거/변경
- 실패 기준:
  - reservation state row 없음
  - Supabase update 실패
- 재처리 기준:
  - 이미 reviewed면 idempotent 성격이어야 함. 실제 보장 확인 필요.

## Event/Decision/Command: 예약 정보 수정

- 유형: Command + Decision
- 생성 위치: 예약 상세 수정 dialog
- 처리 위치: `SupabaseOpsRepository.updateReservationAndLinkedSchedules`
- 결과 상태:
  - 예약 기본정보 업데이트
  - 연결 배차/반납 일정 시간/위치 업데이트
  - 현재 예약/일정 기준으로 tab 재계산
  - action log 기록
- 다음 흐름:
  - 예약 목록/현황판/차량 상세 projection 갱신
- 실패 기준:
  - 예약 row 없음
  - 연결 일정 update 실패
- 재처리 기준:
  - 마지막 저장값 기준으로 재수정

## Event/Decision/Command: 예약 차량변경

- 유형: Command
- 생성 위치: 예약 상세 차량변경 UI
- 처리 위치: `SupabaseOpsRepository.changeReservationVehicle`, IMS change flow
- 결과 상태:
  - 예약 차량번호/차종 변경
  - 연결 일정 차량번호/차종 변경
  - IMS 등록된 예약이면 IMS 차량변경 시도
  - action log 기록
- 다음 흐름:
  - 차량별 연관 일정/projection 변경
- 실패 기준:
  - IMS 변경 실패
  - Supabase update 실패
- 재처리 기준:
  - IMS 실패 시 unlink 후 원장만 변경 선택 가능
  - 보상 흐름은 예약별 확인 필요

## Event/Decision/Command: 배차완료

- 유형: Command + Decision
- 생성 위치: 예약 상세 또는 일정/차량 상세 완료 버튼
- 처리 위치: `SupabaseOpsRepository.completeSchedule` → `_updateReservationLifecycle`
- 결과 상태:
  - 배차 일정 완료
  - 예약 lifecycle/tab/status 갱신
  - 차량 상태 갱신
  - action log 기록
- 다음 흐름:
  - 예약이 배차중/반납일 등으로 이동
- 실패 기준:
  - schedule row 없음
  - linked reservation/car update 실패
- 재처리 기준:
  - 이미 완료된 일정 재완료 방지 기준 확인 필요

## Event/Decision/Command: 반납완료

- 유형: OPS Command
- 생성 위치: 예약 상세 또는 일정/차량 상세 완료 버튼
- 처리 위치:
  - OPS: `SupabaseOpsRepository.completeSchedule`
  - IMS: 호출하지 않음. IMS 연결 예약이면 확인 모달로 연결 정보를 보여준 뒤 OPS 일정만 완료한다.
- 결과 상태:
  - 반납 일정 완료
  - 예약 `완료`/completed tab
  - 예약 `end_at`을 실제 완료 처리 시각으로 갱신
  - 차량 상태 갱신
  - action log 기록
- 다음 흐름:
  - 완료 탭/projection 갱신
- 실패 기준:
  - OPS update 실패
- 재처리 기준:
  - OPS 반납완료 재처리 기준 확인 필요

## Event/Decision/Command: 예약취소

- 유형: Command
- 생성 위치: 예약 상세 취소 UI
- 처리 위치: `SupabaseOpsRepository.cancelReservation`, IMS delete flow
- 결과 상태:
  - 예약 상태 `예약취소`
  - reservation state completed tab
  - 연결 일정 취소 처리
  - IMS 등록 예약이면 IMS 삭제 command 가능
  - action log 기록
- 다음 흐름:
  - 완료 탭/검색/차량 캘린더 제외 기준 반영
- 실패 기준:
  - IMS 삭제 실패
  - Supabase update 실패
- 재처리 기준:
  - 이미 취소된 예약은 idempotent 처리 필요. 확인 필요.

## Event/Decision/Command: IMS 예약 등록

- 유형: Command
- 생성 위치: 예약 상세 IMS 등록 버튼
- 처리 위치:
  - Flutter `ImsReservationClient`
  - parser `/ims/create-reservation`
  - IMS API
- 결과 상태:
  - IMS 외부 예약 생성
  - `rc00_ops_external_reservation_links` upsert
- 다음 흐름:
  - 예약 상세 IMS 등록 정보 표시
  - 이후 차량변경/삭제/반납완료 연동 가능
- 실패 기준:
  - parser/IMS API 실패
  - 외부 id 조회 실패
  - link upsert 실패
- 재처리 기준:
  - 중복 IMS 예약 생성 위험. 등록 상태 확인 후 실행 필요.

## Event/Decision/Command: 차량 상태/관리정보 변경

- 유형: Command
- 생성 위치: 차량 상세/관리자 차량관리 UI
- 처리 위치: `SupabaseOpsRepository` 또는 차량관리 presentation 직접 Supabase write
- 결과 상태:
  - `rc00_ops_cars` 상태/주차/관리정보 변경
  - action log 기록 일부
- 다음 흐름:
  - 현황판/검색/차량 상세 갱신
- 실패 기준:
  - Supabase update 실패
- 재처리 기준:
  - 최신 차량 row 기준 재수정

## Event/Decision/Command: 직원관리 변경

- 유형: Command
- 생성 위치: 관리자 직원관리 UI
- 처리 위치: `AdminStaffRepository`
- 결과 상태:
  - `rc00_ops_staff_accounts` 갱신
  - `rc00_ops_staff_passwords` upsert 가능
  - action log 기록
- 다음 흐름:
  - 로그인/권한/projection 영향
- 실패 기준:
  - Auth와 staff table 불일치
  - Supabase update 실패
- 재처리 기준:
  - 직원별 상태 확인 후 재수정

## Event/Decision/Command: Core Realtime refresh

- 유형: Event → Projection refresh trigger
- 생성 위치: Supabase postgres changes
- 처리 위치: `OpsRealtimeRefreshBridge`
- 결과 상태:
  - Riverpod providers invalidate
  - 화면 projection 재조회
- 다음 흐름:
  - 예약/현황판/검색/상세 화면 갱신
- 실패 기준:
  - channelError/timedOut/closed
  - 로그인 전 구독 누락
- 재처리 기준:
  - 2초 뒤 재구독
  - 앱 복귀 시 refresh
  - 수동 당겨서 새로고침 유지

## Event/Decision/Command: APK 배포

- 유형: Command + External state change
- 생성 위치: 작업자 CLI
- 처리 위치:
  - `flutter build apk --release --target-platform android-arm64`
  - `rclone` upload/delete
- 결과 상태:
  - `build/releases/` APK 생성
  - `gdrive:rentcar00_OPS/apk/` 최신 APK 갱신
- 다음 흐름:
  - 직원 실기기 설치
- 실패 기준:
  - 테스트/빌드 실패
  - GDrive 업로드 실패
  - GDrive 최신 1개 확인 실패
- 재처리 기준:
  - versionCode와 commit/file name 기준으로 재빌드
