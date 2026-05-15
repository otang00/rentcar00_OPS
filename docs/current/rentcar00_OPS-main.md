# rentcar00_OPS Main

## 문서 역할
이 문서는 `rentcar00_OPS`의 **메인 기준 문서**다.
프로젝트 전체 구조, 정책, spec, 운영 기준, 진행 누적 맥락을 관리한다.
현재 실행 작업 1건은 `docs/current/rentcar00_OPS-current.md` 에만 둔다.
완료 기능의 운영 상세는 `docs/completed/rentcar00_OPS-completed.md` 에 둔다.

## 제품 목적
- 기존 AppSheet 현황 확인 흐름을 유지하면서, Flutter 앱에서 예약/현황 업무를 실제 처리하는 Android 우선 운영 앱을 만든다.

## 런타임 기준
- 앱 시작 시 `.env` 를 읽고 Supabase 를 초기화한다.
- 초기화 진입 파일: `lib/app/bootstrap/app_bootstrap.dart`
- 현재 구조는 별도 앱 서버 bootstrap API 호출형이 아니라, Flutter 앱이 직접 Supabase 를 읽는 구조다.

## 플랫폼 / 백엔드
- 플랫폼: Flutter Android 우선
- 백엔드: Supabase
- 원천 Google Sheets 문서:
  - spreadsheet title: `차량현황`
  - spreadsheet id: `1sEHaOI-zrLNzlGC8IdogQ3CidKuL4R_vFGGvFnGyGWk`
  - 기준 시트: `시트1`
  - 보조 시트: `예약`, `일정`
- 원천 데이터/운영 테이블:
  - `rc00_ops_cars`
  - `rc00_ops_reservations`
  - `rc00_ops_reservation_states`
  - `rc00_ops_schedules`
  - `rc00_ops_import_runs`

## 배포 / 접근 통제 기준
- 이 앱은 외부 공개 서비스가 아니라 **직원 4명 내외가 쓰는 내부 운영앱**으로 본다.
- APK가 외부로 복사되더라도, **허용된 계정 없이는 앱 본문에 들어오지 못하게** 하는 것을 1차 목표로 둔다.
- 1차 접근 통제는 **직원별 아이디/비밀번호 로그인**으로 잠근다.
- 기기 고정, 전화번호 OTP, 하드웨어 식별값 의존 방식은 1차 구현으로 채택하지 않는다.
- 필요 시 후속 phase 에서만 `새 기기 승인`, `동시 로그인 제한`, `직원별 권한 분리`를 추가 검토한다.

### 인증 방식 잠금
- 인증 소스는 **Supabase Auth email/password** 를 우선 기준으로 둔다.
- 앱 표면에서는 `아이디 + 비밀번호` 로 보이게 하되, 내부적으로는 **아이디를 가상 email alias 로 변환**해 Supabase Auth 에 넣는다.
- 로그인 ID 는 내부 직원용 고정 아이디를 쓴다.
- 비밀번호는 직원별로 분리한다.
- 계정은 사장님 또는 관리자만 발급/비활성화할 수 있어야 한다.
- 인증되지 않은 상태에서는 현황판/예약/상세 어떤 실데이터도 읽지 않는다.
- 자동 로그인 유지가 필요하므로, 앱 재실행 시 기존 세션이 유효하면 로그인 화면을 건너뛴다.

### 계정 식별 규칙
- 직원이 입력하는 값은 `login_id` 다.
- `login_id` 는 영문 소문자/숫자 기준의 짧은 내부 아이디로 관리한다.
- 앱에서는 `login_id` 를 정규화한 뒤 내부적으로 `{login_id}@ops.00rentcar.local` 형식의 alias email 로 변환해 로그인한다.
- 사용자에게는 email 개념을 노출하지 않는다.
- 공개 회원가입은 막고, alias email 생성/수정은 관리자 작업으로만 처리한다.

### 권장 계정 메타 테이블
인증 자체는 Supabase Auth 로 처리하고, 운영 메타는 별도 테이블로 둔다.

권장 테이블: `rc00_ops_staff_accounts`
- `id uuid primary key`
- `auth_user_id uuid unique`
- `login_id text unique`
- `display_name text`
- `role text default 'staff'`
- `is_active boolean default true`
- `created_at timestamptz`
- `updated_at timestamptz`
- `last_login_at timestamptz null`

역할:
- 어떤 직원 계정인지 앱/운영 화면에서 식별
- 비활성화 여부 별도 관리
- 나중에 권한 분리나 기기 승인 확장 시 기준 테이블로 재사용

### 비활성화 규칙
- 1차 구현에서는 **Auth 로그인 성공 + staff meta 활성 상태** 둘 다 만족해야 앱 본문 진입을 허용한다.
- Auth user 가 살아 있어도 `rc00_ops_staff_accounts.is_active = false` 면 앱은 접근을 막는다.
- 즉 계정 회수는 Auth 삭제보다 `is_active` 차단을 우선 기준으로 둔다.

