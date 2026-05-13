# rentcar00_OPS Main

## 1. 문서 역할
이 문서는 `rentcar00_OPS`의 메인 기준 문서다.
제품 정의, 현재 잠긴 운영 기준, 현재 구현 기준은 여기서 관리한다.
현재 진행 중인 단일 작업 메모는 `rentcar00_OPS-current.md` 에만 둔다.

## 2. 제품 현재 정의
- 목적: 기존 AppSheet 현황 확인 흐름을 유지하면서, Flutter 앱에서 예약/현황 업무를 실제 처리하는 Android 우선 운영 앱을 만든다.
- 플랫폼: Flutter Android 우선
- 백엔드: Supabase
- 원천 데이터: Google Sheets `예약`, `일정`, `시트1` 기반 운영 데이터
- 역할 분리:
  - AppSheet: 기존 운영자가 보던 레퍼런스 현황판
  - rentcar00_OPS: 예약 상세 처리, 현황판 상세 확인, 예약 생성/상태 작업의 실행 화면

## 3. 현재 잠긴 운영 기준
### 데이터 계층
- raw/ops 계층은 분리한다.
- raw는 원본 보존, ops는 앱 표시/업무 처리 기준으로 사용한다.
- 핵심 테이블 접두는 `rc00_ops_`를 유지한다.

### 예약 생성
- 차량 상세에서 예약 생성 가능하다.
- 생성 시 아래를 함께 저장한다.
  - reservation row 1건
  - reservation state 1건
  - schedule row 2건(배차/반납)
- 예약 생성 기본 상태는 `예약중`이다.
- 예약 원장은 앱 내부 canonical schema 기준으로 저장한다.
- 현재 저장 필드에는 아래가 포함된다.
  - 차량번호
  - 차량명
  - 고객명
  - 고객번호
  - 생년월일
  - 소개처
  - 가격
  - 배차일시
  - 반납일시
  - 배차지
  - 반납지
  - 비고
- 형식 잠금 기준:
  - 생년월일: `YYYY-MM-DD`
  - 고객번호: 숫자만
  - 가격: 숫자만
  - 배차/반납 시각: 내부 `DateTime` 기준
  - 주소 기준: 배차지 우선
- AI파서를 사용한 예약 생성에서는 원장 메모에 원문 전체를 저장하는 것을 기본 원칙으로 둔다.

### IMS 예약추가
- IMS 예약추가는 파싱 기능의 부속이 아니라 원장 기반 독립 기능으로 본다.
- 예약생성에서 IMS 체크를 켜는 경우에도 순서는 `내부 예약 생성 → IMS 전송` 이다.
- 향후 예약 상세/원장에서 `IMS 예약추가` / `IMS 재시도` 를 독립 실행 가능해야 한다.
- IMS payload 는 원장에서 결정적으로 생성한다.
- 현재 잠긴 기준:
  - `address = pickupLocation`
  - `useDelivery = true`
  - IMS 메모는 원장 메모 전체가 아니라 별도 builder 로 축약 생성

### 예약 상세
- 예약 상세는 조회 중심에서 시작했지만, 현재는 `IMS 예약추가` 1건은 실행 가능하다.
- 상세에서 표시하는 핵심 정보:
  - 예약번호
  - 고객명
  - 고객번호
  - 생년월일
  - 소개처
  - 가격
  - 차량번호
  - 탭/상태
  - 배차/반납 시각
  - 위치
  - 체크 상태
  - 메모

### 현황판
- 현황판은 기존 AppSheet 구조 복제를 우선한다.
- 현재 기준 탭은 아래 5개다.
  - 대기
  - 보험
  - 일반
  - 장기
  - 일정
- 차량 상세에서 예약 상세로 진입 가능해야 한다.
- 현황판의 목적은 재설계보다 운영 익숙함 유지다.
- 차량 상세는 상태 기준 액션 분기를 지원한다.
- 일정 상세는 `일정완료` / `일정삭제` 액션을 지원한다.
- 일정 탭은 FAB 기반 일정 단독 생성 흐름을 지원한다.
- 현황판/일정 UI 는 화이트 배경 + 블루/스카이블루 포인트 기준으로 톤 정리를 반영했다.

## 4. 현재 구현 상태
### 완료
- Flutter 앱 기본 뼈대 구성 완료
- Supabase read 연결 완료
- raw import / normalization 도구 반영 완료
- 현황판 리스트/상세 기본 연결 완료
- 차량 상세 → 예약 생성 연결 완료
- 예약 생성 추가 필드 반영 완료
  - 생년월일
  - 소개처
  - 가격
- 예약 상세에 위 3개 필드 표시 반영 완료
- 원격 migration 반영 완료
- AI파서 버튼/입력 dialog/자동채움 반영 완료
- 예약생성 `IMS` 체크박스 및 IMS 전송 반영 완료
- 예약 상세 `IMS 예약추가` 버튼 반영 완료
- IMS dry-run / 실저장 / 즉시 삭제 검증 완료
- 차량 상세 상태별 액션 분기 반영 완료
- 차량 상세 `반납 완료` 반영 완료
- 일정 상세 `일정완료` / `일정삭제` 반영 완료
- 일정 탭 FAB 기반 일정 단독 생성 반영 완료
- 현황판/일정 모달·입력·FAB·액션칩 UI 톤 정리 반영 완료

### 현재 확인된 운영 이슈
- Android release APK는 현재 설치 검증상 파일 자체는 정상이다.
- 다만 release 빌드가 아직 `debug signing` 기준이다.
- 업로드 파일명은 arm64 기준으로 운영하지만 실제 산출물은 universal APK다.
- 최신 배포본은 `b14 / 11c4627` 기준으로 업로드 완료 상태다.
- 현황판/일정 액션 기능은 구현됐고 UI 톤 정리도 반영됐지만 실데이터 클릭 동선 재확인은 더 필요하다.
- 다음 확인 기준은 `b15` 패키지 실기기 체크다.

## 5. 기준 경로
### 앱 코드
- `lib/features/status_board/...`
- `lib/features/reservations/...`
- `lib/data/repositories/supabase_ops_repository.dart`

### DB / migration
- `supabase/migrations/`

### 운영 도구
- `tool/import_google_sheets_raw.dart`
- `tool/normalize_raw_to_projection.dart`

## 6. 기준 문서
- 메인 기준 문서: `docs/rentcar00_OPS-main.md`
- 현재 진행 문서: `docs/rentcar00_OPS-current.md`
- 현재 UI 준비는 `docs/rentcar00_OPS-current.md` 기준으로 본다.

## 7. 과거 문서 위치
- 기존 루트 기준 문서 스냅샷: `docs/archive/root-current-2026-05-12/`
- 그 이전 탐색/설계 기록: `docs/archive/`
- 이전 current 스냅샷: `docs/archive/rentcar00_OPS-current-ai-parser-snapshot-2026-05-13.md`
- IMS 완료 current 스냅샷: `docs/archive/rentcar00_OPS-current-ims-complete-2026-05-14.md`
- IMS 완료 roadmap 스냅샷: `docs/archive/rentcar00_OPS-ims-roadmap-complete-2026-05-14.md`
- 현황판 액션 완료 current 스냅샷: `docs/archive/rentcar00_OPS-current-status-board-actions-complete-2026-05-14.md`
- 현황판 액션 완료 roadmap 스냅샷: `docs/archive/rentcar00_OPS-status-board-actions-roadmap-complete-2026-05-14.md`
