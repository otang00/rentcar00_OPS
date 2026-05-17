# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 실행 중인 작업 1건만 적는다.
완료된 기능과 운영 확인 포인트는 `docs/completed/rentcar00_OPS-completed.md`로 옮긴다.

---

## 현재 active 작업
**관리자 기능 준비 + 기능 버튼 UI 정리 + 일정상세 헤더 보정**

## 목적
관리자만 접근 가능한 운영 메뉴를 만들고, 기능 버튼이 계속 늘어나는 상황에 맞춰 버튼 UI 기준을 먼저 정리한다. 동시에 일정상세 화면에서 차량번호 가독성을 높인다.

---

## 현재 코드 검토 요약
### 라우팅/권한
- 라우트는 `AppRoutes`에 `login/home/reservationDetail/statusBoardDetail/scheduleDetail/search/sync`만 있다.
- 모든 주요 화면은 `StaffAccessGate`로 감싸져 있다.
- 직원 계정 모델에는 이미 `role`, `isActive`가 있다.
- `StaffAccountRepository.fetchByAuthUserId()`는 현재 로그인 사용자 조회만 지원한다.

### 홈 상단
- `AppShell` AppBar 왼쪽에 `빵빵카` 텍스트가 있다.
- 현재는 단순 텍스트이며 tap action이 없다.
- `예약추가`는 AppBar actions의 `+` 버튼으로 별도 존재한다.

### 예약상세 기능 버튼
- `_ReservationDetailBody`의 `기능` 섹션 안에서 4열 grid로 표시한다.
- 현재 버튼은 `수정 / 차량변경 / 배차완료 / 반납완료 / 전화 / 문자 / IMS추가 or IMS등록됨`이 한 grid에 섞여 있다.
- `_DetailActionButton`은 `emphasis` boolean 하나로 강조 여부를 결정한다.
- 현재 `수정`, `배차완료`, `반납완료`, `IMS추가`가 모두 강조되어 중요도가 섞인다.

### 일정상세 헤더
- `_ScheduleDetailBody`에서 헤더는 `일정유형 → 날짜/시간 → 차량번호 badge` 순서다.
- 날짜는 `titleLarge`, 차량번호는 `titleSmall`이라 차량번호가 작게 보인다.

---

## 실행 전 확정 제안
### A. 일정상세 헤더 UI
**제안안**
- 일정유형: 현재 `headlineMedium` 유지
- 날짜/시간: 현재 `titleLarge` 유지
- 차량번호 badge:
  - padding `horizontal 14 / vertical 8`
  - radius `12`
  - text style `headlineSmall` 또는 `titleLarge + fontSize 24`
  - 날짜보다 살짝 크게, 일정유형보다는 작게

**예상 화면 흐름**
```text
반납
05/17(일) 15:00
[ 123허4567 ]  ← 날짜보다 살짝 크게
```

### B. 예약상세 기능 버튼 UI
**제안안: 기능 섹션을 3단으로 분리**

1. `상태 처리` 영역
   - 위치: 기능 섹션 최상단
   - 표시 조건:
     - 미배차면 `배차완료`
     - 배차중이면 `반납완료`
     - 그 외 없음
   - UI:
     - 한 줄 full-width 큰 버튼
     - 높이 52~56
     - 왼쪽 icon + 중앙/왼쪽 label + 보조 설명 1줄
   - 색상:
     - 배차완료: primary/blue 계열
     - 반납완료: secondary/green or purple 계열
   - 문구:
     - 배차완료: `연결 배차일정 완료 + 차량 일반 전환`
     - 반납완료: `연결 반납일정 완료 + 차량 대기중 전환`
     - IMS active binding이면 반납완료 설명에 `IMS 반납도 함께 시도` 표시

2. `관리` 영역
   - 버튼: `수정`, `차량변경`, `IMS추가` 또는 disabled `IMS등록됨`
   - UI: 3열 또는 4열 작은 카드
   - 강조색은 제거하고 tonal/light 버튼으로 통일
   - `IMS추가`만 아이콘으로 구분하되 lifecycle급 강조는 하지 않음

3. `연락` 영역
   - 버튼: `전화`, `문자`
   - UI: 작은 카드 또는 outlined tonal
   - 전화번호가 없으면 영역 자체 미표시

**왜 이 방식인지**
- 상태를 바꾸는 버튼과 보조 기능이 섞이지 않는다.
- 이후 기능 버튼이 추가되어도 `관리`, `연락`, `상태 처리` 중 어디에 넣을지 기준이 생긴다.
- 반납완료처럼 IMS까지 건드리는 버튼이 보조 버튼처럼 보이는 문제를 막는다.