## 핵심 화면
- 현황판
- 일정 상세
- 예약 상세
- 예약 생성/상태 작업
- 일정 수정

## 현황판 기준
### 탭 의미
코드 기준 파일:
- `lib/features/status_board/shared/domain/status_board_tab.dart`
- `lib/data/repositories/supabase_ops_repository.dart`

탭은 아래처럼 고정한다.
- `idle`: 차량 `status` 가 `대기` 또는 `대기중`
- `insurance`: 차량 `status` 가 `보험`
- `general`: 차량 `status` 가 `일반`
- `longTerm`: 차량 `status` 가 `장기`
- `schedule`: `rc00_ops_schedules` 에서 완료되지 않은 일정 행

### 일정탭 의미
- 일정탭은 차량 상태 탭이 아니라 **미완료 일정 feed** 다.
- `schedule_type_raw` 가 `배차` / `반납` / `기타` 인 행을 읽는다.
- `schedule_done_raw` 가 truthy 면 일정탭에서 제외한다.
- 일정 단독 생성은 허용하며, 기타 업무 체크용 미연결 일정이 존재할 수 있다.
- `기타` 일정은 일정탭에서 별도 상태로 유지하며, 초록 `!` 표시로 구분한다.
- 일정 record 는 `reservation_id` 기준으로 예약/차량 정보와 연결해 상세에 보여준다.
- schedule row 의 예약번호/위치/상세가 비어 있으면 linked reservation 값으로 fallback 한다.
- `reservation_id` 가 비어 있는 일정은 자동 연결 대상이 아니라 의도된 독립 일정일 수 있으므로 그대로 유지한다.

### 차량 상세 액션 기준
코드 기준 파일:
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/data/repositories/supabase_ops_repository.dart`

### 대기 현황판 표시 기준
코드 기준 파일:
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`

- 대기 현황판은 차량번호 / 차종 / 세차 / 주차지 순으로 보여준다.
- 차종은 좁게 두고 일부 잘림을 허용한다.
- 세차 컬럼은 왼쪽 정렬 쪽으로 붙인다.
- 주차지는 상대적으로 더 넓게 사용한다.
- 대기 차량의 주차지 수정은 enum 선택형을 기본으로 쓴다.
- 기본 주차지 목록:
  - `수푸레B1`
  - `수푸레B2`
  - `주차타워(반포)`
  - `반포3주민센터`
  - `수푸레1층`
- 목록에 없는 값은 `+ 직접추가`로 저장 가능하다.

- 대기 차량:
  - 예약 생성
  - 보험/일반/장기 즉시 전환
  - 외부세차 / 실내세차 토글
  - 주차지 수정
- 운행 차량:
  - 반납 완료
  - 전화 / 문자
- 반납 완료 실행 시:
  - `status = 대기중`
  - `status_action = 반납 완료`
  - `customer_name = ''`
  - `customer_phone = ''`
  - `start_at = ''`
  - `pickup_location = ''`
  - `end_at` 는 유지
  - `car_wash = FALSE`
  - `interior_wash = FALSE`
  - `parking_location = 수푸레`

### 일정 상세 액션 기준
- 완료
- 수정
- 전화 / 문자
- 삭제
- 수정 가능 항목:
  - 일정유형
  - 일정시각
  - 차량번호
  - 차종
  - 위치
  - 상세정보
- 배차 일정 완료 시 연결 예약의 고객정보를 차량 인스턴트값으로 반영하고 차량 상태를 `일반`으로 바꾼다.

## 예약 원장 기준
### 생성 구조
코드 기준 파일:
- `lib/data/repositories/supabase_ops_repository.dart`

차량 상세에서 예약 생성 시 아래를 함께 쓴다.
1. `rc00_ops_reservations`
2. `rc00_ops_reservation_states`
3. `rc00_ops_schedules` 배차 행
4. `rc00_ops_schedules` 반납 행

### 저장 형식 잠금
- 생년월일: `YYYY-MM-DD`
- 고객번호: 숫자만
- 가격: 숫자만
- 배차/반납 시각: 내부 `DateTime` → ISO string 저장
- 배차지/반납지: trim string
- AI파서 사용 시 원문 전체를 원장 메모에 보존

### 예약 탭 기준
코드 기준 파일:
- `lib/features/reservations/shared/domain/reservation_tab.dart`
- `lib/data/repositories/supabase_ops_repository.dart`

`startAt / endAt` 날짜 기준으로 tab key 를 계산한다.
- `completed`: end day < today
- `returnDue`: end day == today
- `pickupToday`: start day == today
- `inUse`: start day < today and end day > today
- `pending`: 그 외

