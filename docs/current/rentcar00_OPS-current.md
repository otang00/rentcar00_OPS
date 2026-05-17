# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 실행 중인 작업 1건만 적는다.
완료된 기능과 운영 확인 포인트는 docs/completed/rentcar00_OPS-completed.md로 옮긴다.

---

## 현재 active 작업
**상태보드 수리중/배차 UX + 예약상세 차량변경**

## 목적
대기 차량 중 실제 배차가 불가능한 차량을 `수리중` 상태로 표시하고, 배차 즉시전환 UX를 실기기 운영 흐름에 맞게 정리한다.
추가로 예약상세에서 예약 차량을 안전하게 변경할 수 있게 하되, 원장 예약시간 중복과 IMS 연동 실패 처리를 명확히 잠근다.

## 현재 기준
- 최신 빌드/업로드 APK: `rentcar00_ops-app-release-arm64-b31-8c18738.apk`
- 현재 앱 build number: `31`
- b31은 상태보드 배차/세차/연결 일정 UX 보정분까지 포함한다.
- 이번 작업은 아직 구현 전이며, 문서 기준을 먼저 잠근 상태다.
- 현재 앱의 IMS 클라이언트는 `POST /ims/create-reservation` 생성 흐름만 확인됨.
- 루트 `IMS_API_MANUAL.md` 기준 직접 API는 인증/가용차량조회/예약생성/예약삭제가 확인됨.
- IMS Web 번들 정적 확인 결과 스케줄 차량변경 전용 API 후보를 확인했다.
  - `POST /v2/company-car-schedules/{schedule_id}`
  - body: `{ company_car_id: <rent_company_car_id> }`
  - 응답 성공 시 `success`와 새 `schedule_id`가 내려오는 흐름으로 보인다.
- 확인 근거: IMS Web `carBooking/schedule` 번들의 `api/carBooking/index.js` `modifyCarSchedule()`와 `components/Scheduler/.../GroupRow/index.tsx` 드래그 차량변경 흐름.
- 이 API는 IMS 스케줄의 차량 이동 API로 실제 검증했다.
- 2026-05-17 KST 실제 IMS 테스트 결과:
  - 테스트 시간: `2026-12-15 10:00~12:00`
  - 생성 차량: `101허4041` / IMS car id `117649`
  - 변경 차량: `101허4014` / IMS car id `117646`
  - 생성 schedule id: `4189163`, detail id: `204340`
  - 차량변경 요청: `POST /v2/company-car-schedules/4189163` body `{ company_car_id: 117646 }`
  - 변경 응답: `{ schedule_id: 4189163, success: true }`
  - 변경 후 schedule id는 유지됐고 차량만 `101허4014`로 변경됨.
  - 삭제 요청: `POST /v2/company-car-schedules/delete` body `{ ids: ["4189163"] }`
  - 삭제 응답: `{ failed_deletion_schedule_ids: [], success: true }`
  - 삭제 후 동일 테스트 예약이 목록에서 사라진 것까지 확인함.
- 사전 실패/정리 기록: 생성 후 조회 범위 문제로 발견이 늦어진 테스트 예약 `4189161`, `4189162`도 각각 확인 후 삭제 성공했다.
- 삭제+재생성 방식은 우선 보류한다. Phase 6의 1차 구현 대상은 `POST /v2/company-car-schedules/{schedule_id}`다.

## 잠긴 요구사항
### 1. 수리중 상태
- `수리중` 차량은 배차불가 차량이다.
- `수리중` 차량은 별도 탭이 아니라 **대기탭에 계속 표시**한다.
- 대기탭에서 `수리중` 차량 row/card는 어두운 배경으로 표시해 일반 대기 차량과 구분한다.
- `수리중` 차량은 배차 대상처럼 보이면 안 된다.

### 2. 수리중 진입
- 대기 차량 상세 기능에 `수리중` 버튼을 추가한다.
- `수리중` 버튼을 누르면 입고공장 선택 다이얼로그를 연다.
- 입고공장 선택 UI는 기존 주차지 선택 폼과 같은 방식으로 만든다.
- 선택지 아래에 `공장추가` 버튼을 두고, 직접 공장을 추가할 수 있게 한다.
- 저장 시 차량 상태는 `대기중`이 아니라 `수리중`으로 바뀐다.
- 입고공장명은 대기탭에서 바로 보이도록 `parking_location`에 저장하는 것을 1차 기준으로 한다.

