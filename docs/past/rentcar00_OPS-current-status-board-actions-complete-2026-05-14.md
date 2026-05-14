# rentcar00_OPS Current Snapshot Archive

원본 파일: `docs/rentcar00_OPS-current.md`
아카이브 시각: 2026-05-14 KST
사유: 현황판 차량 상태별 액션 분기, 반납 완료, 일정완료/삭제, 일정탭 일정생성 1차 구현이 완료되어 current 문서를 다음 작업 기준으로 교체한다.

---

# rentcar00_OPS Current

## 1. 현재 작업
현황판 차량 상태별 액션 분기 + 반납 상태복귀 구현.

## 2. 현재 범위
- IMS 예약추가 1차 구현은 완료로 본다.
- 현재 task는 **현황판 차량 상태에 따라 다른 기능을 노출**하는 작업 1건만 본다.
- 1차 목표는 **대기 차량 배차 액션 / 배차중 차량 반납 액션**을 분리하는 것이다.

## 3. 오늘 기준 현재 상태 점검 (2026-05-14 02:05 KST)
### 완료
- 차량 상세 → 예약생성 가능
- 예약생성 + IMS 체크 가능
- 예약 상세 → 독립 `IMS 예약추가` 가능
- AI파서 원문 메모 저장 가능
- IMS dry-run / 실저장 / 삭제 검증 완료

### 미완료
- 현황판 차량 상태에 따라 액션 종류가 달라지지 않음
- 현재 차량 상세 `기능` 영역에는 아래가 **상태 구분 없이 같이 노출**됨
  - 예약생성
  - 보험대차
  - 일반대차
  - 장기대차
  - 외부세차
  - 실내세차
  - 주차
- 보험/장기/일반 운행 차량 전용 `반납 완료` 버튼 없음
- 반납 시 상태복귀 + 세차초기화 + 주차지 기본화 로직 없음

## 4. 이번 작업에서 잠글 규칙
### 4-1. 대기 상태 차량
노출 기능:
- 예약생성
- 보험대차
- 일반대차
- 장기대차
- 세차 토글
- 주차지 수정

### 4-2. 보험 / 일반 / 장기 상태 차량
노출 기능:
- 반납 완료
- 세차 토글
- 주차지 수정

### 4-3. 반납 완료 실행 규칙
버튼 실행 시 아래를 한 번에 반영한다.
- `status = 대기중`
- `status_action = 반납 완료`
- `car_wash = FALSE`
- `interior_wash = FALSE`
- `parking_location = 수푸레`

### 4-4. 확인 필요 항목
아래는 구현 전 다시 확인한다.
- 고객명/고객번호/start_at/end_at/pickup_location/note_text 를 같이 비울지
- 반납 버튼 노출 기준을 `tab` 기준으로 볼지 `status` 기준으로 볼지

## 5. 파일 기준점
- 현황판 상세 UI: `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- 차량 상태 저장: `lib/data/repositories/supabase_ops_repository.dart`
- 상태판 레코드 해석: `lib/data/repositories/supabase_ops_repository.dart`

## 6. 다음 실행 순서
1. 현재 상태/탭 분기 기준 확인
2. 대기 차량 액션 묶음 / 운행 차량 액션 묶음 분리
3. `반납 완료` 저장 함수 추가
4. 세차/주차지 기본값 반영
5. 검증 후 배포