### C. 확인 다이얼로그 문구
**배차완료**
```text
배차완료 처리할까요?
- 연결된 배차 일정을 완료 처리합니다.
- 차량 상태를 일반으로 전환합니다.
```

**반납완료 / IMS 없음**
```text
반납완료 처리할까요?
- 연결된 반납 일정을 완료 처리합니다.
- 차량 상태를 대기중으로 전환합니다.
```

**반납완료 / IMS 있음**
```text
반납완료 처리할까요?
- 연결된 반납 일정을 완료 처리합니다.
- 차량 상태를 대기중으로 전환합니다.
- 연결된 IMS 예약도 반납완료를 시도합니다.
```

### D. 관리자 메뉴 1차 UI
**진입**
- 좌상단 `빵빵카` 텍스트를 `InkWell`/`TextButton`처럼 탭 가능하게 변경
- tap 시 현재 로그인 staff role 확인
- `admin`이면 `/admin` 이동
- 아니면 SnackBar 또는 dialog: `관리자만 접근할 수 있습니다.`

**관리자 홈 화면**
- AppBar: `관리자`
- 카드 메뉴 5개:
  1. 직원관리
  2. 차량관리
  3. 작업로그
  4. 출근확인
  5. 앱푸시
- Phase 3에서는 placeholder 화면/카드까지만 만든다.
- 실제 생성/수정/DB 변경은 Phase 4 이후로 분리한다.

---

## 관리자 기능 범위
### 1차 관리자 메뉴
1. 직원관리
   - 직원 목록
   - 직원 추가
   - 권한 변경: `admin / staff`
   - 활성/비활성 처리
   - 로그인 ID / 표시명 관리
2. 차량관리
   - 차량 추가
   - 차량 정보 변경
   - 차량 삭제 또는 비활성 처리
3. 작업로그
   - 누가
   - 언제
   - 어떤 작업을 했는지
   - 관련 예약/차량/직원 기준으로 조회
4. 출근확인
   - Wi‑Fi 기반 출근 버튼
   - 직원별 출근 로그
   - 관리자 출근현황
5. 앱푸시
   - 직원 기기 push token 저장
   - 관리자 공지/알림 발송
   - 자동 알림은 후속 phase

### 관리자 기능 리스크
- 직원 추가는 Supabase Auth 계정 생성과 `rc00_ops_staff_accounts` row 생성이 함께 필요하다.
- 차량 삭제는 과거 예약/로그와 연결될 수 있으므로 실제 삭제보다 비활성 처리를 우선 검토한다.
- 작업로그는 기존 예약 action log와 관리자/차량/직원 변경 로그를 같은 화면에서 볼지, 별도 테이블로 분리할지 결정이 필요하다.
- 앱푸시는 FCM 설정/권한/토큰 저장/서버 발송 경로가 필요해 관리자 MVP 이후 별도 phase가 적합하다.
- Wi‑Fi 출근확인은 Android/iOS 권한 차이가 있고 SSID 위조 가능성이 있어 보조 확인 수단으로 본다.

---

## Phase 계획
### Phase 0 — 실행 전 검토/승인 대기
종료 조건:
- 위 A/B/C/D UI 제안을 사장님이 확인한다.
- 진행 범위를 아래 중 하나로 확정한다.
  1. Phase 1만
  2. Phase 1~2
  3. Phase 1~3
  4. 전체 계속 진행

### Phase 1 — 일정상세 헤더 보정
목적:
- 차량번호 가독성 개선.

작업:
- `_ScheduleDetailBody` 차량번호 badge style 수정.
- 날짜보다 차량번호가 살짝 크게 보이게 조정.

종료 조건:
- 일정상세 날짜 밑 차량번호가 더 크게 보인다.
- 기능 동작 변경 없음.

검증:
- `flutter analyze`
- 필요 시 `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart`

### Phase 2 — 예약상세 기능 버튼 UI 정리
목적:
- 기능 버튼 증가에 대비해 UI 기준 확정.

작업:
- 기능 섹션 내부를 `상태 처리 / 관리 / 연락`으로 분리.
- lifecycle full-width 버튼 컴포넌트 추가.
- `_DetailActionButton` 강조 정책 정리.
- 확인 다이얼로그 문구를 위 C 기준으로 변경.

종료 조건:
- 배차완료/반납완료가 한 줄 큰 버튼으로 보인다.
- 수정/차량변경/IMS가 관리 영역에 묶인다.
- 전화/문자가 연락 영역에 묶인다.
- 반납 IMS 동시 처리 안내가 확인창에 보인다.