### 3. 수리완료
- 차량 상태가 `수리중`이면 상세 기능 버튼은 `수리완료`로 바뀐다.
- `수리완료` 버튼을 누르면 확인 다이얼로그를 띄운다.
- 확인 문구: `수리완료(대기중) 처리하시겠습니까?`
- 확인 시 차량 상태를 `대기중`으로 되돌린다.
- 수리완료 후 공장명/주차지 초기화 여부는 구현 중 임의 확장하지 않는다. 필요하면 별도 확인한다.

### 4. 배차 선택 다이얼로그 UX
- 차량상세 → `배차` 클릭 시 나오는 보험/일반/장기 선택 다이얼로그를 세차 다이얼로그와 비슷한 카드 버튼형 UI로 통일한다.
- 이 다이얼로그는 체크 상태를 고르는 화면이 아니라 즉시배차 선택 화면이다.
- 체크박스/체크 아이콘은 빼고, 버튼형 선택지만 둔다.

### 5. 배차 후 수정창 자동 오픈
- 보험/일반/장기 선택 즉시 차량 상태를 해당 상태로 변경한다.
- 대여일시는 배차 시점이므로 현재 시각으로 저장한다.
- 배차지와 주차지는 빈값으로 시작한다.
- 상태 변경 직후 차량 상태 수정창을 바로 띄워 세부값을 입력할 수 있게 한다.

### 6. 예약상세 차량변경
- 예약상세에 `차량변경` 기능을 추가한다.
- `차량변경`을 누르면 차량검색창 + 차량 선택창을 띄운다.
- 차량 선택 후 `차량 변경하시겠습니까?` 확인 다이얼로그를 띄운다.
- 확인 후에만 변경을 진행한다.
- OPS 원장 예약의 `car_number`, `car_name`을 새 차량으로 변경한다.
- 연결된 배차/반납 일정의 차량번호/차종도 같이 변경한다.
- 변경 후 예약/현황판 provider를 invalidate 해 화면을 갱신한다.

### 7. 원장 예약시간 중복 검증
- 차량변경 전, 바꿀 차량의 다른 예약과 시간이 겹치는지 OPS 원장에서 먼저 확인한다.
- 같은 예약 자기 자신은 중복 검사에서 제외한다.
- 시간 겹침 기준은 기존 예약의 `start_at/end_at` 구간과 변경 대상 예약의 `start_at/end_at` 구간이 겹치는 경우다.
- 겹치면 차량변경을 실패 처리하고 사용자에게 안내한다.
- OPS 원장 중복 검증 실패 시 IMS 호출은 하지 않는다.

### 8. IMS 연동 차량변경
- 해당 예약이 IMS와 active binding 상태면 IMS 예약도 차량 변경한다.
- IMS 변경 전에도 OPS 원장 중복 검증은 먼저 통과해야 한다.
- IMS 변경 성공 시 OPS 원장/일정 변경까지 완료한다.
- OPS 원장은 통과했지만 IMS 변경이 실패한 경우, 사용자에게 선택지를 보여준다.
  1. `연동 끊고 원장만 변경`
  2. `변경취소`
- `연동 끊고 원장만 변경` 선택 시 OPS 원장/일정은 변경하고 IMS link는 unlinked/failed 등 끊긴 상태로 기록한다.
- `변경취소` 선택 시 OPS 원장/일정 변경도 하지 않는다.
- IMS 변경 API 후보는 `POST /v2/company-car-schedules/{schedule_id}` + `{ company_car_id }`로 잠근다.
- 이 API 호출에는 IMS `schedule_id`와 대상 차량의 IMS `rent_company_car_id`가 필요하다.
- 실제 적용 전에는 OPS 예약의 IMS binding에 저장된 `schedule_id/detail_id` 매핑과 대상 차량의 IMS car id 매핑을 확인한다.
- API 응답 실패 또는 IMS schedule id 매핑 누락 시 임의 삭제+재생성으로 우회하지 않는다.

