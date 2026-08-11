# Current State Map

작성일: 2026-06-11  
대상: `rentcar00_OPS`

## 상태: 예약 원장

- 의미: 고객 예약의 기준 기록. 고객/차량/금액/배차/반납/메모/상태의 중심 상태.
- 저장 위치: `rc00_ops_reservations`
- owner: Supabase DB. 앱 내 primary writer는 `SupabaseOpsRepository`.
- reader: 예약 탭, 검색, 예약 상세, 차량 상세 연관 일정, parser event importer.
- writer:
  - OPS 앱 예약 생성/수정/취소/차량변경
  - 홈페이지 이벤트 importer
  - 반납완료 lifecycle 처리
  - IMS import 생성 경로
- 생성 조건:
  - OPS 앱 직접 생성
  - 차량 상세에서 예약 생성
  - 홈페이지 `reservation.created` event 수신
  - IMS 가져오기 결과 저장
- 변경 조건:
  - 예약 수정
  - 차량변경
  - 배차/반납 lifecycle
  - 예약취소
  - 예약번호 보정
- 종료 조건:
  - `예약취소`
  - `완료` 또는 completed tab
- 관련 이벤트:
  - reservation.created
  - reservation.updated
  - reservation.cancelled
  - schedule.dispatch_completed
  - schedule.return_completed
- 혼재 지점:
  - 예약 상태와 탭 상태가 별도 테이블/derived decision으로 공존한다.
  - 반납완료는 일정/예약/차량을 함께 바꾼다.

## 상태: 예약 탭/체크/주의 상태

- 의미: 예약을 어떤 운영 탭과 배지로 볼지 결정하는 projection/control 상태.
- 저장 위치: `rc00_ops_reservation_states`
- owner: OPS 앱 repository 및 홈페이지 event importer.
- reader: 예약 목록, 예약 상세, 홈페이지 확인 배지.
- writer:
  - 예약 생성/수정
  - lifecycle 처리
  - 홈페이지 확인 처리
  - 예약취소
- 생성 조건: 예약 생성과 함께 생성.
- 변경 조건: 상태 재계산, 홈페이지 확인, 체크 payload 변경.
- 종료 조건: 예약 종료/취소 후 completed tab.
- 관련 이벤트:
  - homepage.reviewed
  - lifecycle.recalculated
- 혼재 지점:
  - 저장된 `tab_key`와 runtime 재계산 `_deriveReservationTabKey`가 같이 존재한다.

## 상태: 일정

- 의미: 배차/반납/기타 일정 카드와 차량/예약 연결 상태.
- 저장 위치: `rc00_ops_schedules`
- owner: OPS 앱 repository, 홈페이지 event importer.
- reader: 현황판, 일정 탭, 차량 상세, 예약 상세 연결 일정.
- writer:
  - 예약 생성 시 배차/반납 일정 자동 생성
  - 일정 생성/수정/삭제
  - 배차/반납 완료
  - 예약 차량변경/시간변경 동기화
- 생성 조건:
  - 예약 생성
  - 수동 일정 생성
  - 홈페이지 예약 event
- 변경 조건:
  - 일정 수정
  - 차량변경
  - 위치/시간 수정
  - 완료 처리
- 종료 조건:
  - 일정 완료
  - 일정 삭제
  - 예약취소 시 연결 일정 취소 처리
- 관련 이벤트:
  - schedule.created
  - schedule.updated
  - schedule.completed
  - schedule.deleted
- 혼재 지점:
  - 일정 완료 command가 예약 lifecycle과 차량 상태까지 함께 변경한다.

## 상태: 차량

- 의미: 차량번호/차종/상태/주차/세차/수리/관리정보의 기준 상태.
- 저장 위치: `rc00_ops_cars`
- owner: OPS 앱. 관리자 차량관리 일부 UI가 직접 writer.
- reader: 현황판, 예약 생성/수정, 일정 생성, 차량 상세, 검색.
- writer:
  - 차량관리 add/edit/delete
  - 즉시 상태 변경
  - 배차/반납 완료 lifecycle
  - 주차지/관리정보 수정
- 생성 조건: 관리자 차량 추가 또는 DB 초기 데이터.
- 변경 조건: 관리자 수정, lifecycle 처리, 상태수정.
- 종료 조건: 차량 삭제 또는 운영 제외 처리. 명시적 archive 상태는 확인 필요.
- 관련 이벤트:
  - car.created
  - car.updated
  - car.status_changed
  - car.deleted
