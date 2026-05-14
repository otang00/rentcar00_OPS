# rentcar00_OPS 과거 진행 정리

이 문서는 완료된 단계와 지난 기준점을 보관하는 archive 문서다.
현재 실행 기준은 `docs/rentcar00_OPS-current-index-progress.md` 부터 본다.

## 1. 초기 환경 구성 완료
- Flutter / Android Studio / Android SDK 준비 완료
- 프로젝트 경로: `projects/rentcar00_OPS`
- GitHub 저장소 연결 완료
- Flutter Android 앱 기본 구조 생성 완료

## 2. 초기 앱 골격 완료
- 메인 라우팅 구성 완료
- 상단 `예약 / 현황판` 2레이어 스위치 구조 반영 완료
- 예약 5탭 / 현황판 5탭 골격 반영 완료
- Sync / Search / 공용 상세 기본 구조 반영 완료

## 3. Supabase / 시트 import 기반 완료
- Google Sheets read-only 접근 확인 완료
- raw import tooling 추가 완료
- 초기 normalize 흐름 추가 완료
- 원격 Supabase 프로젝트 연결 완료
- migration 적용 경로 확보 완료

## 4. RAW / OPS 분리 완료
- 적용 migration:
  - `20260508154107_initial_rc00_ops_schema.sql`
  - `20260509002000_simplify_reservation_states.sql`
  - `20260510121500_add_sheet1_cars_table.sql`
  - `20260511195000_split_raw_and_ops_tables.sql`
- RAW 계층:
  - `rc00_ops_import_runs`
  - `rc00_ops_cars_raw`
  - `rc00_ops_reservations_raw`
  - `rc00_ops_schedules_raw`
- OPS 계층:
  - `rc00_ops_cars`
  - `rc00_ops_reservations`
  - `rc00_ops_schedules`
  - `rc00_ops_reservation_states`
  - `rc00_ops_action_logs`
  - `rc00_ops_outbox`

## 5. 현재까지 완료된 구현
- 현황판 read/write 를 OPS 테이블 기준으로 전환 완료
- 예약생성 / instant 차량 상태 수정 / 일정 생성 1차 연결 완료
- 차량 상세에 아래 필드 1차 반영 완료
  - `차량등록일`
  - `차량검사일`
  - `차령만료일`
  - `차량번호(앞/중/네자리)`
- related 일정 상단 배치 및 과거 일정 제외 1차 반영 완료
- 일정 탭에서 일정 상세 → 예약 상세 연결 1차 반영 완료

## 6. APK 배포 과거 기준 정리
- 기본 배포물은 debug APK가 아니라 arm64 release APK다.
- 업로드 위치는 `gdrive:rentcar00_OPS/apk/` 다.
- 최근 업로드 파일:
  - `rentcar00_ops-app-release-arm64-b9-93f5a22.apk`
  - `rentcar00_ops-app-release-arm64-b10-93f5a22.apk`
  - `rentcar00_ops-app-release-arm64-b11-849f66b.apk`

## 7. 과거 기준점 메모
- 과거 기준 잠금 커밋으로 `10e2e04` 가 기록돼 있다.
- 이후 raw/ops 분리, 문서 정리, APK 재배포까지 더 진행된 상태다.
- 최신 실행 우선순위와 다음 할 일은 archive가 아니라 current 문서에서 관리한다.
