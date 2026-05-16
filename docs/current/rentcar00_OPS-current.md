# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **유일한 현재 active 실행 문서**다.
현재 실행 중인 작업 1건만 적는다.
프로젝트 전체 기준/과거 정책 문서는 `docs/past/current-archive-2026-05-16/` 및 `docs/completed/`로 보관한다.

---

## 현재 active 작업
**예약원장 ↔ 일정 ↔ 차량상태 lifecycle 연동 + 예약/차량 상세 UX 정리**

## 목적
예약원장, 일정, 차량 현황이 따로 움직이지 않게 한다.
운영자가 일정 완료/수정 또는 예약 수정 중 하나만 처리해도 연결된 데이터가 같이 맞춰지도록 한다.

## 핵심 기준
1. 예약원장이 기준 데이터다.
2. 일정은 예약 lifecycle의 실행 이벤트다.
3. 차량 현황은 실제 운영 상태 표면이다.
4. 연결된 예약/일정이 있으면 한쪽 수정이 다른 쪽에 반영되어야 한다.
5. 자동 반영 대상이 없거나 중복이면 임의 추정하지 않고 중단/오류 표시한다.
6. 빌드는 별도 지시 전까지 하지 않는다.

---

## 전체 Phase 잠금

### Phase 1. 일정 완료/수정 → 예약원장/차량 상태 연동
목적:
- 일정에서 완료/수정한 내용이 예약원장과 차량 상태에 반영되게 한다.

작업:
1. 일정 완료 버튼에 확인창 추가
2. 배차 일정 완료 시:
   - `rc00_ops_schedules.schedule_done = true`
   - `rc00_ops_reservations.reservation_status = '배차중'`
   - `rc00_ops_reservation_states.tab_key = 'in_use'`
   - 차량은 기존 배차 반영 로직 유지
3. 반납 일정 완료 시:
   - `rc00_ops_schedules.schedule_done = true`
   - `rc00_ops_reservations.reservation_status = '완료'`
   - `rc00_ops_reservation_states.tab_key = 'completed'`
   - 차량은 기존 `completeCarReturn()` 기준으로 대기중/세차 초기화/주차지 초기화
4. 일정 수정 시 연결 예약이 있으면:
   - 배차 일정: 예약 `start_at`, `pickup_location` 갱신
   - 반납 일정: 예약 `end_at`, `dropoff_location` 갱신

종료 조건:
- 배차 일정 완료 후 예약이 배차중 탭으로 이동
- 반납 일정 완료 후 예약이 완료 탭으로 이동
- 일정 수정 후 예약 상세의 배차/반납 일시와 위치가 갱신
- 확인창 없이 일정 완료가 바로 실행되지 않음
- `flutter analyze` 통과
- 커밋 완료

### Phase 2. 예약 상세 수정 기능 + 예약 수정 → 연결 일정 동기화
목적:
- 예약 상세에서 예약내용을 직접 수정하고, 연결 일정을 같이 맞춘다.

작업:
1. 예약 상세 기능 버튼 맨 앞에 `수정` 추가
2. 예약 수정 다이얼로그 추가
   - 외부예약번호
   - 고객명/전화/생년월일
   - 소개처
   - 가격
   - 배차/반납 일시
   - 배차지/반납지
   - 메모
3. 예약 수정 저장 시 연결 일정도 갱신
   - 배차 일정: 배차일/배차지
   - 반납 일정: 반납일/반납지
4. 예약 상세 가격 표시 포맷 변경
   - `163400` → `163,400원`

종료 조건:
- 예약 상세에서 수정 가능
- 예약 수정 후 일정 탭에도 반영
- 가격 표시 콤마/원 정상
- `flutter analyze` 통과
- 커밋 완료

### Phase 3. 대기 차량 상세 UX 정리
목적:
- 대기 차량 상세 기능을 단순화한다.

작업:
1. 보험/일반/장기 버튼 제거
2. `배차` 버튼 하나로 통합
3. 배차 입력창 상단에서 보험/일반/장기 선택
4. 외부/실내 세차 버튼 제거
5. `세차` 버튼 하나로 통합
   - 선택창에서 외부세차/실내세차 선택
   - 바깥 누르면 닫힘
6. 주차 다이얼로그는 기본 목록만 표시
   - `직접추가` 버튼을 눌렀을 때만 새 주차지 입력폼 표시

종료 조건:
- 대기 차량 상세 버튼 수 감소
- 기존 배차/세차/주차 기능 유지
- UI 정렬 깨짐 없음
- `flutter analyze` 통과
- 커밋 완료

---

## Phase 1 구체 실행계획

### 1. 현재 경로
대상 파일:
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- 필요 시 `lib/features/reservations/shared/providers/reservation_providers.dart`

현재 확인된 사실:
- 일정 완료 UI: `_ScheduleDetailBodyState._completeSchedule()`
- 완료 저장 함수: `SupabaseOpsRepository.completeSchedule()`
- 현재 `completeSchedule()`은 `schedule_done=true` 처리 후, 배차 일정일 때만 차량 상태를 `일반`으로 반영한다.
- 반납 일정 완료 시 예약원장/차량 상태 변경 로직은 아직 없다.

### 2. repository 변경
`completeSchedule()` 내부를 다음 기준으로 정리한다.

