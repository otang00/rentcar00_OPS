# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 진행 중인 작업, 지금까지 끝난 것, 앞으로 해야 할 것을 짧게 고정한다.
완료된 기능의 상세 내역은 `docs/completed/rentcar00_OPS-completed.md`에 누적한다.

---

## 현재 active 작업
**b48 KST 시간 처리 통일 APK 빌드/GDrive 업로드 완료 / 실기기 확인 대기**

## 현재 기준점
- repository: `rentcar00_OPS`
- branch: `main`
- 현재 HEAD: `4ae2374 Release b47 UI and icon updates`
- 앱 버전/build: `1.0.0+48`
- 최신 APK 파일명 기준: `rentcar00_ops-app-release-arm64-b48-4ae2374.apk`
- 작업트리는 b47 변경 커밋까지 완료된 상태다.
- GDrive `rentcar00_OPS/apk/`에는 최신 APK 1개만 유지하는 운영 기준을 사용한다.
- macOS platform 폴더는 삭제 완료했고 다시 생성하지 않는다.

---

## 지금까지 한 것

### 1. IMS 예약 생성 후 schedule id 확보 개선
- IMS 생성 API가 `{ success: true }`만 반환하는 것을 확인했다.
- 생성 후 빠른 API lookup / page scan fallback으로 schedule id와 detail id를 확보하는 흐름을 구현했다.
- 확보한 id를 OPS 예약의 IMS linked 상태로 저장하는 기준을 잡았다.
- 검증: 실제 4014 테스트 생성/삭제, `node --check`, `npm --prefix reservation_ai_parser run check`, `flutter analyze`, `flutter test` 통과 기록.

### 2. 직원관리 MVP 1차 구현
- 관리자 기준은 `rentcar00` admin, 나머지는 staff 기준으로 고정했다.
- 관리자 메뉴에서 직원관리 화면으로 진입하는 흐름을 만들었다.
- 직원 목록/권한/활성상태/마지막 활동/위치정보/관리자 표시용 비밀번호 확인 UI를 구현했다.
- `rc00_ops_staff_accounts`, `rc00_ops_staff_passwords` 기준의 DB migration을 작성하고 운영 DB 반영까지 완료한 기록이 있다.
- staff 계정 2개는 Supabase Auth 실제 비밀번호와 관리자 표시용 비밀번호를 동기화 완료한 상태로 기록돼 있다.

### 3. IMS 보험배차 가져오기 UI/API 구현
- 차량상세 `배차 > 보험`에서 `IMS 보험배차 가져오기` 창을 띄우는 흐름을 구현했다.
- 보험계약서 대여일 조회 기준은 `GET /v2/rencar-claims` + `periodOption=using_car` + 소문자 `startdate/enddate`로 정리했다.
- `직접입력` 버튼은 기존 수동 입력폼 흐름으로 보낸다.

### 4. b43 IMS 가져오기 UI/API 배포/정리
- 앱 build number를 b43 기준으로 올렸다.
- 일반예약/보험배차 IMS 가져오기를 차량번호 4자리 검색 → OPS 차량 선택 → 전체 차량번호 exact 조회 구조로 바꿨다.
- 이름 검색은 제거했고 날짜 입력은 유지했다.
- 일반예약 fallback 전체 scan은 제거했다.
- 결과 리스트는 카드형 선택 UI로 정리했다.
- b43 APK 기준 파일명을 문서에 고정했다.
- 로컬 build 및 GDrive는 최신 APK만 유지하는 기준으로 정리한 상태다.


### 6. 관리자 차량관리 1차 구현
- 관리자 홈의 차량관리 카드를 실제 화면으로 연결했다.
- 차량 목록은 차량번호/차종/상태/주차위치 검색과 카드형 표시를 지원한다.
- 차량 추가는 차량번호 필수, 상태 기본 `대기중`, 세차값 기본 `FALSE` 기준이다.
- 차량 수정은 기본 영역과 `고급 컬럼 보기`로 나눴다.
- 고급 영역에서 운행/시스템 컬럼과 `payload_json`을 수정할 수 있다.
- 차량 삭제는 수정 화면 하단 위험 영역에서 확인 다이얼로그 후 실행한다.

### 5. 홈페이지 예약 이벤트 수신/자동 원장 등록 구현
- endpoint: `POST /api/integrations/rentcar00/reservation-events`
- `reservation.created` 이벤트 수신 코드를 `reservation_ai_parser`에 구현했다.
- HMAC 서명, timestamp, eventId, payload schema 검증을 넣었다.
- 같은 eventId는 중복 성공으로 처리해 홈페이지 재시도에 안전하게 만들었다.
- 정상 payload는 `rc00_ops_reservation_events`에 저장한 뒤 원장/상태/배차·반납 일정까지 자동 생성한다.
- 앱은 `homepage_review=pending` 기준으로 `홈페이지 확인` 배지와 상단 `홈페이지 N` 표시를 보여준다.
- 예약 상세에는 `홈페이지확인` 버튼을 추가해 확인 완료 처리한다.
- 검증 기록:
  - signed POST → 원장/상태/배차·반납 일정 생성 확인
  - 테스트 row 정리 후 `cleanup_remaining=0`
  - `node --check`, `npm --prefix reservation_ai_parser run check`, `flutter analyze`, `flutter test` 통과
  - b45 APK 빌드 및 GDrive 업로드 완료

### 6. 차량상세 상태수정/즉시배차 검증 완화
- 차량상세의 상태수정은 원장 작성이 아니라 차량 인스턴스 스냅샷 수정 기준으로 정리했다.
- 일반/장기 즉시배차는 먼저 DB 업데이트하지 않고 상태수정 다이얼로그 저장 시 한 번만 반영한다.
- 상태수정 다이얼로그에서 고객명/대여일시/반납일시 필수 검증을 제거했다.
- 빈 날짜는 `null` 저장, 파싱 가능한 날짜만 정규화해 저장한다.
- 검증 기록: `flutter analyze`, `flutter test`, `git diff --check` 통과
- b46 APK 빌드 및 GDrive 업로드 완료