## Phase 계획
### Phase 1 — 수리중 상태/표시/토글
수정 대상 후보:
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`

종료 조건:
- `수리중` 차량이 대기탭에 표시된다.
- 수리중 row/card가 어둡게 표시된다.
- 상세에서 `수리중` 진입과 `수리완료` 복귀가 가능하다.

### Phase 2 — 배차 선택 다이얼로그 통일
수정 대상 후보:
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`

종료 조건:
- 배차 선택 UI가 세차 선택 UI와 같은 계열의 카드 버튼형으로 보인다.
- 체크박스/선택완료형 UI가 남지 않는다.

### Phase 3 — 배차 후 수정창 자동 오픈
수정 대상 후보:
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/data/repositories/supabase_ops_repository.dart`

종료 조건:
- 배차 상태 전환 직후 수정창이 열린다.
- 수정창 초기값은 상태=선택값, 대여일시=현재시각, 배차지/주차지=빈값이다.

### Phase 4 — 예약상세 차량변경 UI + OPS 중복검증
수정 대상 후보:
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/data/models/status_board_record.dart` 또는 차량 선택용 모델/조회 함수

종료 조건:
- 예약상세에서 차량검색/선택/확인 흐름이 열린다.
- 선택 차량의 OPS 예약시간 중복을 검사한다.
- 겹치는 예약이 있으면 변경하지 않고 실패 안내한다.

### Phase 5 — OPS 원장/일정 차량변경 반영
수정 대상 후보:
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`

종료 조건:
- OPS 원장의 예약 차량이 변경된다.
- 연결된 배차/반납 일정 차량도 같이 변경된다.
- 예약상세/예약목록/현황판 갱신이 된다.

### Phase 6 — IMS 차량변경 연동/실패분기
사전 확인 기준:
- IMS Web 정적 번들에서 전용 수정 API를 확인했고, 실제 테스트 예약으로 검증했다.
- API: `POST /v2/company-car-schedules/{schedule_id}`
- 요청 body: `{ company_car_id: <rent_company_car_id> }`
- 호출 위치: IMS Web `carBooking/schedule` 드래그 차량변경 `modifyCarSchedule()` 흐름.
- 실제 검증 결과 기존 `schedule_id`는 유지되고 차량만 변경됐다.
- 구현 전 OPS에 저장된 IMS `schedule_id`와 대상 차량 IMS id 조회 경로를 확인한다.
- 추가 실제 IMS POST 테스트는 외부 상태 변경이므로 별도 승인/테스트 예약 기준 없이 실행하지 않는다.
- 삭제+재생성 방식은 별도 승인/정책 결정 전까지 구현하지 않는다.

수정 대상 후보:
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/data/repositories/supabase_ops_repository.dart`

종료 조건:
- IMS active binding 예약은 IMS 차량변경을 시도한다.
- IMS 변경 성공 시 OPS도 변경한다.
- IMS 변경 실패 시 `연동 끊고 원장만 변경` / `변경취소` 선택 분기가 동작한다.
- IMS 차량변경 API는 실제 테스트 예약 기준 검증 완료다.
- IMS `schedule_id` 또는 대상 차량 IMS id 매핑이 없으면 이 phase는 중단하고 별도 보고한다.
- 삭제+재생성 방식은 실제 IMS 예약 상태를 바꾸므로 별도 승인 없이는 실행하지 않는다.

## 진행 현황
- 2026-05-17 KST Phase 1 완료:
  - `수리중` 상태를 대기탭으로 분류한다.
  - 대기탭 `수리중` 차량은 어두운 row와 `배차불가` 배지로 표시한다.
  - 차량상세에서 `수리중` 진입/`수리완료` 복귀 버튼을 제공한다.
  - 입고공장 선택/공장추가 다이얼로그를 추가했다.
  - `수리중` 진입 시 `parking_location`에 입고공장명을 저장한다.
  - `수리완료` 시 상태만 `대기중`으로 되돌리고 공장명/주차지는 임의 초기화하지 않는다.
