# IMS 보험배차 가져오기 예약 반납완료 버튼 누락 이슈

- Date: 2026-07-07
- Status: Issue documented only
- Scope: 코드 확인 + 문서 추가. 코드/DB/배포 변경 없음.

## 현상

보험배차에서 IMS 보험계약을 가져온 건의 경우, 차량이 배차 상태가 되어도 예약원장/예약상세에서 `반납완료` 기능이 뜨지 않는 문제가 있다.

## 사용자 제보 기준

- 경로: 차량상세 `배차` → `보험` → `IMS 보험배차 가져오기`
- 기대: 가져온 보험배차 건도 예약원장 흐름에서 배차 후 반납완료 처리가 가능해야 한다.
- 실제: 배차가 되어도 예약원장 상세의 `반납완료` 액션이 보이지 않는다.

## 코드 확인 결과

### 1. 일반 예약 생성 경로는 반납 일정까지 만든다

`lib/data/repositories/supabase_ops_repository.dart`

- `createReservationFromVehicle()`은 `rc00_ops_reservations` 생성 후 `rc00_ops_schedules`에 2건을 생성한다.
  - `schedule_type = '배차'`
  - `schedule_type = '반납'`
- 예약상세의 반납완료 버튼은 이 연결 반납 일정 존재 여부에 의존한다.

### 2. 예약상세 반납완료 버튼 표시 조건

`lib/features/reservations/detail/presentation/reservation_detail_page.dart`

- `returnPending`: 연결 일정 중 `schedule_type == '반납'`이고 `schedule_done`이 아닌 일정이 있어야 true.
- `isDispatched`: 예약 상태가 `배차중`이거나 예약 탭이 `inUse`여야 true.
- `showReturnComplete = !isCompleted && isDispatched && returnPending`

즉, 예약상세에서 `반납완료`가 뜨려면 최소 조건은 아래 2개다.

1. 예약 원장 상태가 배차중/inUse
2. 같은 `reservation_id`에 미완료 `반납` 일정 존재

### 3. 보험배차 IMS 가져오기 경로는 예약원장/반납일정을 만들지 않는다

`lib/features/status_board/detail/presentation/status_board_detail_page.dart`

- `_openDispatchStatus()`에서 `보험` 선택 시 `_ImsInsuranceDispatchImportDialog`를 열고 IMS 보험계약 후보를 조회한다.
- 후보 선택 후 `_applyInsuranceDispatchImport()` 실행.
- `_applyInsuranceDispatchImport()`는 `updateCarInstantStatus()`만 호출한다.
- `updateCarInstantStatus()`는 `rc00_ops_cars` 차량 상태만 갱신한다.
  - `status = '보험'`
  - 고객명/전화/배차일/반납일/배차지/note 저장
- 이 경로에서는 `rc00_ops_reservations` 생성, `rc00_ops_reservation_states` 생성, `rc00_ops_schedules` 배차/반납 생성, `rc00_ops_external_reservation_links` 저장이 없다.

## 원인 가설

현재 코드 기준으로는 단순 UI 누락이 아니라 데이터 흐름 불일치다.

- 일반 예약/IMS 일반예약 가져오기: 예약원장 + 배차/반납 일정 기반
- 보험배차 IMS 가져오기: 차량 즉시상태 갱신 기반

따라서 보험배차로 가져온 건은 예약상세가 요구하는 `reservation_id` 연결 반납 일정이 없거나, 예약원장 lifecycle과 연결되지 않아 `반납완료` 버튼 조건을 만족하지 못할 수 있다.

## 영향 범위

- 보험배차 IMS 가져오기 건의 반납완료 처리 UX 누락
- 차량 상태에는 반납 예정 정보가 들어가도 예약원장/일정 기반 lifecycle과 분리될 수 있음
- 과태료/계약서 쪽 IMS 보험계약 조회와는 별개 경로지만, 같은 보험계약 source를 사용하므로 source id/claim id 저장 기준은 함께 확인 필요

## 수정 방향 후보

### 권장 방향 A — 보험배차 IMS 가져오기도 예약원장으로 승격

보험배차 IMS 후보 선택 시 `createReservationFromVehicle()` 또는 별도 보험예약 생성 함수를 통해 아래를 함께 생성한다.

- `rc00_ops_reservations`
- `rc00_ops_reservation_states`
- `rc00_ops_schedules` 배차/반납 2건
- `rc00_ops_external_reservation_links`에 IMS 보험 claim id/link 정보 저장

장점:
- 기존 예약상세 lifecycle 조건을 그대로 사용한다.
- 배차완료/반납완료/로그/탭 이동 기준이 통일된다.

리스크:
- 현재 보험배차가 차량 즉시상태 중심으로 쓰이는 경우, 중복 예약 생성 가능성 검증 필요.
- `claimId`를 external id/detail id 중 어디에 저장할지 기준 잠금 필요.

### 대안 B — 차량 즉시상태 기반 반납완료 액션 별도 제공

차량상세 보험 상태에서 별도 `반납완료` 버튼을 제공하고 `completeCarReturn()`으로 차량만 대기중 전환한다.

장점:
- 변경 범위가 작다.

리스크:
- 예약원장 lifecycle과 계속 분리된다.
- 사용자가 말한 “예약원장 반납 기능” 기대와 다를 수 있다.
- 일정/로그/완료탭 이력이 약해진다.

## 다음 PM 작성 시 잠글 기준

1. 보험배차 IMS 가져오기 결과를 예약원장으로 반드시 생성할지 여부
2. 기존 차량 즉시상태 보험배차 흐름을 유지할지, 예약원장 흐름으로 통합할지 여부
3. 보험 claim id 저장 위치
   - `external_reservation_id`
   - `external_detail_id`
   - `link_key`
4. 이미 차량 즉시상태로만 가져온 기존 건을 backfill할지 여부
5. 중복 생성 방지 기준
   - 차량번호 + claimId
   - 차량번호 + 대여/반납일시
   - IMS 보험계약 상태

## 검증 후보

- 보험배차 IMS 후보 선택 후 예약원장 생성 여부 확인
- 생성된 예약상세에서 `배차완료` → `반납완료` 버튼 순서 확인
- `rc00_ops_schedules`에 배차/반납 2건 생성 확인
- `rc00_ops_external_reservation_links`에 IMS 보험 claim id 연결 확인
- 기존 일반예약 IMS 가져오기/IMS 생성/차량변경/취소 regression 확인

## 현재 미실행

- 코드 수정 없음
- DB 수정 없음
- 테스트 실행 없음
- 커밋 없음
