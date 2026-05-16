# rentcar00_OPS Completed

이 문서는 `rentcar00_OPS`의 **완료 기능 단일 문서**다.
완료된 기능은 날짜순으로 누적하고, 각 항목마다 사용자 표면 / 실제 동작 / 핵심 파일 / 검증 / 1차 장애 확인 포인트를 남긴다.

---

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
- `docs/current/rentcar00_OPS-main.md`

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
