# rentcar00_OPS Completed

이 문서는 `rentcar00_OPS`의 **완료 기능 단일 문서**다.
완료된 기능은 날짜순으로 누적하고, 각 항목마다 사용자 표면 / 실제 동작 / 핵심 파일 / 검증 / 1차 장애 확인 포인트를 남긴다.

---

## 2026-05-18 — 예약원장 배차대기 상태 기준 정리
### 사용자 표면
- 예약원장 기존 `오늘배차` 탭 명칭을 `배차대기`로 변경했다.
- 배차일이 지났더라도 배차 일정이 미완료이고 예약상태가 아직 `배차중/완료`가 아니면 `배차대기`에 남는다.
- 카드 배지는 `배차 지연`, `오늘 배차`, `배차 예정`, `반납 지연`, `오늘 반납`으로 상태를 구분한다.

### 실제 동작
- 예약원장 목록 조회 시 `rc00_ops_schedules`의 배차/반납 `schedule_done`과 `reservations.reservation_status`를 함께 읽어 탭을 재계산한다.
- 예약 수정 저장 후 배차/반납 일정 변경에 맞춰 `rc00_ops_reservation_states.tab_key`를 다시 계산해 갱신한다.
- `배차중` 상태에서 반납 일정이 오늘이거나 지났고 반납 미완료이면 `반납일`, 그 외 배차중은 `배차중`, 완료 상태는 `완료`로 분류한다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/reservations/shared/domain/reservation_tab.dart`
- `lib/features/reservations/list/presentation/reservation_tab_page.dart`
- `lib/features/reservations/shared/providers/reservation_providers.dart`
- `test/widget_test.dart`

### 검증
- `flutter analyze` 통과
- `flutter test` 통과
- `git diff --check` 통과

### 1차 장애 확인 포인트
1. 과거 미배차 예약이 많으면 `배차대기`가 예상보다 많이 보일 수 있다.
2. 기존 DB의 `reservation_status` 또는 `schedule_done` 값이 틀리면 탭도 그 상태값 기준으로 표시된다.

---


## 2026-05-17 — b35 APK 빌드/업로드 완료
### 사용자 표면
- IMS 반납완료 성공 API 수정과 `IMS 가져오기` 예약생성이 포함된 b35 APK를 실기기 설치 테스트할 수 있다.

### 실제 동작
- build number를 `34 → 35`로 올렸다.
- arm64 release APK를 빌드했다.
- gdrive `rentcar00_OPS/apk/`에 업로드했다.

### 산출물
- 기준 커밋: `39191a4 Add IMS import and return integration`
- APK: `rentcar00_ops-app-release-arm64-b35-39191a4.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`
- 업로드 확인 용량: `19,840,562 bytes`

### 검증
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `git diff --check` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b35-39191a4.apk` 확인

### 1차 장애 확인 포인트
1. 실기기에서 `IMS 가져오기` 조회/선택 UI가 모바일 화면에 맞게 보이는지
2. IMS 가져오기 후 OPS 예약 생성과 external link 저장이 정상인지
3. IMS 연결 반납완료 입력창에서 유류량/주행거리/유류비 입력 후 반납이 정상인지
4. 기존 `IMS연동생성` 체크 후 새 IMS 생성 흐름이 기존처럼 동작하는지

---


## 2026-05-17 — IMS 가져오기 예약생성 1차 구현
### 사용자 표면
- 예약생성 화면 상단에서 `AI파서` 옆 `IMS 가져오기` 버튼을 사용할 수 있다.
- 이름/차량번호/배차일로 기존 IMS 예약을 조회하고 1건을 선택하면 예약생성 폼이 자동 입력된다.
- 하단 체크박스는 기본 체크이며 문구는 `IMS연동생성`으로 보인다.

### 실제 동작
- `POST /ims/search-reservations` 조회 전용 endpoint를 추가했다.
- IMS 조회 결과에서 `scheduleId`, `detailId`, 고객명, 전화, 차량번호, 배차/반납일, 배차/반납지를 앱에 전달한다.
- IMS 가져오기 선택 후 저장하면 OPS 예약을 새로 만들고, IMS 새 생성 호출 없이 external link만 `linked`로 저장한다.
- 저장 기준은 `external_reservation_id=scheduleId`, `external_detail_id=detailId`다.

### 핵심 파일
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `lib/features/status_board/detail/data/reservation_ai_parser_client.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `docs/current/rentcar00_OPS-current.md`

### 검증
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter analyze` 통과
- local `POST /ims/search-reservations` smoke 조회 성공: `2026-05-17` 기준 2건 반환
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `git diff --check` 통과

### 1차 장애 확인 포인트
1. IMS 조회 결과의 차량번호가 OPS 차량 목록에 없으면 가져오기를 차단한다.
2. IMS 조회는 read-only지만, 실제 앱 저장 시 OPS DB에는 예약/link가 생성된다.
3. 추가 실기기 UI 확인과 APK 빌드는 아직 수행하지 않았다.

---


## 2026-05-17 — IMS 반납완료 연동 수정
### 사용자 표면
- 예약상세 `반납완료`와 반납 일정상세 `일정 완료`에서 IMS 연결 원장이 있으면 `IMS 반납 정보 입력` 창이 뜬다.
- 직원은 반납 유류량, 반납 주행거리, 유류비를 입력한 뒤 OPS 반납완료와 IMS 반납완료를 함께 시도할 수 있다.

### 실제 동작
- 중간서버 IMS 반납완료 호출을 실테스트 성공 endpoint인 `POST /v2/normal-contracts/{detail_id}/set-done`으로 변경했다.
- payload는 `done_at`, `return_gas_charge`, `driven_distance_upon_return`, `fuel_cost`를 보낸다.
- 서버는 주행거리와 유류비 누락을 invalid payload로 막는다.
- 앱은 `externalDetailId`를 우선 사용하고 없으면 `externalReservationId`를 fallback으로 사용한다.

