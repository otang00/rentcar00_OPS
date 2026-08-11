# Current UI/API Boundary Map

작성일: 2026-06-11  
생성 사유: 관리자 화면, 예약 상세, 홈페이지 event API, IMS adapter가 상태 변경을 많이 수행하므로 UI/API 경계가 개발 리스크에 직접 연결된다.

## Boundary: Flutter UI → SupabaseOpsRepository

- UI 역할:
  - 사용자 입력 수집
  - 확인 dialog 표시
  - command 호출
  - 결과/오류 표시
- Repository 역할:
  - DB table mutation
  - lifecycle decision
  - action log 기록
  - linked schedule/car/reservation 동기화
- 상태 변경 예:
  - 예약 생성/수정/취소
  - 차량변경
  - 일정 완료
  - 홈페이지 확인
  - 주차/관리정보 변경
- guardrail:
  - UI는 여러 테이블을 직접 순차 update하지 않는다.
  - lifecycle 변경은 repository method 하나로 묶는다.

## Boundary: Admin UI → AdminStaffRepository

- UI 역할:
  - 직원 목록/수정 입력
  - 관리자 action 요청
- Repository 역할:
  - staff table mutation
  - password display table upsert
  - action log 기록
- guardrail:
  - Auth 계정 상태와 staff table 상태를 구분한다.
  - password/credential 값은 문서화하지 않는다.

## Boundary: Admin Vehicle UI → Supabase

- 현재 상태:
  - `vehicle_management_page.dart`에서 `rc00_ops_cars` 직접 insert/update/delete 경로가 확인된다.
- 문제:
  - repository/action log/삭제 guard와 경계가 섞일 수 있다.
- 정리 방향:
  - 차량관리 command repository를 만들거나 기존 `SupabaseOpsRepository`로 이동.
  - 차량 삭제 전 예약/일정 연결 검증을 owner 쪽에 둔다.

## Boundary: Homepage → reservation_ai_parser

- 홈페이지 역할:
  - 예약 확정 event 생성
  - eventId/timestamp/signature 생성
  - payload POST
- Parser 역할:
  - HMAC/timestamp 검증
  - dedupe
  - payload mapping
  - Supabase 원장/상태/일정 생성
- guardrail:
  - 홈페이지는 OPS Supabase table을 직접 쓰지 않는다.
  - payload schema 변경 시 parser mapping/test를 같이 업데이트한다.

## Boundary: OPS 앱 → parser IMS API → IMS

- 앱 역할:
  - IMS command 의도 생성
  - payload 구성
  - 결과 표시/보상 선택
- Parser 역할:
  - IMS auth/API adapter
  - request transform
  - result normalize
- IMS 역할:
  - 외부 예약 상태 owner
- guardrail:
  - live command 중복 호출 방지
  - 실패 시 OPS link 상태와 IMS 실제 상태를 분리 확인

## Boundary: Supabase Realtime → Flutter Projection

- Realtime 역할:
  - table change event 전달
- Flutter 역할:
  - provider invalidate 후 재조회
- guardrail:
  - realtime event payload 자체를 source state로 쓰지 않는다.
  - 수동 refresh를 fallback으로 유지한다.