### 7. 예약생성 UI / IMS 계정 이슈 확인
- 예약생성 다이얼로그 하단 `IMS연동생성 / 취소 / 생성`이 AlertDialog actions 영역에서 줄바꿈되는 문제가 확인됐다.
- `IMS연동생성` 체크박스를 content 내부로 옮기고, actions에는 `취소 / 생성`만 남겼다.
- 비슷한 `AlertDialog.actions` 내 체크박스/복합 Row 패턴을 검색했고, 동일한 직접 위험 패턴은 추가로 발견되지 않았다.
- 검증 기록: `dart format`, `flutter analyze`, `flutter test` 통과
- 주의: 이 UI 수정은 b46 GDrive 업로드 이후 반영됐으므로, 현재 GDrive b46 APK에는 아직 포함되지 않았다.
- IMS 가져오기 계정 오류는 `reservation_ai_parser/.env`에 `IMS_ID`, `IMS_PW`/`IMS_PASSWORD`가 없는 상태가 직접 원인으로 확인됐다.

### 8. 앱 아이콘 / 차량상세 연관일정 UI 개선
- 앱 런처 아이콘은 기존 글씨체/디자인을 유지하되 `(주)`를 제거하고 `빵빵카`만 크게 보이게 정리했다.
- Android `mipmap-*` 런처 아이콘을 `빵빵카` 단독 원본 기준으로 재생성했다.
- AppBar 로고 변경은 오해로 판단해 되돌렸다.
- 차량상세 `연관일정`은 가로 짝짓기 없이 시간순 세로 카드 리스트로 정리했다.
- 일정 카드에는 `배차`/`반납` 색상과 `↗`/`↙` 방향 아이콘을 적용했다.
- 첫 번째 일정은 가장 가까운 일정 기준으로 강조한다.
- b47 APK 빌드 및 GDrive 업로드 완료: `rentcar00_ops-app-release-arm64-b47-2e26228.apk`

### 9. 앱 시간 처리 KST 통일
- 예약/일정/현황판 시간 구조는 유지하고, 시간 parse/store/display 기준만 KST로 통일했다.
- 공통 helper `lib/shared/utils/ops_kst_datetime.dart`를 추가했다.
- 앱 입력/표시는 KST 벽시계 시간으로 고정하고, DB timestamptz 저장 시에만 UTC timestamp로 변환한다.
- 직접 `toUtc()`, `toLocal()`, `DateTime.tryParse()`를 쓰던 예약판/현황판/상세/관리/IMS 시간 표시 경로를 공통 KST helper 기준으로 정리했다.
- 검증 기록: `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --release --target-platform android-arm64` 통과.
- b48 APK 빌드 및 GDrive 업로드 완료: `rentcar00_ops-app-release-arm64-b48-4ae2374.apk`

---

## 앞으로 해야 할 것

### A. 실기기 확인
- b48 APK 설치 후 예약판 배차대기 시간이 한국시간 기준으로 표시되는지 확인.
- b43 APK 설치 후 앱 실행 확인.
- 관리자 `rentcar00` 로그인 확인.
- 관리자 > 직원관리 목록/수정/비밀번호 눈 아이콘 확인.
- staff 계정에서 관리자 화면 접근 차단 확인.
- 일반예약 가져오기에서 4자리 차량검색/선택/카드형 결과 선택 확인.
- 차량상세 `배차 > 보험`에서 4자리 차량검색/선택/카드형 보험배차 결과 선택 확인.

### B. 홈페이지 예약 이벤트 수신부 운영 반영
운영 반영 전 별도 승인 필요.

1. Supabase migration 실제 적용
   - `supabase/migrations/20260520015500_add_reservation_event_inbox.sql`
2. 운영 secret 안전 주입
   - `OPS_APP_RESERVATION_EVENT_SECRET`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. `reservation_ai_parser` restart
4. 홈페이지 송신부와 통합 검증
   - 정상 예약 생성 이벤트 수신
   - 중복 eventId 처리
   - 잘못된 signature 거부
   - DB 저장 row 확인

### C. 차량관리 1차 확인
- b44 APK 설치 후 관리자 `rentcar00`으로 차량관리 화면 접근 확인.
- 차량 추가/수정/고급 컬럼 펼치기/삭제 흐름 실기기 확인.
- 삭제는 과거 예약/일정 연결 리스크가 있으므로 실제 운영 차량 삭제 전 재확인.

### D. b47 배포 후 확인
- b47 APK 설치 후 예약생성 다이얼로그 하단 버튼/키보드 가시성을 확인한다.
- 앱 런처 아이콘이 홈 화면/앱 서랍에서 `빵빵카`로 잘 읽히는지 확인한다.
- 차량상세 `연관일정` 세로 카드의 시간순/색상/높이를 실기기에서 확인한다.

---

## 현재 리스크 / 주의점
1. 운영 secret과 runtime 설정은 승인 없이 수정하지 않는다.
2. 홈페이지 이벤트 수신부는 코드 구현 상태이며, 운영 반영은 migration/secret/restart/통합 검증이 끝나야 완료다.
3. 차량 삭제는 과거 예약/일정 표시와 연결이 끊길 수 있다.
4. 현재 작업트리에 차량관리 구현 변경이 uncommitted 상태로 남아 있으므로 검증 후 커밋이 필요하다.
5. b44 실기기 확인 전까지는 배포 완료가 아니라 배포물 준비/업로드 완료 상태로 본다.
