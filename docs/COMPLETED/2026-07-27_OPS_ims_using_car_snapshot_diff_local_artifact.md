# 2026-07-27 — IMS 배차중 snapshot diff 로컬 산출물 보관

## 완료 내용

- IMS 일반대차 `company-car-schedules`와 보험대차 `rencar-claims`의 배차중 목록을 같은 정규형으로 수집하는 로컬 모듈을 추가했다.
- snapshot key는 차량번호가 아니라 `source_type + external_id` 기준으로 잡았다.
- 첫 실행은 bootstrap으로 처리하고 appeared/disappeared lifecycle 후보를 만들지 않는다.
- diff 후보만 detail 조회하도록 테스트를 추가했다.
- API 실패/대량 누락 의심 시 snapshot 품질 guard로 disappeared 처리를 막는다.
- 자동 배차완료/자동 반납완료 전송은 비활성화했다.

## 현재 운영 기준

- 이 산출물은 자동 배반차 기능으로 사용하지 않는다.
- `send-events` mode는 `send_events_disabled`로 차단된다.
- `allowOpsHandoffSend=true`도 `ops_handoff_send_disabled`로 차단된다.
- `signalSave`와 `handoffSend`는 `automatic_lifecycle_disabled` 상태를 반환한다.
- launchd/cron 연결은 없다.

## 주요 파일

- `reservation_ai_parser/src/ims-api-client.js`
- `reservation_ai_parser/src/ims-using-car-snapshot-diff.js`
- `reservation_ai_parser/test/ims-using-car-snapshot-diff.test.js`
- `supabase/migrations/20260726151500_add_ims_using_car_snapshots.sql`
- `docs/ARCHIVE/rentcar00_OPS_ims_two_source_lifecycle_worker_pm_20260726.md`

## 남은 확인

- 자동 lifecycle 처리는 폐기된 방향이다.
- 향후 다시 필요하면 이 파일을 그대로 운영 연결하지 말고, 별도 PM에서 권위/오탐/현장 리스크를 다시 승인받아야 한다.
