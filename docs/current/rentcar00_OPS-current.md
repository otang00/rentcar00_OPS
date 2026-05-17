# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 실행 중인 작업 1건만 적는다.
완료된 기능과 운영 확인 포인트는 `docs/completed/rentcar00_OPS-completed.md`로 옮긴다.

---

## 현재 active 작업
**IMS 가져오기 예약생성 연동**

## 목적
예약생성 화면에서 기존 IMS 예약을 조회/선택해 OPS 예약을 생성하고, IMS 새 생성 없이 기존 IMS `schedule_id/detail_id`를 external link로 저장한다.

---

## 현재 구현 상태
- 앱 endpoint: `ImsReservationClient.completeReservationReturn()`
- 중간서버 endpoint: `POST /ims/complete-reservation-return`
- 중간서버 호출 대상:
  - `POST https://api.rencar.co.kr/v2/normal-contracts/{contractId}/set-done`
- body:
  - `done_at`
  - `return_gas_charge`
  - `driven_distance_upon_return`
  - `fuel_cost`
- 앱은 `externalDetailId`를 우선 `contractId`로 사용하고, 없으면 `externalReservationId`를 fallback으로 사용한다.
- 예약상세 반납완료와 반납 일정상세 완료는 IMS 연결 원장이 있으면 반납 유류량/주행거리/유류비 입력창을 먼저 띄운다.
- 예약생성 화면은 `AI파서` 옆에 `IMS 가져오기` 버튼을 제공한다.
- IMS 가져오기 선택 시 OPS 예약 생성 후 `external_reservation_id=schedule_id`, `external_detail_id=detail_id`만 저장한다.
- 예약생성 하단 체크박스 기본값은 체크이며, 라벨은 `IMS연동생성`이다.

## 확정 원인
1. 기존 `/v2/rent-contracts/{id}/return-gas-charge`는 실제 IMS UI 반납완료 플로우가 아니었다.
2. 성공 플로우는 `/v2/normal-contracts/{detail_id}/set-done`이다.
3. `return_gas_charge`, `driven_distance_upon_return`, `fuel_cost`가 필요하다.

---

## 실테스트 원칙
- 실제 IMS 상태를 변경한다.
- 테스트 예약 1건만 생성한다.
- 테스트 차량은 이전 검증과 동일하게 우선 `101허4041` 사용, 필요 시 `101허4014` 보조 사용.
- 테스트 예약 memo에는 `OPS_RETURN_TEST`와 테스트 시각을 명확히 남긴다.
- 로그/문서에는 IMS 비밀번호, JWT, cookie, 토큰을 남기지 않는다.
- 실패하더라도 무단 우회로 삭제/반납 대체하지 않는다.
- 삭제 API를 반납 대체로 사용하지 않는다. 삭제는 cleanup 용도만 사용한다.

---

## Phase 계획
### Phase 0 — 사전 상태 확인
종료 조건:
- 작업트리가 깨끗한지 확인한다.
- 중간서버 env에 `IMS_ID/IMS_PW`가 준비되어 있는지 값 노출 없이 확인한다.
- 현재 `/ims/create-reservation`, `/ims/complete-reservation-return` 코드 경로를 재확인한다.
- IMS 테스트 차량 `101허4041`, `101허4014`의 available 조회 가능성을 확인한다.

### Phase 1 — 테스트 예약 생성
종료 조건:
- 중간서버 `/ims/create-reservation`으로 실제 IMS 테스트 예약 1건을 생성한다.
- 생성 결과에서 `schedule_id`와 `detail_id`를 확보한다.
- 둘 중 하나라도 못 얻으면 반납 테스트로 넘어가지 않고 원인 분석한다.

테스트 payload 기준:
- carNumber: `101허4041`
- rentalAt/returnAt: 미래 짧은 시간대
- customerName: `OPS반납테스트`
- customerPhone: 테스트용 번호
- memo: `OPS_RETURN_TEST:{timestamp}`

### Phase 2 — 반납완료 endpoint 직접 검증
종료 조건:
- 먼저 `detail_id`로 `/ims/complete-reservation-return`을 호출한다.
- 실패하면 status/body/message를 redact해서 기록한다.
- 필요 시 같은 테스트건 기준으로 `schedule_id` 호출 가능성은 API 의미 확인용으로만 검토한다. 단, 중복 반납/파괴적 재시도는 하지 않는다.
- 성공 기준:
  - API 응답 success 또는 2xx
  - IMS 목록에서 배차중 상태가 해소됨
  - 완료/종결 목록 또는 상세 상태에서 반납완료 확인됨

### Phase 3 — 실패 원인 수정
가능한 수정 방향:
1. `externalDetailId`가 없을 때 중간서버가 `schedule_id`로 IMS 목록/export 조회 후 `detail_id`를 resolve한다.
2. `done_at` formatter를 실제 IMS 요구 형식으로 수정한다.
3. `return_gas_charge`/주행거리 기본값이 문제면 앱/중간서버 payload 기준을 수정한다.
4. API endpoint가 다르면 `IMS_API_MANUAL.md`와 중간서버 endpoint를 갱신한다.

종료 조건:
- 수정 후 동일 유형 테스트에서 IMS 반납완료 성공.
- 앱 경로가 `externalDetailId` 없는 binding에도 안전하게 동작.

### Phase 4 — cleanup
종료 조건:
- 반납완료된 테스트 예약을 삭제 가능한지 확인한다.
- 삭제 API가 허용되면 테스트 예약을 삭제한다.
- 삭제가 불가하면 테스트 예약 ID, schedule_id, detail_id, 상태를 문서에 남긴다.

### Phase 5 — 검증/문서/빌드
종료 조건:
- `IMS_API_MANUAL.md` 업데이트
- `reservation_ai_parser/README.md` 업데이트
- `docs/current`/`docs/completed` 정리
- `flutter analyze`
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart`
- `npm --prefix reservation_ai_parser run check`
- `git diff --check`
- 필요 시 build number 증가, APK 빌드/업로드

---

## 예상 수정 파일
- `reservation_ai_parser/src/server.js`
- `reservation_ai_parser/README.md`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `IMS_API_MANUAL.md`
- `docs/current/rentcar00_OPS-current.md`
- 완료 시 `docs/completed/rentcar00_OPS-completed.md`

---

## 진행 상태
- 2026-05-17 KST 사장님이 IMS 반납 연동 실패를 알려줌.
- 실테스트 및 수정 준비 계획 잠금.
- 2026-05-17 20:20 KST 실예약 `1209357 / 예약번호 204337 / 125호6498` IMS 반납완료 성공.
- 성공 payload 기준으로 parser 서버와 앱 입력 흐름 수정 완료.
- 예약상세 반납완료와 반납 일정상세 완료 모두 IMS 연결 시 `IMS 반납 정보 입력` 창을 띄운다.
- 검증 완료:
  - `npm --prefix reservation_ai_parser run check`
  - `flutter analyze`
  - `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart`
  - `git diff --check`
- 운영 IMS 재호출/추가 실반납 테스트는 아직 수행하지 않았다.
- IMS 가져오기 1차 구현 완료. IMS 조회는 read-only로 확인했고 상태 변경은 하지 않았다.
- b35 APK 빌드/업로드 완료: `rentcar00_ops-app-release-arm64-b35-39191a4.apk`.
