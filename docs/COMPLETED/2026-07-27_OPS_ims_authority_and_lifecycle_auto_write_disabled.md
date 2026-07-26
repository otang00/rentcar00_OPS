# 2026-07-27 — OPS 배차/반납 IMS write 제거 및 확인 모달 정리

## 완료 내용

- OPS 일정 목록, 일정 상세, 예약 상세의 배차완료/반납완료 버튼에서 IMS 반납완료 write 호출을 제거했다.
- IMS active binding이 있는 예약은 완료 전에 확인 모달을 띄워 연결 IMS id/source/link 정보를 보여준다.
- 확인 후에는 IMS 계약 상태를 변경하지 않고 OPS 일정만 완료한다.
- 기존 IMS 반납 입력 모달 파일은 삭제했다.
- `rc00_ops_external_reservation_links.source_type`을 앱 모델에 추가해 일반대차/보험대차 연결 출처를 표시할 수 있게 했다.

## 핵심 기준

- OPS는 현황판/일정 원장이다.
- IMS는 계약 원장이다.
- OPS 배차/반납 버튼은 IMS 계약 lifecycle을 write하지 않는다.
- 연결 정보가 있으면 사용자에게 한 번 확인시키되, 완료 자체를 막지는 않는다.

## 주요 파일

- `lib/features/status_board/list/presentation/status_board_tab_page.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`
- `lib/features/reservations/detail/presentation/ims_return_input_dialog.dart`
- `lib/data/models/external_reservation_link.dart`
- `docs/HARNESS/CURRENT_EVENT_FLOW_MAP.md`

## 검증 기준

- `flutter analyze`
- 관련 Flutter 테스트
- parser syntax check
- `git diff --check`

## 남은 확인

- 실기기에서 세 위치의 완료 버튼이 모두 확인 모달 후 OPS 일정만 완료하는지 확인이 필요하다.
- 기존 완료 문서 중 과거 IMS 반납연동 기록은 historical record이며 현재 기준으로 사용하지 않는다.