### 핵심 파일
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `lib/features/reservations/detail/presentation/ims_return_input_dialog.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `docs/current/rentcar00_OPS-current.md`
- `/Users/otang_server/.openclaw/workspace/IMS_API_MANUAL.md`

### 검증
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `git diff --check` 통과

### 1차 장애 확인 포인트
1. 입력값이 실제 IMS 화면 기준과 다르면 IMS validation이 실패할 수 있다.
2. `externalDetailId`가 비어 있고 `externalReservationId`가 schedule id인 오래된 binding은 여전히 실패할 수 있다.
3. 이번 수정 후 추가 운영 IMS 재호출/실기기 APK 검증은 아직 수행하지 않았다.

---






## 2026-05-17 — b34 APK 빌드/업로드 완료
### 사용자 표면
- 일정상세 차량번호 확대, 예약상세 기능버튼 UI 정리, 관리자 메뉴 뼈대가 포함된 b34 APK를 실기기 설치 테스트할 수 있다.

### 실제 동작
- build number를 `33 → 34`로 올렸다.
- arm64 release APK를 빌드했다.
- gdrive `rentcar00_OPS/apk/`에 업로드했다.

### 산출물
- 기준 커밋: `5aa4e7c Add admin shell and action button UI`
- APK: `rentcar00_ops-app-release-arm64-b34-5aa4e7c.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`
- 업로드 확인 용량: `19,774,994 bytes`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b34-5aa4e7c.apk` 확인

### 1차 장애 확인 포인트
1. 실기기 설치 후 앱 실행이 정상인지
2. 일정상세 차량번호가 날짜보다 잘 보이는지
3. 예약상세 기능 버튼이 `상태 처리 / 관리 / 연락`으로 분리되어 보이는지
4. admin 계정에서 좌상단 `빵빵카` 클릭 시 관리자 홈으로 진입하는지
5. staff 계정에서 관리자 접근 차단 안내가 뜨는지

### 남은 주의점
- 관리자 홈의 개별 기능은 아직 placeholder다.
- 직원관리 MVP는 RLS/서버 Auth 생성 경로 결정 후 진행해야 한다.

---

## 2026-05-17 — 기능 버튼 UI + 관리자 메뉴 뼈대 완료
### 사용자 표면
- 일정상세에서 날짜 밑 차량번호가 더 크게 보여 빠르게 식별할 수 있다.
- 예약상세 기능 버튼이 `상태 처리 / 관리 / 연락` 영역으로 분리되어 상태 변경 버튼이 더 명확해졌다.
- 좌상단 `빵빵카`를 누르면 관리자 권한 계정만 관리자 홈에 진입할 수 있다.

### 실제 동작
- 일정상세 차량번호 badge를 `headlineSmall`급으로 키우고 padding/radius를 보정했다.
- 예약상세 `배차완료`/`반납완료`는 full-width lifecycle 버튼으로 분리했다.
- `수정`, `차량변경`, `IMS추가/IMS등록됨`은 관리 영역에 묶었다.
- `전화`, `문자`는 연락 영역에 묶었다.
- 배차/반납 확인 다이얼로그는 실제 변경 내용과 IMS 동시 처리 여부를 bullet로 보여준다.
- `AppRoutes.admin`과 `AdminHomePage`를 추가했다.
- `StaffAccount.isAdmin` 기준으로 admin만 관리자 홈에 진입한다.
- 관리자 홈의 직원관리/차량관리/작업로그/출근확인/앱푸시는 현재 placeholder다.

### 핵심 파일
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/app/view/app_shell.dart`
- `lib/app/router/app_routes.dart`
- `lib/app/router/app_router.dart`
- `lib/features/admin/presentation/admin_home_page.dart`
- `lib/features/auth/domain/staff_account.dart`
- `docs/current/rentcar00_OPS-current.md`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- `git diff --check` 통과

### 1차 장애 확인 포인트
1. 일정상세에서 차량번호가 날짜보다 살짝 크게 보이는지
2. 예약상세 배차/반납 버튼이 관리/연락 버튼과 분리되어 보이는지
3. 반납완료 확인창에서 IMS 동시 처리 여부가 보이는지
4. admin 계정은 `빵빵카` 클릭 시 관리자 홈으로 들어가는지
5. staff 계정은 관리자 접근 차단 안내가 보이는지

### 남은 주의점
- 관리자 홈의 개별 기능은 아직 placeholder다.
- 직원관리 MVP는 RLS/서버 Auth 생성 경로 결정이 필요하다.
- `rc00_ops_staff_accounts` 현재 RLS는 본인 row 조회만 허용하므로 직원 목록 기능 전 정책/서버 경로를 먼저 확정해야 한다.

---

## 2026-05-17 — b33 APK 빌드/업로드 완료
### 사용자 표면
- 예약상세 배차/반납 완료 버튼과 IMS 반납 연동이 포함된 b33 APK를 실기기 설치 테스트할 수 있다.

### 실제 동작
- build number를 `32 → 33`으로 올렸다.
- arm64 release APK를 빌드했다.
- gdrive `rentcar00_OPS/apk/`에 업로드했다.

### 산출물
- 기준 커밋: `b563520 Add reservation lifecycle IMS return`
- APK: `rentcar00_ops-app-release-arm64-b33-b563520.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`
- 업로드 확인 용량: `19,774,178 bytes`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b33-b563520.apk` 확인

### 1차 장애 확인 포인트
1. 실기기 설치 후 앱 실행이 정상인지
2. 예약상세 `배차완료`/`반납완료` 버튼 노출이 상태와 맞는지
3. 반납완료 후 OPS 차량/예약/일정 상태가 정상 갱신되는지
4. IMS active binding 예약 반납 시 IMS 성공/실패 안내가 정상인지

### 남은 주의점
- 실예약 IMS 반납완료 테스트는 수행하지 않았다.
- IMS 반납은 외부 상태 변경이므로 운영 예약은 대상 확인 후 진행한다.

---

## 2026-05-17 — 예약상세 배차/반납 완료 + IMS 반납 연동
### 사용자 표면
- 예약상세에서 상태에 따라 `배차완료` 또는 `반납완료` 버튼을 바로 사용할 수 있다.
- 일정상세/예약상세에서 반납완료 시 IMS active binding이 있으면 IMS 반납완료도 함께 시도하고 결과를 안내한다.

