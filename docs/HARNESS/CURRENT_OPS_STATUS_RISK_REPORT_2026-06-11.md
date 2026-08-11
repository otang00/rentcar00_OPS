# 현재 OPS 앱 상태·구조·충돌점·리스크 보고

작성일: 2026-06-11  
기준 커밋: `ef066cc docs: add OPS harness state maps`  
브랜치: `fix/ops-return-complete-end-at`

## 1. 결론

현재 OPS 앱은 예약/차량/일정/직원/IMS/홈페이지 이벤트 수신까지 연결된 운영 MVP 상태다.  
핵심 기능은 대부분 구현되어 있지만, 다음 배포 전에는 **미커밋 앱 변경 3개 파일의 포함 여부**를 먼저 확정해야 한다.

가장 큰 리스크는 아래 4개다.

1. `pubspec.yaml`이 이미 `1.0.0+49`로 변경되어 있어 b50 배포 기준과 충돌 가능
2. 직원도 관리자 메뉴 화면으로 들어가 로그아웃할 수 있게 바뀐 변경이 아직 미커밋
3. 홈페이지 실제 송신부/소스/배포 상태 미확인
4. 가격/차량 그룹 정책 owner 미확정

---

## 2. 현재 작업트리 충돌점

현재 미커밋 앱 변경:

```txt
M lib/app/view/app_shell.dart
M lib/features/admin/presentation/admin_home_page.dart
M pubspec.yaml
```

### 2-1. `lib/app/view/app_shell.dart`

변경 내용:
- `_openAdminMenu`가 `_openAccountMenu`로 바뀜
- 기존에는 비관리자가 누르면 `관리자만 접근할 수 있습니다.` snackbar 표시
- 현재 변경은 비관리자도 `AppRoutes.admin`으로 이동

의미:
- 관리자 전용 진입 차단에서, 계정/직원 메뉴 진입 허용 구조로 변경됨
- 관리자 메뉴가 사실상 `계정 메뉴` 역할까지 갖게 됨

리스크:
- 기존 UX 문구와 권한 경계가 바뀜
- 관리자 route 이름은 그대로인데 직원도 접근하므로 의미 충돌 가능
- 다른 화면에서 admin route를 관리자 전용으로 가정하면 혼동 가능

판단:
- b49 직원 로그아웃 기능 변경으로 보임
- 예약 상세 수정/b50 배포와 직접 관련 없음
- 배포에 포함하려면 "직원 로그아웃 메뉴" 변경으로 별도 커밋/문서화가 안전

### 2-2. `lib/features/admin/presentation/admin_home_page.dart`

변경 내용:
- 비관리자 접근 차단 화면 `_AdminBlockedView` 제거
- 비관리자에게 `_StaffMenuView` 표시
- 직원 메뉴에 현재 로그인 직원 정보와 로그아웃 ListTile 추가
- 로그아웃 시 `authControllerProvider.signOut()` 후 login route 이동

의미:
- 관리자 홈이 관리자 전용 화면에서 관리자/직원 공용 계정 메뉴로 확장됨

리스크:
- class 이름/route 이름은 여전히 AdminHomePage라 의미 혼재
- 비관리자에게 표시해도 되는 기능만 남아 있는지 계속 확인 필요
- 직원 메뉴와 관리자 메뉴가 같은 route를 공유해 권한 테스트 필요

판단:
- 구조적으로는 계정 메뉴 분리 또는 route rename 후보
- 당장 배포하려면 최소 widget/smoke 테스트 필요

### 2-3. `pubspec.yaml`

변경 내용:
- `version: 1.0.0+48` → `1.0.0+49`

의미:
- 이미 b49 배포 기준으로 build number가 올라가 있음
- GDrive 최신도 `b49-staff-logout-f87e545.apk`로 확인됨