## 새로고침 / 반영 기준
현재 구조는 별도 `app-refresh` API 가 아니라 Riverpod invalidate 기반이다.

### invalidate 기준
코드 기준 파일:
- `lib/features/status_board/detail/presentation/status_board_detail_page.dart`
- `lib/features/status_board/list/presentation/status_board_tab_page.dart`

- 차량 상세 액션 후:
  - `allStatusBoardRecordsProvider`
  - `allReservationsProvider`
- 일정 완료/삭제 후:
  - `allStatusBoardRecordsProvider`
  - `allReservationsProvider`
- 일정탭 일정 생성 후:
  - `allStatusBoardRecordsProvider`

즉 현재 refresh 기준은 **현황판/예약 provider 재조회**다.

## AI 파서 / IMS 기준
### AI 파서
코드 기준 파일:
- `lib/features/status_board/detail/data/reservation_ai_parser_client.dart`
- `reservation_ai_parser/README.md`

- 외부 진입점: `https://parser.00rentcar.com`
- health: `GET /health`
- 파싱: `POST /parse-reservation`
- timeout:
  - health 10초
  - parse 30초
- baseUrl 이 비어 있으면 앱에서 즉시 에러 처리한다.

### IMS 예약추가
코드 기준 파일:
- `lib/features/reservations/detail/data/ims_reservation_payload.dart`
- `lib/features/reservations/detail/data/ims_reservation_client.dart`

- IMS는 AI파서 부속이 아니라 원장 기반 독립 기능
- 전송 endpoint: `POST /ims/create-reservation`
- timeout: 40초
- `useDelivery = true` 고정
- memo 최대 길이: `120`
- 필수 검증:
  - rentalAt
  - returnAt
  - carNumber
  - totalFee
  - customerName
  - customerPhone
  - address
  - `customerBirthDate` 형식
  - 반납일시 > 배차일시

## 장애 해석 원칙
### AI 파서
- public 502 + local 43110 미응답이면 parser origin down 으로 본다.
- tunnel up 만으로 서비스 정상으로 보지 않는다.
- tunnel과 parser 둘 다 살아 있어야 정상이다.

### 앱 데이터
- 현황판/예약 화면 불일치가 나면 provider invalidate 후 재조회 범위를 먼저 본다.
- 일정 생성은 현황판만 invalidate 하므로, 예약 원장 반영 기대와 혼동하지 않는다.

## 로그인 / 세션 기준
### 1차 범위
- 앱 시작 시 세션을 먼저 확인한다.
- 세션이 없으면 로그인 화면으로 보낸다.
- 세션이 있어도 staff meta 조회 결과 `is_active != true` 면 본문 진입을 막고 강제 로그아웃 처리한다.
- 로그인 성공 후에만 기존 앱 shell / 현황판 / 예약 화면을 연다.
- 로그아웃 기능을 제공하고, 로그아웃 시 즉시 로그인 화면으로 복귀한다.

### 로그인 화면 기준
- 입력값은 `아이디`, `비밀번호` 2개만 둔다.
- `회원가입`, `비밀번호 찾기`, `전화번호 인증` 버튼은 두지 않는다.
- 에러 문구는 내부앱 기준으로 단순하게 유지한다.
  - `아이디 또는 비밀번호가 올바르지 않습니다.`
  - `승인되지 않은 계정입니다.`
  - `비활성화된 계정입니다.`
- 로그인 성공 직후 staff meta 를 조회해 표시명/활성 상태를 확인한다.

### 세션/라우팅 원칙
- 앱 루트 라우터에서 auth 상태를 먼저 본다.
- 비로그인 상태에서는 `/login` 외 업무 라우트 진입을 모두 막는다.
- 로그인 상태에서는 `/login` 으로 되돌아가지 않고 홈으로 보낸다.
- 데이터 provider 는 인증 상태가 확인된 뒤에만 구독되게 한다.

### 1차 제외 범위
- 회원가입 공개 노출
- 비밀번호 찾기 자동화
- 전화번호 OTP 인증
- 기기별 화이트리스트 강제
- 역할별 세밀 권한 분기

### 운영 원칙
- 내부앱이라도 계정 단위 접근기록을 남길 수 있는 구조를 우선한다.
- 공용 비밀번호 1개를 공유하는 방식은 채택하지 않는다.
- 로그인 추가 후에도 기존 업무 데이터 구조는 유지하고, 인증 레이어만 앱 진입 앞단에 둔다.

## 문서 구조 기준
- `docs/current/rentcar00_OPS-current.md`
  - 현재 실제 실행 작업 1건만 기록
- `docs/current/rentcar00_OPS-main.md`
  - 전체 구조/정책/spec/운영 기준
- `docs/completed/rentcar00_OPS-completed.md`
  - 완료된 기능의 운영/검증/장애 대응 요약
- `docs/past/`
  - 과거 설계/아이디어/스냅샷
