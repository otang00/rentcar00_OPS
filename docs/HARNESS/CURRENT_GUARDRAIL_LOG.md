# Current Guardrail Log

작성일: 2026-06-11  
대상: `rentcar00_OPS`

## Guardrails

### 기준: 상태 owner 분리
- owner:
  - 예약/일정/차량 운영 상태: Supabase DB + `SupabaseOpsRepository`
  - 홈페이지 예약 event 수신: `reservation_ai_parser`
  - IMS 외부 상태: IMS API
  - 직원 Auth: Supabase Auth
  - APK 배포 상태: GDrive release folder
- 허용되는 event/decision/command:
  - UI는 command 요청과 projection 조회를 담당한다.
  - repository는 DB state mutation과 lifecycle decision을 담당한다.
  - parser는 외부 event/IMS command adapter 역할을 담당한다.
- 금지되는 직접 변경:
  - 홈페이지가 Supabase 운영 테이블을 직접 쓰는 것 금지.
  - UI가 여러 테이블 lifecycle을 임의 순서로 직접 변경하는 것 지양.
  - IMS live command를 테스트/replay처럼 반복 호출 금지.

### 기준: Event/Command 구분
- owner: 각 외부/내부 boundary
- 허용되는 event/decision/command:
  - 홈페이지 `reservation.created`는 이미 발생한 Event로 기록 후 처리.
  - 배차완료/반납완료/차량변경/예약취소는 Command로 명시.
  - tab/status 계산은 Decision으로 문서화.
- 금지되는 직접 변경:
  - Event 처리 중 실패를 숨기고 부분 생성 상태를 정상으로 보고하는 것 금지.
  - Command 재시도 시 idempotency 확인 없이 외부 API 재호출 금지.

### 기준: 배포물 추적
- owner: 배포 작업자
- 허용되는 event/decision/command:
  - versionCode +1
  - arm64 release APK
  - 파일명 `rentcar00_ops-app-release-arm64-b<build>-<sha>.apk`
  - GDrive `rentcar00_OPS/apk/` 최신본 확인
- 금지되는 직접 변경:
  - 미커밋/범위 불명확 변경이 포함된 APK 배포 금지
  - APK zip 우회 금지
  - 승인 없는 GDrive 삭제/업로드 금지

### 기준: 운영 비밀/런타임 설정 보호
- owner: 운영자 승인
- 허용되는 event/decision/command:
  - secret 이름/필요성 문서화 가능
  - 값은 기록하지 않음
- 금지되는 직접 변경:
  - `.env`, secret, token, launchd, runtime config 승인 없는 수정 금지
  - secret 값을 문서/채팅/로그에 남기는 것 금지

## Violation: 관리자 차량관리 UI 직접 DB write

- 위치: `lib/features/admin/presentation/vehicle_management_page.dart`
- 현재 문제:
  - presentation layer에서 `rc00_ops_cars` insert/update/delete가 직접 보인다.
- 어긋난 기준:
  - UI는 command 요청만 하고 repository가 state mutation owner가 되는 경계.
- 위험:
  - action log 누락 또는 lifecycle guard 누락 가능
  - 차량 삭제 영향 검증이 화면별로 흩어질 수 있음
- 정리 방향:
  - 차량관리 repository command로 모으고, 삭제/수정 guard와 action log를 같은 owner에서 처리.
- 상태: 후보
- 다음 후보: 차량 삭제/수정 작업 전 별도 phase로 분리

## Violation: 예약 탭 상태 저장과 runtime 재계산 공존

- 위치: `rc00_ops_reservation_states.tab_key`, `_deriveReservationTabKey`
- 현재 문제:
  - 저장된 tab과 runtime decision이 함께 존재한다.
- 어긋난 기준:
  - projection state와 source state의 owner/우선순위가 명확해야 한다.
- 위험:
  - 특정 예약이 예상과 다른 탭에 보일 수 있음
  - 기존 데이터와 새 계산 기준이 충돌할 수 있음
- 정리 방향:
  - tab_key를 manual override인지 cache/projection인지 명확히 정의.
  - lifecycle command마다 재계산 기준을 문서화.
- 상태: 관찰 필요
- 다음 후보: 가격 정책보다 먼저 건드릴 필요는 낮음. 탭 이슈 발생 시 우선 정리.

## Violation: 홈페이지 실제 송신부 미확인

- 위치: 실제 서비스 중인 빵빵카 홈페이지
- 현재 문제:
  - OPS 수신부는 구현되어 있으나 홈페이지 repo/URL/송신 코드가 현재 작업공간에 없다.
- 어긋난 기준:
  - 외부 Event producer가 확인되어야 end-to-end flow를 완료로 볼 수 있다.
- 위험:
  - 홈페이지 예약이 OPS 원장에 들어오지 않거나 payload mismatch 가능
  - 가격/차량 정보가 홈페이지와 OPS에서 다를 수 있음
- 정리 방향:
  - 홈페이지 source/deploy/payload를 확인하고 Event Flow Map에 producer를 추가.
- 상태: 확인 필요
- 다음 후보: 홈페이지 운영 URL/저장소 확인

## Violation: 가격 정책 owner 미확정

- 위치: `docs/PHASE/rentcar00_OPS-vehicle-group-pricing-policy.md`, 홈페이지/OPS/IMS 가격 흐름
- 현재 문제:
  - 차량 그룹별 가격의 저장 위치와 owner가 잠기지 않았다.
- 어긋난 기준:
  - 가격은 예약 생성/홈페이지 이벤트/IMS import/정산에 영향을 주는 핵심 상태라 owner가 필요하다.
- 위험:
  - 앱/홈페이지/IMS 간 가격 불일치
  - 정산/매출 리포트 단계에서 데이터 보정 비용 증가
- 정리 방향:
  - 가격 정책 State Map을 먼저 확정하고, 그 후 구현 phase 진행.
- 상태: 먼저 State Map 필요
- 다음 후보: 차량 그룹/가격 원천 확정 문서

## Violation: IMS command와 OPS 상태 보상 흐름 복잡

- 위치: 예약 상세 IMS 등록/차량변경/삭제/반납완료 flow
- 현재 문제:
  - 외부 IMS 성공/실패와 OPS link 상태가 분리되어 보상 판단이 필요하다.
- 어긋난 기준:
  - external command는 idempotency와 실패 기준이 명확해야 한다.
- 위험:
  - IMS에는 변경됐지만 OPS link가 실패하거나, 반대로 OPS만 변경될 수 있음
  - 중복 생성/삭제/반납완료 호출 위험
- 정리 방향:
  - IMS command별 성공/실패/보상 표를 별도 phase에서 정리.
- 상태: 관찰 필요
- 다음 후보: IMS 장애 발생 시 command 보상표 작성

## Violation: 미커밋 변경 상태에서 배포 요청 가능

- 위치: 현재 작업트리
- 현재 문제:
  - `app_shell.dart`, `admin_home_page.dart`, `pubspec.yaml` 미커밋 변경이 존재한다.
- 어긋난 기준:
  - APK 배포는 포함 코드 범위가 명확해야 한다.
- 위험:
  - 의도하지 않은 변경이 APK에 포함될 수 있음
  - versionCode/문서/커밋 기준이 흔들릴 수 있음
- 정리 방향:
  - 변경 파일별 목적 확인 후 포함/제외/별도 커밋 결정.
- 상태: 즉시 확인 필요
- 다음 후보: b50 배포 전 git diff 분류
