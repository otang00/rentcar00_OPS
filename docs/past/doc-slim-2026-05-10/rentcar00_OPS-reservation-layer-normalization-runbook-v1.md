# rentcar00_OPS Normalization Runbook v1

## 1. 목적
이 문서는 raw import 이후 `rc00_ops_reservations`, `rc00_ops_reservation_states` 로
1차 정규화를 수행하는 기준을 고정한다.

## 2. 입력
- latest `sync_run_id`
- `rc00_ops_sheet_reservations_raw`
- `rc00_ops_sheet_schedules_raw`

## 3. 현재 1차 규칙
### reservation 원장
- 원장은 `예약` raw 기준으로만 생성
- `reservation_id` 를 primary upsert 키로 사용
- `pickup_location` 은 우선 `배반차위치` 원문을 그대로 저장
- `meta_json` 에 raw payload 원문 유지

### state 계산
- `예약취소` 포함 시 `pending + hold`
- 반납일이 오늘 이전이면 `completed + done`
- 반납일이 오늘이면 `return_due + return_due`
- 대여일이 오늘이면 `pickup_today + ready_for_dispatch`
- 대여일이 과거면 `in_use + in_use`
- 그 외는 `pending`

### attention 기준
- 고객명/전화번호/위치 공란 여부 반영
- 1차는 최소 경고만 계산

## 4. 명령
```bash
dart run tool/normalize_raw_to_projection.dart <db-password>
```

## 5. 주의
- 현재는 `일정` raw 를 projection 계산에 아직 적극 반영하지 않는다.
- `일정` 은 다음 phase 에 reservation 연결 보강용으로 사용한다.
- 수동 override 는 state 테이블에 남기고 정규화가 덮어쓰지 않도록 이후 보강 필요.
