# COMPLETE 2026-06-26 — rentcar00_OPS homepage link with pending badge

## 완료 범위
- 앱 상단 🌐 버튼은 예약 상세 shortcut이 아니라 `https://rentcar00.com` 외부 홈페이지를 연다.
- 관리자/admin은 홈페이지 미확인 건이 있으면 같은 🌐 버튼에 숫자 배지를 본다.
- 관리자/admin은 미확인 건이 없어도 일반 🌐 홈페이지 버튼을 본다.
- staff는 기존 owner-only UI 규칙대로 홈페이지 버튼을 보지 않는다.
- 메뉴/분기/bottom sheet/예약상세 자동 이동은 포함하지 않았다.

## 변경 파일
- `lib/app/view/app_shell.dart`
- `test/widget_test.dart`
- `docs/COMPLETED/rentcar00_OPS-completed.md`
- `docs/COMPLETED/COMPLETE_20260626_rentcar00_OPS_homepage_link_with_pending_badge_pm.md`
- `docs/PHASE/rentcar00_OPS_homepage_pending_badge_only_pm.md`

## 검증
- `dart format lib/app/view/app_shell.dart test/widget_test.dart`
- `flutter analyze` 통과
- `flutter test test/widget_test.dart` 통과: 5 tests passed
- `flutter test` 통과: 24 tests passed

## 보호 대상 확인
- DB/RLS/Supabase migration 변경 없음.
- `.env`, runtime config, deploy/restart, `output/` 변경 없음.
- commit 없음.

## 남은 리스크
- 실제 외부 브라우저 열림은 플랫폼 `url_launcher` 동작에 의존한다.
- 앱 내 UI 권한 제한만 다뤘고 서버/RLS 권한 정책은 별도 범위다.