### 실제 동작
- 미배차 예약은 `배차완료`, 배차중 예약은 `반납완료` 버튼을 표시한다.
- 버튼 실행 전 확인 다이얼로그를 띄운다.
- 배차완료는 연결 배차 일정을 완료 처리하고 차량을 `일반`으로 전환한다.
- 반납완료는 연결 반납 일정을 완료 처리하고 차량을 `대기중`으로 전환한다.
- 중간서버 `POST /ims/complete-reservation-return`을 추가했다.
- 중간서버는 IMS `POST /v2/rent-contracts/{contractId}/return-gas-charge`를 호출한다.
- 앱은 IMS binding의 `externalDetailId`를 우선 contract id로 쓰고, 없으면 `externalReservationId`를 fallback으로 사용한다.

### 핵심 파일
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `docs/current/rentcar00_OPS-current.md`
- `IMS_API_MANUAL.md`

### 검증
- IMS Web 정적 소스에서 `POST /v2/rent-contracts/{contractId}/return-gas-charge` 확인
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- `git diff --check` 통과

### 1차 장애 확인 포인트
1. 예약상세 버튼 노출이 미배차/배차중 상태와 맞는지
2. 연결 일정이 없을 때 완료 처리하지 않고 안내하는지
3. 반납완료 후 차량이 대기중으로 복귀하는지
4. IMS active binding 예약에서 IMS 반납 성공/실패 snack 안내가 보이는지
5. IMS contract id가 `externalDetailId`에 없을 때 fallback이 맞게 동작하는지

### 남은 주의점
- 실예약 IMS 반납완료 테스트는 수행하지 않았다.
- OPS 빠른 반납 버튼에는 IMS 유류량/주행거리 입력 UI가 없어 현재 `returnGasCharge=100`, 주행거리 공백으로 호출한다.
- IMS 반납은 실제 외부 상태 변경이므로 운영 예약은 대상 확인 후 진행한다.

---

## 2026-05-17 — b32 APK 빌드/업로드 완료
### 사용자 표면
- 수리중/배차 UX + 예약상세 차량변경 + IMS 차량변경 연동이 포함된 b32 APK를 실기기 설치 테스트할 수 있다.

### 실제 동작
- build number를 `31 → 32`로 올렸다.
- arm64 release APK를 빌드했다.
- gdrive `rentcar00_OPS/apk/`에 업로드했다.

### 산출물
- 기준 커밋: `5b33dfc Add repair status and reservation vehicle change`
- APK: `rentcar00_ops-app-release-arm64-b32-5b33dfc.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`
- 업로드 확인 용량: `19,708,566 bytes`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b32-5b33dfc.apk` 확인

### 1차 장애 확인 포인트
1. 실기기 설치 후 앱 실행이 정상인지
2. 수리중/수리완료 UI가 의도대로 동작하는지
3. 배차 후 수정창 자동 오픈이 모바일에서 어색하지 않은지
4. 예약상세 차량변경에서 OPS 중복검증이 정상인지
5. IMS 연동 예약 차량변경 실패 분기가 정상인지

### 남은 주의점
- 실제 운영 IMS 예약 차량변경은 외부 상태 변경이므로 운영자가 대상 예약을 확인한 뒤 진행한다.

---

## 2026-05-17 — 수리중/배차 UX + 예약상세 차량변경 완료
### 사용자 표면
- 대기 차량을 `수리중`으로 전환해 대기탭에 남기되 배차불가 차량으로 어둡게 표시한다.
- 차량상세에서 입고공장 선택/추가 후 수리중 처리하고, 수리완료 시 확인 다이얼로그를 거쳐 대기중으로 복귀한다.
- 차량상세 배차 선택은 세차 다이얼로그와 비슷한 카드형 버튼 UI로 통일했다.
- 즉시 배차 후 해당 차량 상태 수정창을 바로 열어 시간/위치/상세를 이어서 보정할 수 있다.
- 예약상세에서 차량검색/선택 후 `차량 변경하시겠습니까?` 확인을 거쳐 예약 차량을 변경할 수 있다.

### 실제 동작
- `수리중` 차량은 `idle` 탭에 포함하되 배차 버튼 대신 배차불가 표시를 제공한다.
- 입고공장명은 기존 규칙대로 `parking_location`에 저장한다.
- 수리완료 시 차량 상태를 `대기중`으로 복귀시키고 수리 액션 상태를 초기화한다.
- 예약상세 차량변경은 OPS 원장 기준으로 대상 차량의 시간 중복을 먼저 검사한다.
- IMS active binding 예약은 IMS 차량변경 성공 후 OPS 원장/연결 일정을 변경한다.
- IMS 차량변경 실패 시 `연동 끊고 원장만 변경` 또는 `변경취소`를 선택한다.
- 중간서버는 `/ims/change-reservation-car`에서 IMS available 조회 후 `POST /v2/company-car-schedules/{schedule_id}`를 호출한다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `IMS_API_MANUAL.md`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- IMS 실예약 생성 → 차량변경 → 삭제 테스트 성공
  - 테스트 예약: `4189163`
  - detail id: `204340`
  - 차량: `101허4041 → 101허4014`

### 1차 장애 확인 포인트
1. 수리중 차량이 대기탭에 남되 어두운 배경/배차불가로 보이는지
2. 입고공장 직접추가 후 `parking_location`에 공장명이 남는지
3. 수리완료 후 대기중 복귀가 정상인지
4. 즉시 배차 후 수정창이 바로 열리는지
5. 예약상세 차량변경 시 OPS 중복 예약이 차단되는지
6. IMS 연동 예약에서 IMS 실패 시 연동해제/취소 분기가 정상인지

### 남은 주의점
- 실기기에서 수리중/차량변경 UI는 b32 설치 후 최종 확인해야 한다.
- IMS 차량변경은 외부 상태 변경이므로 테스트 예약 외 실제 예약 변경은 운영자가 확인 후 진행해야 한다.

---
## 2026-05-17 — b31 APK 빌드/업로드 완료
### 사용자 표면
- 상태보드 배차/세차/연결 일정 UX 보정분이 포함된 b31 APK를 실기기 설치 테스트할 수 있다.

### 실제 동작
- build number를 `30 → 31`로 올렸다.
- arm64 release APK를 빌드했다.
- gdrive `rentcar00_OPS/apk/`에 업로드했다.

### 산출물
- 기준 커밋: `8c18738 Fix status board quick actions UX`
- APK: `rentcar00_ops-app-release-arm64-b31-8c18738.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`
- 업로드 확인 용량: `19,708,318 bytes`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b31-8c18738.apk` 확인