- 혼재 지점:
  - 홈페이지 차량 데이터와 동기화 기준이 확인되지 않았다.
  - UI presentation에서 Supabase write를 직접 수행하는 경로가 있다.

## 상태: 외부 IMS 연결

- 의미: OPS 예약과 IMS 예약/schedule/detail id의 연결 상태.
- 저장 위치: `rc00_ops_external_reservation_links`
- owner: OPS 앱 + parser IMS adapter.
- reader: 예약 상세 IMS 등록 정보, IMS 차량변경/삭제/반납완료 flow.
- writer:
  - IMS 등록 성공
  - IMS 가져오기
  - IMS unlink
  - IMS 삭제/변경 실패 보상 처리
- 생성 조건: IMS 예약 생성/가져오기 성공.
- 변경 조건: 차량변경, 삭제, unlink, 외부 id 보정.
- 종료 조건: unlink 또는 IMS 삭제 후 비활성 처리.
- 관련 이벤트:
  - ims.reservation_created
  - ims.reservation_linked
  - ims.vehicle_changed
  - ims.reservation_deleted
  - ims.return_completed
- 혼재 지점:
  - 외부 IMS 상태와 OPS 연결 상태가 분리되어 실패 보상이 필요하다.

## 상태: 홈페이지 예약 이벤트 inbox

- 의미: 홈페이지에서 발생한 예약 생성 event의 수신/중복/처리 상태.
- 저장 위치: `rc00_ops_reservation_events`
- owner: `reservation_ai_parser/src/server.js`
- reader: parser dedupe/import logic, 운영 점검.
- writer: parser reservation event endpoint.
- 생성 조건: signed `reservation.created` 요청 수신.
- 변경 조건: imported/deduped/error 상태 갱신.
- 종료 조건: imported 완료 또는 실패 기록. 재처리 정책은 확인 필요.
- 관련 이벤트:
  - homepage.reservation_event_received
  - homepage.reservation_imported
  - homepage.reservation_deduped
- 혼재 지점:
  - 홈페이지 송신부 구현/배포 상태가 현재 작업공간에 없다.

## 상태: 직원/권한

- 의미: OPS 앱 접근 권한, 직원 활성상태, 관리자 화면 제어.
- 저장 위치:
  - Supabase Auth
  - `rc00_ops_staff_accounts`
  - `rc00_ops_staff_passwords`
- owner: Supabase Auth + 관리자 기능.
- reader: 로그인 gate, 관리자 직원관리, action log.
- writer: 관리자 직원관리, Auth 관리 경로.
- 생성 조건: 직원 추가/계정 생성.
- 변경 조건: 권한/활성/비밀번호/활동정보 변경.
- 종료 조건: 비활성화 또는 삭제.
- 관련 이벤트:
  - staff.updated
  - staff.password_updated
  - staff.activity_marked
- 혼재 지점:
  - Auth 비밀번호와 앱 표시용 비밀번호 기준 혼동 가능성이 있다.

## 상태: 감사 로그

- 의미: 누가 언제 어떤 운영 action을 수행했는지 남기는 append-only 성격의 로그.
- 저장 위치: `rc00_ops_action_logs`
- owner: OPS 앱 repository/admin repository.
- reader: 관리자 작업로그, 예약 상세 업무 로그.
- writer: 각 command 완료 후 `recordActionLog`.
- 생성 조건: 예약/차량/일정/직원 주요 command 수행.
- 변경 조건: 원칙상 변경보다 append 중심. 수정/삭제 정책 확인 필요.
- 종료 조건: 없음. 보존 정책 확인 필요.
- 관련 이벤트:
  - action.logged
- 혼재 지점:
  - 로그 실패는 원 업무를 막지 않도록 설계되어 누락 가능성이 있다.

## 상태: APK 배포물

- 의미: 직원이 설치하는 Android arm64 release APK 최신본.
- 저장 위치: 로컬 `build/releases/`, 원격 `gdrive:rentcar00_OPS/apk/`
- owner: 배포 작업자.
- reader: 설치 사용자, 운영 배포 확인.
- writer: Flutter build + rclone upload/delete.
- 생성 조건: versionCode 증가 후 release build.
- 변경 조건: 새 APK 업로드, 과거 APK 정리.
- 종료 조건: 더 최신 APK로 대체.
- 관련 이벤트:
  - apk.built
  - apk.uploaded
  - apk.superseded
- 혼재 지점:
  - 현재 미커밋 변경이 있으면 어떤 코드가 APK에 포함되는지 모호해질 수 있다.
