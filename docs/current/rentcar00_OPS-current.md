# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 실행 중인 작업 1건만 적는다.
완료된 기능과 운영 확인 포인트는 `docs/completed/rentcar00_OPS-completed.md`로 옮긴다.

---

## 현재 active 작업
**직원관리 MVP 기준 확정**

## 현재 기준점
- 최신 커밋: `0dfad13 Remove macOS platform files`
- 최신 APK: `rentcar00_ops-app-release-arm64-b40-d95f2bc.apk`
- GDrive `rentcar00_OPS/apk/`에는 최신 APK 1개만 유지한다.
- macOS platform 폴더는 삭제 완료했다.
- 최신 완료 내역은 `docs/completed/rentcar00_OPS-completed.md`에 정리됨:
  - `2026-05-18 — macOS platform 폴더 삭제`
  - `2026-05-18 — 앱 아이콘 빵빵카 워드마크 반영`
  - `2026-05-18 — GDrive APK 과거 버전 정리`
  - `2026-05-18 — 예약취소 + IMS 삭제 + 예약생성 다이얼로그 정리`

## 직원관리 MVP에서 잠글 것
1. 직원 계정 생성 방식
   - 앱에서 직접 Auth user 생성할지
   - 중간서버/관리자 API를 둘지
   - Supabase Console 수동 생성 후 staff row만 앱에서 관리할지
2. 직원 비활성 처리 기준
   - Auth 삭제보다 `staff_accounts.is_active=false` 차단 우선
3. 권한 범위
   - admin / staff 최소 2단계로 시작
4. 화면 범위
   - 직원 목록
   - 직원 상세
   - 활성/비활성 전환
   - 역할 변경
5. 감사/로그
   - 누가 언제 직원 상태를 바꿨는지 기록할지 결정

## 다음 실행 전 확인
- 직원관리 구현은 Auth/RLS와 연결되므로 계획 보고 후 승인받고 진행한다.
- build/APK/GDrive 업로드는 별도 승인 전 실행하지 않는다.
- macOS platform은 다시 생성하지 않는다.