### 1차 장애 확인 포인트
1. 실기기 설치 후 앱 실행이 정상인지
2. 대기 차량 배차/세차 UX가 b31에서 의도대로 보이는지
3. 예약 연결 일정 시간 수정이 실제 원장 시간과 함께 바뀌는지
4. b31 이후 새 작업인 `수리중/배차 UX 보정`과 혼동하지 않는지

### 남은 주의점
- `pubspec.yaml`의 build number `+31` 변경은 아직 커밋하지 않았다.
- 다음 구현 작업은 `docs/current/rentcar00_OPS-current.md`의 `상태보드 수리중/배차 UX 보정`이다.

## 2026-05-16 — 상태보드 배차/세차/연결 일정 UX 보정 완료
### 사용자 표면
- 대기 차량의 `배차` 버튼은 전체 수정 폼을 열지 않고 `보험 / 일반 / 장기` 선택만 보여준다.
- 배차 유형을 선택하면 현재 시각 기준으로 차량 상태가 즉시 배차 상태로 전환된다.
- `세차` 다이얼로그는 외부세차/실내세차를 누를 때 바로 닫히지 않고, 열린 상태에서 각각 켜고 끌 수 있다.
- 예약과 연결된 배차/반납 일정은 시간만 수정할 수 있다.
- 예약 연결 일정 카드는 연한 파란색으로 표시되어 단독 일정과 구분된다.

### 실제 동작
- 배차 빠른 전환은 기존 차량 row의 고객/전화/위치/메모 값을 유지하면서 상태와 배차 시작 시각만 갱신한다.
- 세차 토글은 다이얼로그 내부 상태를 즉시 갱신하고, 닫기는 `X` 또는 바깥 터치로 처리한다.
- `reservationId`가 있는 배차/반납 일정은 연결 일정으로 판단한다.
- 연결 일정 시간 수정 시 일정 row의 `schedule_at`과 예약 원장의 `start_at/end_at`을 함께 갱신한다.
- 연결 일정 시간 수정에서는 위치/상세/유형을 변경하지 않아 예약 원장 꼬임을 막는다.
- 단독 일정은 기존 일정 수정 다이얼로그를 그대로 사용한다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`

### 검증
- `dart format` 적용
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과

### 1차 장애 확인 포인트
1. 대기 차량에서 배차 선택 즉시 보험/일반/장기 탭으로 이동하는지
2. 배차 빠른 전환 후 기존 고객/전화/위치/메모가 불필요하게 비지 않는지
3. 세차 다이얼로그에서 외부/실내를 연속 토글할 수 있는지
4. 예약 연결 일정 수정에서 시간만 수정 가능한지
5. 연결 일정 시간 수정 후 예약 상세의 대여/반납 시간이 같이 바뀌는지

### 남은 주의점
- 이번 변경은 APK 빌드/업로드를 포함하지 않는다.
- 실기기 확인 후 배포하려면 build number를 올려 b31로 빌드/업로드해야 한다.

## 2026-05-16 — 입력 UX b30 APK 빌드/업로드 완료
### 사용자 표면
- 입력 UX 개선분이 포함된 b30 APK를 설치 테스트할 수 있다.

### 실제 동작
- build number를 `29 → 30`으로 올렸다.
- arm64 release APK를 빌드했다.
- gdrive `rentcar00_OPS/apk/`에 업로드했다.

### 산출물
- 커밋: `78dcd51 Bump Android build number to 30`
- APK: `rentcar00_ops-app-release-arm64-b30-78dcd51.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`
- 업로드 확인 용량: `19,708,190 bytes`

### 검증
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b30-78dcd51.apk` 확인

### 1차 장애 확인 포인트
1. 실기기 설치 후 앱 실행이 정상인지
2. 예약/일정 입력 formatter가 모바일 키보드에서 어색하지 않은지
3. IMS 등록 흐름이 기존처럼 동작하는지
4. 날짜만 입력한 예약/일정이 `10:00`으로 저장되는지

## 2026-05-16 — 예약/일정 입력 UX 공통 정리 완료
### 사용자 표면
- 전화번호 입력 중 자동 하이픈이 붙는다.
- 생년월일은 숫자 입력만으로 `YYYY-MM-DD` 형식이 된다.
- 배차/반납/일정 일시는 연도 prefix 기준으로 숫자를 입력하면 자동 포맷된다.
- 날짜만 입력한 예약성 일시는 `10:00`으로 보정된다.
- 기타 일정도 날짜만 입력하면 `10:00`으로 보정된다.

### 실제 동작
- 공통 입력 formatter를 `lib/shared/input/ops_input_formatters.dart`에 추가했다.
- 전화번호는 화면에서 하이픈 표시, 저장 시 숫자만 유지한다.
- 생년월일은 실제 날짜까지 완성된 값만 저장 허용한다.
- 예약수정에서 날짜만 바꾸면 기존 시간을 유지한다.
- 예약생성/즉시배차/일정 생성·수정에서 날짜만 입력하면 `10:00`을 붙인다.
- IMS payload 저장/검증 규칙은 변경하지 않았다.

### 핵심 파일
- `lib/shared/input/ops_input_formatters.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/shared/presentation/schedule_editor_dialog.dart`
- `test/ops_input_formatters_test.dart`

### 검증
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `git diff --check` 통과

### 1차 장애 확인 포인트
1. 실기기 키보드에서 자동 하이픈/날짜 포맷이 입력 흐름을 방해하지 않는지
2. 날짜만 입력 후 저장 시 화면과 저장값이 `10:00`으로 맞는지
3. 예약수정에서 날짜만 바꿀 때 기존 시간이 유지되는지
4. 기타 일정 날짜만 입력 시 `10:00`으로 저장되는지
5. IMS 체크 예약에서 전화번호 10~11자리 검증이 그대로 동작하는지

