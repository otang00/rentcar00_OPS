# Issue Report — IMS 연동 배차중 예약 반납예정일 미동기화

- Date: 2026-07-30
- Project: rentcar00_OPS
- Status: open
- Type: issue report

## Summary

배차중 차량의 OPS 예약/일정에서 반납일을 변경할 때, 해당 예약이 IMS에 연결되어 있으면 IMS 예약의 반납예정일도 함께 수정되어야 한다.

현재 확인 기준으로는 OPS 반납일 변경은 OPS DB에는 반영되지만, IMS 예약의 반납예정일 수정 호출은 연결되어 있지 않다.

## Expected Behavior

IMS 연결 예약이면서 현재 배차중인 건에 대해 OPS에서 반납일/반납일시를 변경하면:

1. OPS 예약 `end_at` 변경
2. OPS 반납 일정 `schedule_at` 변경
3. IMS 연결 정보 확인
4. IMS 예약의 반납예정일도 동일한 값으로 수정
5. 성공/실패 결과를 action log에 기록

## Current Observed Behavior

OPS 예약 수정 흐름은 다음까지만 수행한다.

```text
예약 end_at 변경
→ OPS 반납 일정 schedule_at 변경
→ OPS 상태/탭 재계산
```

IMS 연결건이어도 현재 흐름에서 IMS 반납예정일 수정 호출은 수행하지 않는다.

## Relevant Current Code

OPS 예약 수정 흐름:

```text
lib/features/reservations/detail/presentation/reservation_detail_page.dart
lib/data/repositories/supabase_ops_repository.dart
```

IMS client:

```text
lib/features/reservations/detail/data/ims_reservation_client.dart
```

Parser IMS endpoint:

```text
reservation_ai_parser/src/server.js
```

## Important Finding

기존 `/ims/change-reservation-car` endpoint는 `returnAt` payload를 받지만, 현재 실제 IMS 호출은 차량 변경만 수행하는 구조다.

```text
POST /v2/company-car-schedules/{scheduleId}
body: { company_car_id: ... }
```

따라서 현재 구현만으로는 IMS 반납예정일이 변경되지 않는다.

## Required Fix Direction

배차중 + IMS 연결 예약에서 반납일 변경 시 전용 IMS 반납예정일 수정 흐름이 필요하다.

Candidate phases:

1. IMS 반납예정일 수정 API 경로 확인 및 parser endpoint 추가
2. OPS 예약 수정 흐름에서 반납일 변경 감지
3. IMS 연결건이면 IMS 반납예정일 수정 호출
4. action log에 성공/실패 기록
5. dry-run/테스트 및 `flutter analyze` 검증

## Risks

- IMS API의 실제 반납예정일 수정 필드명이 확인되지 않으면 잘못된 payload가 무시될 수 있다.
- OPS 변경 성공 후 IMS 변경 실패 시 양쪽 반납일이 불일치할 수 있다.
- 배차중이 아닌 예약까지 무조건 IMS 수정하면 이미 완료/취소된 IMS 예약에 영향을 줄 수 있다.

## Non-goals for This Report

- 코드 수정 없음
- IMS 실제 호출 테스트 없음
- 배포/재시작 없음
