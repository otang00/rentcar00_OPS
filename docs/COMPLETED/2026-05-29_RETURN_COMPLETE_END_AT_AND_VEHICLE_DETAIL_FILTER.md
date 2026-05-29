# 반납완료 예약 종료시각/차량상세 필터 수정 완료

## 완료 범위
- 반납 일정 `반납완료` 처리 시 예약원장 `end_at`을 실제 완료 처리 시각으로 갱신하도록 수정했다.
- 차량상세 예약 가능 캘린더에서 완료/취소/과거 종료 예약을 제외하도록 필터를 보강했다.

## 변경 파일
- `lib/data/repositories/supabase_ops_repository.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`

## 동작 기준
- 조기반납이면 기존 예정 반납일시가 아니라, 반납완료 버튼을 누른 시각이 예약원장 반납일시가 된다.
- 반납완료 예약은 상태 `완료`, 탭 `completed`, `end_at=완료 처리 시각` 기준으로 정리된다.
- 차량상세 캘린더는 아래 예약을 표시하지 않는다.
  - `예약취소`
  - `완료`
  - completed 탭 예약
  - 현재 시각보다 종료시각이 과거인 예약

## 검증
- `dart format lib/data/repositories/supabase_ops_repository.dart lib/features/status_board/detail/presentation/status_board_detail_page.dart` 완료
- `flutter analyze` 통과
- `flutter test` 통과
- `git diff --check` 통과

## 남은 리스크 / 후속
- 기존에 이미 완료 처리됐지만 `end_at`이 미래로 남아 있는 과거 데이터는 이번 코드 수정만으로 자동 보정하지 않는다.
- 필요한 경우 특정 예약만 확인 후 운영 DB 보정은 별도 승인으로 진행한다.