- 2026-05-17 KST Phase 2 완료:
  - 배차 선택 다이얼로그를 세차 다이얼로그 계열의 카드 버튼형 UI로 통일했다.
  - 즉시배차 선택 화면에서 체크박스/체크 아이콘을 제거했다.
- 2026-05-17 KST Phase 3 완료:
  - 배차 선택 직후 차량 상태와 대여일시를 저장한다.
  - 배차지/주차지는 빈값으로 저장한다.
  - 상태 전환 직후 차량 상태 수정창을 자동으로 연다.
- 2026-05-17 KST Phase 4 완료:
  - 예약상세에 `차량변경` 기능 버튼을 추가했다.
  - 차량검색/선택 다이얼로그와 `차량 변경하시겠습니까?` 확인 흐름을 추가했다.
  - 변경 전 OPS 원장 기준 차량/시간 중복 검사를 수행한다.
  - 자기 예약은 중복 검사에서 제외한다.
- 2026-05-17 KST Phase 5 완료:
  - OPS 원장 예약의 `car_number`, `car_name`을 변경한다.
  - 연결된 배차/반납 일정의 차량번호/차종도 같이 변경한다.
  - 예약/현황판 provider를 invalidate 해 화면을 갱신한다.
- 2026-05-17 KST Phase 6 구현 완료:
  - 중간서버에 `POST /ims/change-reservation-car`를 추가했다.
  - 서버는 IMS available API로 대상 차량의 내부 `company_car_id`를 조회한 뒤 `POST /v2/company-car-schedules/{schedule_id}`를 호출한다.
  - IMS active binding 예약은 IMS 차량변경 성공 후 OPS 원장/일정을 변경한다.
  - IMS 실패 시 `연동 끊고 원장만 변경` / `변경취소` 선택 분기를 제공한다.
  - `연동 끊고 원장만 변경` 선택 시 IMS link를 `unlinked`로 전환한 뒤 OPS 원장만 변경한다.
- 검증:
  - `flutter analyze` 통과
  - `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
  - `npm --prefix reservation_ai_parser run check` 통과

## 전체 진행 순서
1. Phase 1 수리중 상태부터 구현한다. — 완료
2. Phase 2~3으로 상태보드 배차 UX를 마무리한다. — 완료
3. Phase 4~5로 OPS 원장 기준 차량변경을 먼저 완성한다. — 완료
4. Phase 6에서 IMS 차량변경 연동을 별도 검증 후 붙인다. — 구현 완료
5. 모든 phase 완료 후 문서 업데이트, 검증, 필요 시 b32 APK 빌드/업로드를 진행한다.

## 검증 방법
- `flutter analyze`
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart`
- 예약상세 차량변경 관련 테스트가 필요하면 별도 테스트 추가
- `npm --prefix reservation_ai_parser run check`는 IMS 서버 변경 시 실행
- 필요 시 arm64 APK 빌드/업로드는 별도 승인 후 진행한다.

## 리스크 / 확인 필요
- `수리중`은 기존 DB enum 없이 문자열 상태로 쓰는 구조로 보인다. 구현 중 DB 제약이 발견되면 즉시 중단한다.
- 공장명을 `parking_location`에 저장하는 기준으로 잠갔지만, 별도 컬럼이 필요해지는 경우 자동 확장하지 않는다.
- 수리완료 시 공장명/주차지 값을 어떻게 처리할지는 구현 중 임의 결정하지 않는다.
- 차량변경의 원장 중복검증은 DB 쿼리 기준을 잘못 잡으면 중복 예약을 허용할 수 있으므로 phase 내에서 별도 검증한다.
- IMS 차량변경 API는 정적 번들 확인과 실제 테스트 예약 검증을 모두 완료했다. 추가 실제 IMS POST 검증은 승인 없이 실행하지 않는다.
- `POST /v2/company-car-schedules/{schedule_id}`는 이번 검증에서 기존 schedule id를 유지했다. 다만 응답의 `schedule_id`를 기준으로 binding을 재저장하는 방어 로직은 유지한다.
- 삭제+재생성 방식은 외부 IMS 예약을 실제로 변경하므로, 테스트 예약/삭제 경로/롤백 기준이 잠기기 전에는 실행하지 않는다.
