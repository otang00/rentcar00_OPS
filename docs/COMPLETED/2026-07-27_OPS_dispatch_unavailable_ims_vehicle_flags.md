# 2026-07-27 — 배차불가 버튼 및 IMS 일배차/월배차 flag 연동

## 완료 내용

- 기존 `수리중/수리완료` UX를 `배차불가/배차가능` 기준으로 전환했다.
- 차량 상세에서 `배차불가`를 누르면 IMS 차량의 일배차와 월배차 flag를 먼저 끈다.
- IMS flag 변경이 성공한 뒤 OPS 차량 상태를 `배차불가`로 저장한다.
- 차량 상세에서 `배차가능`을 누르면 IMS 일배차/월배차 flag를 다시 켠 뒤 OPS 차량 상태를 `대기중`으로 복귀한다.
- 대기 탭에서는 `배차불가` 차량을 idle 영역에 남기되 어두운 배경과 배지로 구분한다.

## IMS 호출

- OPS 앱 client: `ImsReservationClient.updateVehicleRentalFlags`
- parser endpoint: `POST /ims/update-vehicle-rental-flags`
- IMS 조회: `GET /v2/rent-company-cars`
- IMS write: `POST /v2/rent-company-cars/{carId}/flags`

## 실패 처리

- IMS 차량번호 exact match가 없거나 복수면 실패한다.
- IMS flag 변경 실패 시 OPS 차량 상태는 변경하지 않는다.
- 이 기능은 실제 IMS 상태 변경을 포함하므로 parser 운영 반영/restart 이후에만 현장 사용 가능하다.

## 주요 파일

- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`

## 남은 확인

- parser restart는 이번 커밋 범위가 아니다.
- 찜카/카모아/홈페이지까지 자동 반영하는 외부 차량상태 sync runner는 현재 별도 write 경로가 열려 있지 않다.