리스크:
- 다음 배포는 `+50`이어야 하는데 현재 미커밋 `+49` 상태라 기준이 섞임
- 이 변경이 커밋되지 않은 채 예약 상세 수정까지 들어가면 b50 diff가 복잡해짐

판단:
- b49 배포를 정식 코드 기준으로 남기려면 먼저 이 변경을 관련 앱 변경과 함께 커밋해야 함
- 예약 상세 수정 배포는 그 다음 `+50`으로 별도 진행하는 것이 안전

---

## 3. 구조 상태 요약

### 예약/일정/차량 상태 owner
- 저장소: Supabase
- 앱 owner: `SupabaseOpsRepository`
- 주요 상태:
  - `rc00_ops_reservations`
  - `rc00_ops_reservation_states`
  - `rc00_ops_schedules`
  - `rc00_ops_cars`

### 외부 연동 owner
- IMS 실제 상태 owner: IMS API
- OPS 연결 상태: `rc00_ops_external_reservation_links`
- Parser adapter: `reservation_ai_parser/src/server.js`

### 홈페이지 이벤트 owner
- 홈페이지: event producer여야 함
- OPS parser: signed event receiver/importer
- 상태:
  - `rc00_ops_reservation_events`
  - 생성된 예약/상태/일정

### projection/refresh
- Supabase Realtime은 source of truth가 아니라 refresh trigger
- 수동 새로고침은 계속 유지 필요

---

## 4. 현재 리스크 우선순위

### P0. 배포 범위 불명확
- 현재 앱 미커밋 변경이 이미 존재
- 예약 상세 수정과 섞이면 어떤 변경이 APK에 들어갔는지 추적이 어려움

대응:
1. b49 직원 로그아웃 변경을 먼저 정식 커밋할지 결정
2. 그 후 예약 상세 수정은 b50으로 별도 진행

### P1. route/권한 의미 충돌
- `AdminHomePage`가 직원 메뉴도 담당하게 됨
- 실제로는 `Account/Admin menu`가 되었지만 이름은 admin 유지

대응:
- 단기: 현재 변경을 직원 로그아웃 메뉴로 문서화하고 테스트
- 중기: 계정 메뉴 route와 관리자 메뉴 route를 분리

### P1. 홈페이지 상태 미확인
- OPS 수신부는 구현되어 있으나 홈페이지 송신부 확인 없음

대응:
- 홈페이지 repo/URL/배포 플랫폼 확인
- 실제 예약 1건 end-to-end 테스트

### P1. 가격 정책 owner 미확정
- 차량 그룹별 가격 정책이 OPS/홈페이지/IMS/정산에 모두 연결됨

대응:
- 가격 정책 State Map을 먼저 확정
- 그 후 생성/수정/홈페이지/IMS import 적용 범위 결정

### P2. IMS 보상 흐름
- 외부 IMS 성공/실패와 OPS link 상태가 분리됨

대응:
- 장애 발생 전 command별 성공/실패/보상표 작성

---

## 5. 다음 실행 권장 순서

1. 현재 미커밋 b49 직원 로그아웃 변경 검증/커밋 여부 결정
2. 예약 상세 `상세정보` 누락 수정은 별도 b50 phase로 진행
3. b50 배포 전 `flutter test` + `flutter build apk --release --target-platform android-arm64`
4. GDrive `rentcar00_OPS/apk/`에 b50 APK 업로드 후 최신 1개 확인
5. 홈페이지 실제 송신부 확인
6. 차량 그룹/가격 정책 owner 확정

---

## 6. 현재 상태 판단

- 앱 구조: 운영 MVP 수준, 다만 owner 경계 일부 혼재
- 배포 상태: b49 기준으로 보이나 로컬에는 b49 관련 변경이 미커밋
- 다음 수정 가능 여부: 가능하나, 미커밋 변경 정리 후 진행이 안전
- 즉시 중단해야 할 영역: 홈페이지/IMS/DB/배포 외부 상태 변경은 별도 명시 승인 전 금지