공통:
- `schedule_done=true`
- `updated_at` 기록
- `reservationId`가 비어 있으면 예약원장 동기화는 생략

배차:
- 예약 row 조회
- 예약 `reservation_status='배차중'`
- reservation state `tab_key='in_use'`
- 차량 `status='일반'`, `status_action='일정완료'`
- 예약의 고객/전화/배차지/시작/종료/메모를 차량에 반영

반납:
- 예약 `reservation_status='완료'`
- reservation state `tab_key='completed'`
- 차량번호가 있으면 차량을 대기중으로 초기화
  - 기준은 기존 `completeCarReturn()`과 동일

### 3. 일정 수정 동기화
`updateSchedule()`에서 schedule update 후 다음을 추가한다.

조건:
- `reservationId`를 인자로 추가로 받는다.
- `reservationId`가 비어 있으면 예약원장 동기화 생략.

배차 일정:
- 예약 `start_at = scheduleAt`
- 예약 `pickup_location = locationText`

반납 일정:
- 예약 `end_at = scheduleAt`
- 예약 `dropoff_location = locationText`

기타 일정:
- 예약원장 동기화 없음.

### 4. UI 변경
`_completeSchedule()` 실행 전 확인창 추가.

문구:
- 제목: `일정 완료`
- 메시지: `이 일정을 완료 처리하고 연결된 예약/차량 상태를 함께 갱신합니다.`
- 확인 버튼: `완료`

`_editSchedule()`에서 `updateSchedule()` 호출 시 `reservationId: record.reservationId` 전달.

### 5. 검증
실행할 검증:
- `flutter analyze`
- 필요 시 기존 관련 test가 있으면 선택 실행

수동 QA 포인트:
1. 배차 일정 완료 → 예약원장 `배차중`, 차량 일반/보험/장기 현황 진입 확인
2. 반납 일정 완료 → 예약원장 `완료`, 차량 `대기중` 확인
3. 배차 일정 수정 → 예약 상세 배차일/배차지 변경 확인
4. 반납 일정 수정 → 예약 상세 반납일/반납지 변경 확인
5. 연결 없는 기타 일정 완료/수정은 기존처럼 일정만 처리

### 6. 되돌리기
- 이번 phase는 앱 코드 변경만 한다.
- DB schema 변경 없음.
- 문제 발생 시 Phase 1 커밋 revert로 되돌린다.

---

## Phase 1 구현 기록

구현 상태: 코드 반영 완료, 검증 진행 완료.

반영 내용:
- 일정 완료 전 확인창 추가
- 일정 완료 시 `schedule_done=true`, `updated_at` 기록
- 배차 일정 완료 시 예약 상태 `배차중`, 예약 탭 `in_use`로 변경
- 반납 일정 완료 시 예약 상태 `완료`, 예약 탭 `completed`로 변경
- 반납 일정 완료 시 차량을 기존 반납완료 기준으로 `대기중` 초기화
- 일정 수정 시 연결 예약 동기화
  - 배차 일정: 예약 `start_at`, `pickup_location`
  - 반납 일정: 예약 `end_at`, `dropoff_location`

검증:
- `flutter analyze` 통과

남은 QA:
- 실기기에서 배차 일정 완료 후 예약이 배차중 탭으로 이동하는지 확인
- 실기기에서 반납 일정 완료 후 예약이 완료 탭으로 이동하고 차량이 대기중으로 보이는지 확인
- 일정 수정 후 예약 상세 날짜/위치가 즉시 반영되는지 확인

---

## Phase 2 구현 기록

구현 상태: 코드 반영 완료, 검증 진행 완료.

반영 내용:
- 예약 상세 기능 버튼 맨 앞에 `수정` 버튼 추가
- 예약 수정 다이얼로그 추가
  - 외부예약번호, 고객명/전화/생년월일, 소개처, 가격, 배차/반납 일시, 배차지/반납지, 메모
- 예약 수정 저장 시 예약원장 갱신
  - `reservation_number`, 고객 정보, 소개처, 가격, 배차/반납 일시, 배차지/반납지, 메모
- 예약 수정 저장 시 연결 일정 동기화
  - 배차 일정: 예약번호, 배차일, 배차지, 메모
  - 반납 일정: 예약번호, 반납일, 반납지, 메모
- 예약 상세 가격 표시를 콤마/원 형식으로 변경
- 예약 상세 메모는 상태 요약 배지가 섞인 값이 아니라 원본 `note_text`만 표시
- `ReservationRecord`에 `dropoffLocation`, `rawNoteText` 필드 추가

검증:
- `flutter analyze` 통과
- `flutter test test/ims_reservation_payload_test.dart` 통과
- `git diff --check` 통과

확인 필요:
- 기존 `test/widget_test.dart`는 Supabase auth 초기화/세션 의존성 때문에 현재 테스트 환경에서 실패한다.
- Phase 2 기능 자체의 analyze/관련 IMS payload 테스트는 통과했다.

남은 QA:
- 실기기에서 예약 상세 수정창 저장 후 예약 상세 값이 갱신되는지 확인
- 일정 탭의 배차/반납 일정 날짜와 위치가 함께 바뀌는지 확인
- 가격 표시가 `163,400원` 형식으로 보이는지 확인