검증:
- `flutter analyze`
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart`

### Phase 3 — 관리자 진입/권한 뼈대
목적:
- 관리자 기능을 붙일 안전한 입구 확보.

작업:
- `AppRoutes.admin = '/admin'` 추가.
- `AdminHomePage` 신규 생성.
- `AppShell`의 `빵빵카`를 tap 가능하게 변경.
- 현재 로그인 staff role이 `admin`이면 `/admin` 이동.
- staff면 차단 안내.
- 관리자 홈에 5개 placeholder 카드 표시.

종료 조건:
- admin은 빵빵카 클릭 시 관리자 홈으로 진입한다.
- staff는 차단된다.
- 아직 회원/차량 DB 변경 기능은 없다.

검증:
- `flutter analyze`
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart`

### Phase 4 — 직원관리 MVP 설계 후 구현
목적:
- 관리자 기능 중 최우선인 직원관리 구현.

선행 확인:
- Supabase Auth 계정 생성 방식 결정 필요.
- 앱 클라이언트에서 직접 생성할지, Edge Function/서버로 생성할지 결정 필요.

작업 후보:
- 직원 목록 조회.
- 직원 추가 화면.
- 권한/활성 상태 변경.

종료 조건:
- 직원 목록/추가/상태변경이 동작하거나, Auth 생성 경로가 막히면 설계 문서화 후 대기.

### Phase 5 — 차량관리 MVP
목적:
- 차량 추가/수정/삭제 또는 비활성 처리.

선행 확인:
- `rc00_ops_cars` 스키마와 과거 예약 연결 영향 확인.

작업 후보:
- 차량 목록 조회.
- 차량 추가.
- 차량 정보 수정.
- 삭제 대신 비활성 우선 검토.

### Phase 6 — 작업로그 화면
목적:
- 운영 변경 추적.

선행 확인:
- 기존 예약 action log 구조와 신규 관리자 로그 테이블 필요 여부 확인.

작업 후보:
- 최근 작업로그 화면.
- 예약/차량/직원 필터.
- 관리자 변경 이력 저장.

### Phase 7 — 출근확인/앱푸시 설계
목적:
- 직원관리 이후 붙일 확장 기능 기준 확정.

작업 후보:
- Wi‑Fi 출근확인 권한/패키지 검토.
- 출근 로그 테이블 설계.
- FCM push token 저장 구조 설계.
- 관리자 공지 발송 경로 설계.

---

## 수정 예상 파일
### UI / 앱
- `lib/app/view/app_shell.dart`
- `lib/app/router/app_routes.dart`
- `lib/app/router/app_router.dart`
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/reservations/detail/presentation/reservation_detail_page.dart`
- 신규 `lib/features/admin/...`

### 데이터 / 권한
- `lib/features/auth/domain/staff_account.dart`
- `lib/features/auth/data/staff_account_repository.dart`
- `lib/data/repositories/supabase_ops_repository.dart`
- 필요 시 Supabase migration

### 문서
- `docs/current/rentcar00_OPS-current.md`
- 완료 시 `docs/completed/rentcar00_OPS-completed.md`
- 미래 아이디어: `docs/past/rentcar00_OPS-future-ideas-2026-05-17.md`

---

## 보류 아이디어
차후 기능 아이디어는 `docs/past/rentcar00_OPS-future-ideas-2026-05-17.md`에 별도 보관한다.

## 진행 상태
- 2026-05-17 KST 실행 전 구체 계획 재정리 완료.
- 2026-05-17 KST Phase 1~3 구현 완료:
  - 일정상세 날짜 밑 차량번호 badge를 날짜보다 크게 보이도록 보정했다.
  - 예약상세 기능 버튼을 `상태 처리 / 관리 / 연락` 영역으로 분리했다.
  - 배차완료/반납완료 확인 다이얼로그 문구를 실제 변경 내용과 IMS 동시 처리 여부 기준으로 정리했다.
  - 좌상단 `빵빵카` 클릭 시 admin만 관리자 홈(`/admin`)으로 진입하도록 뼈대를 추가했다.
  - 관리자 홈에는 직원관리/차량관리/작업로그/출근확인/앱푸시 placeholder 카드를 추가했다.
- Phase 4 직원관리 MVP는 추가 확인 필요:
  - 현재 `rc00_ops_staff_accounts` RLS는 본인 row 조회만 허용한다.
  - 직원 목록/추가/권한 변경은 admin 조회/수정 정책 또는 서버/Edge Function 경로가 필요하다.
  - Supabase Auth 계정 생성은 클라이언트 직접 처리보다 서버/Edge Function 방식이 안전하다.