### 남은 주의점
- 최신 HEAD 기준 APK는 아직 빌드하지 않았다.
- 다음 APK는 build number 30으로 진행하는 것이 자연스럽다.

## 2026-05-16 — 예약/일정/차량 lifecycle + 상세 UX 정리 완료
### 사용자 표면
- 일정 완료/수정 시 연결 예약과 차량 상태가 함께 맞춰진다.
- 예약 상세에서 예약 내용을 수정할 수 있고, 연결 일정도 같이 갱신된다.
- 대기 차량 상세의 배차/세차/주차 기능이 단순해졌다.
- 예약 상세 기능카드 아래에 연결 일정 카드가 보이고, 카드를 누르면 해당 일정 상세로 이동한다.
- 카드 시간 화살표는 큰 단일 화살표 `↑/↓`로 보인다.

### 실제 동작
- 배차 일정 완료 시 예약 상태를 `배차중`, 예약 탭을 `in_use`로 갱신한다.
- 반납 일정 완료 시 예약 상태를 `완료`, 예약 탭을 `completed`로 갱신하고 차량을 대기중 기준으로 초기화한다.
- 일정 수정 시 배차/반납 일시와 위치를 연결 예약에 동기화한다.
- 예약 수정 저장 시 예약 row와 연결된 배차/반납 일정이 함께 갱신된다.
- 대기 차량 상세는 `배차` 단일 버튼 안에서 보험/일반/장기를 선택한다.
- `세차` 단일 버튼 안에서 외부세차/실내세차를 선택한다.
- 주차 직접추가 입력은 `직접추가` 버튼을 눌렀을 때만 표시된다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/reservations/list/presentation/reservation_tab_page.dart`

### 검증
- `flutter analyze` 통과
- `flutter test test/ims_reservation_payload_test.dart` 통과
- `git diff --check` 통과
- 관련 커밋:
  - `2ab57e3 Sync schedules with reservations on lifecycle changes`
  - `dd6998e Add reservation detail edit flow`
  - `5c5fe71 Phase 3 idle vehicle detail cleanup`
  - `3e056ae Polish reservation detail schedule UX`

### 1차 장애 확인 포인트
1. 배차 일정 완료 후 예약이 배차중 탭으로 이동하는지
2. 반납 일정 완료 후 예약이 완료 탭으로 이동하고 차량이 대기중으로 보이는지
3. 예약 수정 후 연결 일정의 날짜/위치가 함께 바뀌는지
4. 대기 차량 배차/세차/주차 UX가 실기기에서 어색하지 않은지
5. 예약 상세 연결 일정 카드 탭 시 올바른 일정 상세로 진입하는지

### 남은 주의점
- 최신 APK는 `b29-f5bd85c` 기준으로 업로드되어 있다.
- `3e056ae` UX 보정은 b29 업로드 이후 커밋이므로, 최신 HEAD 기준 APK는 아직 다시 빌드하지 않았다.


## 2026-05-16 — IMS API 직결 등록 + APK b28 재배포 완료
### 사용자 표면
- IMS 예약 생성이 브라우저 자동화가 아니라 Rencar API 직결 방식으로 동작한다.
- IMS 등록 중에는 `IMS 등록 진행중` 모달이 뜨고 다른 동작이 차단된다.
- 예약생성 폼 첫 입력칸 label이 위에서 잘리지 않도록 보정했다.
- 최신 arm64 release APK를 b28로 빌드해 gdrive 업로드까지 마쳤다.

### 실제 동작
- 중간서버 `/ims/create-reservation`은 `auth → available 조회 → company-car-schedules POST` 순서로 직접 IMS API를 호출한다.
- 기본 동작은 실제 저장이며, `dryRun=true`일 때만 저장을 생략한다.
- 직접 생성 API 응답이 `{ success: true }`만 반환하므로, 생성 후 목록 조회 fallback으로 `schedule_id/detail_id`를 확보한다.
- 실제 테스트 예약 생성/삭제를 완료했다.
  - 생성 IMS ID: `4187211`
  - detail ID: `204233`
  - 삭제 성공 후 상세 조회에서 `존재하지 않는 스케쥴입니다.` 확인

### 핵심 파일
- `reservation_ai_parser/src/server.js`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/reservations/detail/data/ims_reservation_payload.dart`
- `pubspec.yaml`
- `docs/current/rentcar00_OPS-current.md`

