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
- `pubspec.yaml`

## 검증
- `git diff --check` 통과
- `flutter analyze` 통과
- `flutter test test/widget_test.dart` 통과: 5 tests passed
- `flutter test` 통과: 24 tests passed
- `flutter build apk --release --target-platform android-arm64 --build-name=1.0.0 --build-number=54` 통과

## 배포 확인
- Commit: `200ec98 fix: open homepage from pending badge`
- Android build number: `1.0.0+54`
- APK: `build/releases/rentcar00_ops-app-release-arm64-b54-200ec98.apk`
- GDrive: `rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b54-200ec98.apk`
- GDrive APK 폴더에는 최신 b54 APK 1개만 남김.
- Upload size: `20,570,999 bytes`
- SHA-256: `e3676721eee238e0c0297c228d3e81f6fd1a1a8eca7903274aa35be11794ae7a`

## 보호 대상 확인
- DB/RLS/Supabase migration 변경 없음.
- `.env`, runtime config, restart 변경 없음.
- `output/` 변경 없음.

## 남은 리스크
- 실제 외부 브라우저 열림은 플랫폼 `url_launcher` 동작에 의존한다.
- 앱 내 UI 권한 제한만 다뤘고 서버/RLS 권한 정책은 별도 범위다.
