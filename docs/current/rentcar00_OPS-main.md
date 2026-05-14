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
- 원천 데이터/운영 테이블:
  - `rc00_ops_cars`
  - `rc00_ops_reservations`
  - `rc00_ops_reservation_states`
  - `rc00_ops_schedules`
  - `rc00_ops_import_runs`

## 핵심 화면
- 현황판
- 일정 상세
- 예약 상세
- 예약 생성/상태 작업

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
- `schedule_type_raw` 가 `배차` 또는 `반납` 인 행만 읽는다.
- `schedule_done_raw` 가 truthy 면 일정탭에서 제외한다.
- 일정 단독 생성은 허용하며, 기타 업무 체크용 미연결 일정이 존재할 수 있다.
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
- 전화 / 문자
- 삭제
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

## 문서 구조 기준
- `docs/current/rentcar00_OPS-current.md`
  - 현재 실제 실행 작업 1건만 기록
- `docs/current/rentcar00_OPS-main.md`
  - 전체 구조/정책/spec/운영 기준
- `docs/completed/rentcar00_OPS-completed.md`
  - 완료된 기능의 운영/검증/장애 대응 요약
- `docs/past/`
  - 과거 설계/아이디어/스냅샷