### 검증
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter test test/ims_reservation_payload_test.dart` 통과
- `flutter analyze` 통과
- 실제 IMS API 생성/삭제 테스트 성공
- `flutter build apk --release --target-platform android-arm64` 성공
- gdrive 업로드 확인
  - `rentcar00_ops-app-release-arm64-b28-ae24810.apk`

### 1차 장애 확인 포인트
1. 실기기에서 예약생성 + IMS 체크 시 진행중 모달이 보이는지
2. 완료 후 예약 상세에서 `IMS등록됨`과 IMS ID가 보이는지
3. 중복/가용차량 없음 케이스에서 내부 예약은 유지되고 `등록실패`가 보이는지
4. 예약생성 폼 첫 필드 label이 더 이상 잘리지 않는지
5. IMS 등록 후 실제 IMS 화면에도 예약이 생성되는지

## 2026-05-15 — 직원 로그인 1차 도입 + APK 재배포 완료
### 사용자 표면
- 앱 시작 시 직원 계정 로그인이 필요하다.
- 로그인 ID 는 내부적으로 `{login_id}@ops.00rentcar.local` alias email 로 변환된다.
- 승인된 staff meta row 가 있고 `is_active=true` 인 계정만 본문에 들어갈 수 있다.
- 로그아웃 버튼으로 즉시 로그인 화면으로 돌아갈 수 있다.
- 최신 arm64 release APK를 다시 빌드해 gdrive 업로드까지 마쳤다.

### 실제 동작
- Supabase Auth email/password 를 사용한다.
- `rc00_ops_staff_accounts` 로 직원 메타/활성 상태를 검증한다.
- hosted Auth 공개 signup 은 차단했고, email 로그인은 유지했다.
- 생성 완료 계정:
  - `rentcar00` / `오 태진` / `admin`
  - `rentcar0079` / `직원` / `staff`
  - `test001` / `직원` / `staff`

### 핵심 파일
- `lib/app/router/app_router.dart`
- `lib/app/router/app_routes.dart`
- `lib/app/view/app_shell.dart`
- `lib/features/auth/`
- `supabase/migrations/20260515111500_add_staff_accounts_and_auth_policies.sql`
- `supabase/config.toml`

### 검증
- `flutter analyze` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- Supabase remote migration 적용 확인
- hosted Auth 설정 확인
  - `disable_signup=true`
  - `external.email=true`
- 로그인 API 테스트 성공
- 공개 signup 요청 차단 확인 (`signup_disabled`)
- gdrive 업로드 확인
  - `rentcar00_ops-app-release-arm64-b19-594d9bf.apk`

### 1차 장애 확인 포인트
1. 실기기에서 로그인 화면이 먼저 뜨는지
2. `rentcar00`, `rentcar0079`, `test001` 로그인이 되는지
3. 로그아웃 후 본문 접근이 막히는지
4. 비활성 계정 전환 시 본문 진입이 차단되는지
5. `test001/test001` 비밀번호는 운영 전 교체할지

### 남은 주의점
- 커밋 전 빌드라 APK 파일명 sha 는 현재 HEAD `594d9bf` 기준이다.
- build number 는 여전히 `+19` 기준이라 재설치 전제다.
- `test001` 비밀번호는 테스트용으로 약하다.

## 2026-05-15 — latest raw 재구성 + 기타 일정 반영 + 일정 수정 + 주차지 선택형 완료
### 사용자 표면
- 최신 시트 기준으로 정리된 예약/일정/차량 projection 이 다시 반영된다.
- 일정탭에서 `기타` 일정이 초록 `!` 상태로 보인다.
- 일정 상세에서 `수정` 액션을 쓸 수 있다.
- 대기 차량 주차지는 정해진 목록에서 선택하고, 필요 시 `+ 직접추가`로 새 값을 넣을 수 있다.
- 최신 arm64 release APK를 다시 빌드해 gdrive 업로드까지 마쳤다.

### 실제 동작
- latest raw import run `fff8bdc5-f2ef-46e9-9f27-6908e485edf1` 기준으로 데이터를 다시 적재했다.
- 예약 raw 는 완료/날짜공란/예약취소/과거 반납일 기준으로 1차 정리 후 normalize 했다.
- 일정 raw 는 완료 일정만 제거하고, `기타` 일정과 미연결 일정은 유지했다.
- normalize 시 `배차/반납` 뿐 아니라 `기타`도 `rc00_ops_schedules` 로 올린다.
- 일정 상세 수정은 `schedule_type_raw / schedule_at_raw / car_number / car_name / location_text / detail_text` 를 직접 갱신한다.
- 대기 차량 주차지는 기본 enum 목록 + 직접추가 값으로 저장한다.

### 핵심 파일
- `tool/import_google_sheets_raw.dart`
- `tool/normalize_raw_to_projection.dart`
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/shared/presentation/schedule_editor_dialog.dart`
- 당시 기준 문서: `docs/past/current-archive-2026-05-16/rentcar00_OPS-main.md`

### 검증
- raw import success 확인
- normalize 결과 확인
  - `reservation_projection_count=10`
  - `ops_car_upsert_count=58`
  - `ops_schedule_upsert_count=36`
- `dart analyze` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- gdrive 업로드 확인
  - `rentcar00_ops-app-release-arm64-b19-9c718f8.apk`

### 1차 장애 확인 포인트
1. 일정탭에서 `기타` 3건이 실제로 보이는지
2. 일정 상세 수정 저장 후 목록 반영이 즉시 되는지
3. 주차지 `직접추가` 값이 저장 후 다시 열어도 유지되는지
4. 미연결 일정이 상세에서 비정상 연결되지 않는지
5. 차량 반납일 공란/역전값이 운영상 허용 가능한지

### 남은 주의점
- 차량 raw 반납일 공란과 역전값은 이번 phase에서 그대로 유지했다.
- build number 는 여전히 `+19` 기준이라 배포보다는 재설치 전제다.
- 문서 정리 후 다음 active 는 실기기 운영 확인 phase 로 본다.

## 2026-05-14 — 현황판/상세 UI 밀도 조정 + APK 재배포 완료
### 사용자 표면
- 차량 상세의 기능 버튼이 4열 고정 정렬로 더 단정하게 보인다.
- 기능 영역에서 별도 `기능` 제목/카드가 빠지고 버튼이 더 작고 촘촘하게 배치된다.
- 일정 카드 시간 `HH:MM` 이 잘리지 않게 유지된다.
- 일반/보험/장기 카드에서 차량번호와 날짜가 더 크게 보이고, 카드 상하 여백이 더 얇아진다.
- 배차/반납 글씨는 빠지고 날짜와 화살표만 남는다.
- 반납일이 지난 카드는 빨간색, 지나지 않은 카드는 검정색으로 보인다.
- 대기 탭 세차 완료색이 초록이 아니라 파란색으로 보인다.

### 실제 동작
- 상세 기능 액션을 `GridView.count(crossAxisCount: 4)` 로 정렬해 버튼 수가 달라도 4열 기준으로 맞춘다.
- 액션 버튼은 더 작은 아이콘/텍스트 밀도로 재조정했다.
- 일정 카드 시간 칸은 폭을 유지하고 `FittedBox` 로 `HH:MM` 잘림을 막는다.
- 일반/보험/장기 카드의 padding, 간격, 텍스트 크기 비율을 다시 조정해 카드 밀도를 높였다.
- 배차/반납 날짜 셀은 라벨 없이 날짜 + 화살표만 표시한다.
- 반납일 overdue 여부는 `endAt < now` 기준으로 계산해 색상을 분기한다.
- APK는 `arm64 release` 로 다시 빌드해 `b18` 산출물로 업로드했다.

### 핵심 파일
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `pubspec.yaml`

### 검증
- `dart format lib/features/status_board/list/presentation/status_board_tab_page.dart lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `dart analyze lib/features/status_board/list/presentation/status_board_tab_page.dart lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `flutter build apk --release --target-platform android-arm64`
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b18-86fd8a6.apk`
- 결과: `No issues found`, APK 업로드 확인 완료

### 1차 장애 확인 포인트
1. 기능 버튼 수가 적거나 많을 때도 4열 정렬이 어색하지 않은지
2. 일정 카드 시간 `HH:MM` 이 실제 기기에서 잘리지 않는지
3. 일반/보험/장기 카드의 주소 영역 축소가 운영상 허용 가능한지
4. 반납일 overdue 색상 기준이 기기 현재시각과 맞는지
5. 업로드 파일 `rentcar00_ops-app-release-arm64-b18-86fd8a6.apk` 가 최신본인지

### 남은 주의점
- 기능 버튼은 4열 고정이라 버튼 수가 매우 적을 때 좌우 여백이 넓게 느껴질 수 있다.
- 반납일 색상은 현재 로컬 현재시각 기준 비교이므로 타임존 이슈가 있으면 후속 보정이 필요하다.

## 2026-05-14 — 반납 완료 초기화 규칙 + 대기 현황판 폭 조정 완료
### 사용자 표면
- 반납 완료 후 차량이 대기 상태로 돌아가면서 고객 연락처/대여일/배차지가 비워진다.
- 대기 현황판에서 차종은 조금 더 좁아지고, 세차는 왼쪽으로 붙고, 주차지는 더 넓게 보인다.

### 실제 동작
- 반납 완료 시 차량 row 에 아래를 반영한다.
  - `status = 대기중`
  - `status_action = 반납 완료`
  - `customer_name = ''`
  - `customer_phone = ''`
  - `start_at = ''`
  - `pickup_location = ''`
  - `end_at` 유지
  - `car_wash = FALSE`
  - `interior_wash = FALSE`
  - `parking_location = 수푸레`
- 대기 현황판 행/헤더에서 차종 폭을 줄이고, 세차 정렬을 왼쪽으로 당기고, 주차지 공간을 늘렸다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`

### 검증
- `dart analyze lib/data/repositories/supabase_ops_repository.dart lib/features/status_board/list/presentation/status_board_tab_page.dart`
- 결과: `No issues found`

### 1차 장애 확인 포인트
1. 반납 완료 후 `rc00_ops_cars` 에 고객명/연락처/대여일/배차지가 실제로 비워졌는지
2. 반납일 `end_at` 이 유지되는지
3. 세차 2개가 `FALSE` 로 내려가는지
4. 주차지가 `수푸레` 로 들어가는지
5. 대기 현황판에서 주차지 폭이 실제로 더 넓어졌는지

### 남은 주의점
- 비고(`note_text`)는 이번 범위에서 유지한다.
- UI 폭은 실기기에서 한 번 더 보고 미세조정 가능하다.

---

## 2026-05-14 — 일정 ↔ 예약 연결 표시 fallback 보강 완료
### 사용자 표면
- 일정 상세의 예약 연결 정보가 덜 비게 보인다.
- schedule row 값이 비어 있어도 외부예약번호/위치/상세가 linked reservation 기준으로 채워진다.

### 실제 동작
- 현황판 일정 record 생성 시 reservation lookup 에 `reservation_number` 를 포함한다.
- schedule row 의 `reservation_number` 가 비면 linked reservation 의 `reservation_number` 로 fallback 한다.
- schedule row 의 `location_text` 가 비면 linked reservation 의 `pickup_location` 으로 fallback 한다.
- schedule row 의 `detail_text` 가 비면 linked reservation 의 `note_text` 로 fallback 한다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`

### 검증
- `dart analyze lib/data/repositories/supabase_ops_repository.dart lib/features/status_board/detail/presentation/status_board_detail_page.dart lib/features/status_board/list/presentation/status_board_tab_page.dart`
- diff 기준으로 schedule record fallback 반영 확인

### 1차 장애 확인 포인트
1. 일정 row 의 `reservation_id` 가 실제 예약 row 와 맞는지
2. `rc00_ops_reservations` 조회에 `reservation_number` 가 포함되는지
3. 일정 상세 외부예약번호/위치/상세가 비면 linked reservation 원천값이 실제로 존재하는지

### 남은 주의점
- `reservation_id` 가 비어 있는 일정은 이번 fallback 대상이 아니다.
- 일정 단독 생성은 의도된 운영 흐름이므로, 미연결 일정은 자동 연결하지 않고 그대로 유지한다.

---

## 2026-05-14 — IMS 예약추가 1차 완료
### 사용자 표면
- 차량 상세에서 예약 생성 시 `IMS 예약추가` 체크 가능
- 예약 상세에서 독립 `IMS 예약추가` 액션 실행 가능

### 실제 동작
- 내부 예약 생성 후 원장 기준으로 IMS payload 를 만든다.
- 앱은 `POST {aiParserBaseUrl}/ims/create-reservation` 으로 전송한다.
- payload 는 `rentalAt / returnAt / carNumber / totalFee / customerName / customerPhone / address / useDelivery / memo` 로 고정한다.
- `useDelivery = true` 고정
- memo 는 `외부예약번호 + 생년월일 + note` 기반으로 만들고 최대 120자로 자른다.

### 핵심 파일
- `lib/features/reservations/detail/data/ims_reservation_payload.dart`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `reservation_ai_parser/src/server.js`

### 검증
- IMS dry-run 호출 성공
- 실제 IMS 저장 성공
- 저장 직후 삭제 재확인 성공

### 1차 장애 확인 포인트
1. AI파서 baseUrl 이 비어 있지 않은지
2. `https://parser.00rentcar.com/health` 가 200 인지
3. 필수값 누락이 없는지
   - 금액
   - 고객명
   - 고객번호
   - 배차지
   - 차량번호
4. 생년월일이 `YYYY-MM-DD` 형식인지
5. 반납일시가 배차일시보다 뒤인지
6. 서버 응답 timeout(40초) 또는 IMS DOM 변경이 아닌지

### 남은 주의점
- IMS DOM/정책 변경 시 서버측 endpoint 보정 필요
- memo 길이 제한은 운영 중 추가 조정 가능

---

## 2026-05-14 — 현황판 상태별 액션 분기 1차 완료
### 사용자 표면
- 대기 차량과 운행 차량의 버튼 구성이 다르게 보인다.
- 운행 차량에는 `반납` 액션이 나온다.
- 일정탭에서는 일정 생성 가능하다.

### 실제 동작
- 대기 차량:
  - 예약
  - 보험 / 일반 / 장기 전환
  - 외부세차 / 실내세차
  - 주차
- 운행 차량:
  - 반납
  - 전화 / 문자
- 반납 완료 시 차량 row 에 아래를 쓴다.
  - `status = 대기중`
  - `status_action = 반납 완료`
  - `car_wash = FALSE`
  - `interior_wash = FALSE`
  - `parking_location = 수푸레`
- 일정탭 일정 생성은 `rc00_ops_schedules` 에 미연결 일정 row 를 추가한다.

### 핵심 파일
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `lib/data/repositories/supabase_ops_repository.dart`

### 검증
- `dart analyze` 통과
- 상태 분기/반납 완료/일정 액션 UI 및 저장 동작 반영 확인

### 1차 장애 확인 포인트
1. 차량 status 값이 `대기중 / 보험 / 일반 / 장기` 중 무엇인지
2. 버튼이 안 보이면 현재 record 가 차량인지 일정인지
3. 반납 후 값이 안 바뀌면 `rc00_ops_cars` update 반영 여부
4. 일정 생성 후 목록이 안 보이면 현황판 provider invalidate 반영 여부

### 남은 주의점
- 반납 후 고객/운행 정보 비움 범위는 후속 점검 가능
- 일정 생성은 예약 원장을 만들지 않는다

---

## 2026-05-14 — 일정완료 시 차량 인스턴트값 동기화 + 전화/문자 액션 완료
### 사용자 표면
- 일정 상세에서 `완료 / 전화 / 문자 / 삭제` 가능
- 배차 일정 완료 후 차량 상세에서 고객 대응 정보를 바로 볼 수 있다.

### 실제 동작
- 일정 완료 시 `schedule_done_raw = TRUE`
- 일정이 `배차` 이고 차량번호가 있으면 연결 예약을 읽어 차량 row 에 고객명/연락처/배차지/start/end/note 를 반영한다.
- 그때 차량 상태는 `일반`, 상태액션은 `일정완료` 로 바뀐다.
- 전화/문자는 번호가 있을 때만 버튼을 노출한다.

### 핵심 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/shared/utils/contact_launcher.dart`
- `pubspec.yaml`

### 검증
- `flutter pub get`
- `dart analyze`
- 전화/문자 버튼 조건부 노출 반영 확인

### 1차 장애 확인 포인트
1. 일정 record 의 `reservation_id` 가 비어 있지 않은지
2. 일정 유형이 `배차` 인지
3. 차량번호가 비어 있지 않은지
4. 연결 예약 row 에 고객명/연락처/배차지/start/end 값이 있는지
5. 전화/문자 버튼 미노출이면 번호 값이 실제로 비어 있지 않은지

### 남은 주의점
- 연결 예약 매핑 누락 데이터는 후속 정리 필요
- 실제 기기에서 전화/문자 앱 라우팅 UX 추가 점검 가능

---

## 2026-05-14 — 예약생성 AI파서 상시 운영 복구 완료
### 사용자 표면
- 차량 상세 예약 생성 dialog 에서 AI파서 health 확인과 원문 파싱이 가능하다.
- 앱은 고정 공개 주소 `https://parser.00rentcar.com` 만 사용한다.

### 실제 서비스 구성
- tunnel daemon: `com.cloudflare.cloudflared`
- parser agent: `ai.otang.reservation-ai-parser`
- parser origin: `127.0.0.1:43110`
- 공개 endpoint:
  - `GET /health`
  - `POST /parse-reservation`
  - `POST /ims/create-reservation`

### 핵심 파일 / 서비스
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `lib/features/status_board/detail/data/reservation_ai_parser_client.dart`
- `~/Library/LaunchAgents/ai.otang.reservation-ai-parser.plist`
- `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist`

### 검증
- `launchctl print gui/$(id -u)/ai.otang.reservation-ai-parser`
- `GET http://127.0.0.1:43110/health` → 200
- `GET https://parser.00rentcar.com/health` → 200
- `POST /parse-reservation` 로컬/외부 둘 다 성공

### 운영 명령 / 로그
- 상태 확인:
  - `launchctl print gui/$(id -u)/ai.otang.reservation-ai-parser`
- 재기동:
  - `launchctl kickstart -k gui/$(id -u)/ai.otang.reservation-ai-parser`
- 로그:
  - `reservation_ai_parser/logs/stdout.log`
  - `reservation_ai_parser/logs/stderr.log`

### public 502 시 1차 확인 순서
1. `curl http://127.0.0.1:43110/health`
2. local health 실패면 parser origin down 으로 본다
3. `launchctl print gui/$(id -u)/ai.otang.reservation-ai-parser`
4. 필요 시 `launchctl kickstart -k gui/$(id -u)/ai.otang.reservation-ai-parser`
5. local health 정상인데 public 만 실패하면 tunnel 쪽 상태를 본다

### 남은 주의점
- 재부팅 후 자동기동 재확인은 별도 시점에 다시 확인 가능
- tunnel up 만으로 서비스 정상으로 보면 안 된다


## 2026-05-15 — IMS 체크 예약 생성 잠금
- 차량 상세에서 IMS 체크 후 예약 생성 시, DB insert 전에 IMS payload 를 검증하도록 잠금.
- 검증 실패 시 예약원장/일정 생성 없이 입력 수정 안내를 표시.
- 차량 시작일 3건 수동 보정 완료: `29하2763`, `34호7488`, `34호7499`.


## 2026-05-15 — UI/참조명 정리
- 상단 불필요 버튼/사용자명 제거, 예약 탭 설명 제거.
- `예약번호` 표시명을 `외부예약번호` 로 변경하고, 예약/일정 연결 기준을 `예약ID` 로 명확화.
- 예약 카드와 예약 상세 가독성 개선.


## 2026-05-15 — 일정 예약 연결 표시 잠금
- 일정 상세에서 실제 예약 원장에 존재하는 예약ID만 연결 표시하도록 정리.
- 원장에 없는 orphan 참조는 예약 상세로 이동하지 않고 `연결된 예약 없음` 으로 표시.
