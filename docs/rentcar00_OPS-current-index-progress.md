# rentcar00_OPS Current Index + Progress

## 0. 이 문서 역할
이 문서는 `rentcar00_OPS`의 현재 허브 문서다.
다음에 다시 볼 때는 이 문서부터 본다.

원칙:
- 기준 문서는 적게 유지한다.
- 문서가 겹치면 새로 만들지 말고 메인 문서로 흡수한다.
- 중요 참고 위치는 이 문서에 먼저 기록한다.

## 1. 현재 기준 문서
### 공통
1. `projects/rentcar00_OPS/docs/rentcar00_OPS-current-index-progress.md`
2. `projects/rentcar00_OPS/docs/rentcar00_OPS-spec.md`
3. `projects/rentcar00_OPS/docs/rentcar00_OPS-naming-mapping-rules-v1.md`

### 예약 레이어
4. `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-design-v1.md`
5. `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-data-design-v1.md`

### 현황판 레이어
6. `projects/rentcar00_OPS/docs/rentcar00_OPS-status-board-design-v1.md`

### 진행 체크
- `tasks/rentcar00_OPS-master-checklist.md`
- `tasks/rentcar00_OPS-design-checklist.md`

## 2. 중요 참고 위치
### Google Sheets
- spreadsheet id: `1sEHaOI-zrLNzlGC8IdogQ3CidKuL4R_vFGGvFnGyGWk`
- spreadsheet title: `차량현황`
- 예약 레이어 원본 시트: `예약`, `일정`
- 현황판 레이어 원본 시트: `시트1`

### Google service account JSON
- `/Users/otang_server/.openclaw/media/inbound/test001-39500280-8a165c8d3c50---fc41748b-2ac5-40fd-962e-2330fc79bd25.json`

주의:
- secret 값은 문서에 복사하지 않는다.
- 경로와 용도만 기록한다.

### env / Supabase
- 앱 공개 env: `projects/rentcar00_OPS/.env`
- 로컬 참고 env: `projects/rentcar00_OPS/.env.local`
- 예시 env: `projects/rentcar00_OPS/.env.example`
- Supabase config: `projects/rentcar00_OPS/supabase/config.toml`
- Supabase pooler URL fallback: `projects/rentcar00_OPS/supabase/.temp/pooler-url`
- Supabase project ref: `projects/rentcar00_OPS/supabase/.temp/project-ref`
- migrations:
  - `projects/rentcar00_OPS/supabase/migrations/20260508154107_initial_rc00_ops_schema.sql`
  - `projects/rentcar00_OPS/supabase/migrations/20260509002000_simplify_reservation_states.sql`

## 3. 지금 읽는 순서
### 예약 레이어 작업일 때
1. 이 문서
2. `rentcar00_OPS-spec.md`
3. `rentcar00_OPS-reservation-layer-design-v1.md`
4. `rentcar00_OPS-reservation-layer-data-design-v1.md`
5. 필요 시 checklist

### 현황판 레이어 작업일 때
1. 이 문서
2. `rentcar00_OPS-spec.md`
3. `rentcar00_OPS-status-board-design-v1.md`
4. 필요 시 checklist

## 4. 현재 고정 사항
### 공통
- 앱 최상단은 `예약 / 현황판` 2레이어 스위치
- AppSheet API 직접 호출 안 함
- Google Sheets write 는 최종 phase 전까지 금지
- 초기 단계는 read-only import + 내부 상태 저장 + outbox dry-run까지만 허용

### 예약 레이어
- 원본 source: Google Sheets `예약` + `일정`
- 메인 탭 5개 고정
  - 예약중
  - 오늘배차
  - 배차중
  - 반납일
  - 완료
- 메인 연결키: `reservation_id`
- 보조키: `reservation_number`
- 탭 계산 source of truth: `status_raw + start_at + end_at` 를 반영한 `tab_key`

### 현황판 레이어
- 1차 source: Google Sheets `시트1`
- 기존 AppSheet 하단 5탭 복제를 우선
- 탭 이름/순서 고정
  - 대기
  - 보험
  - 일반
  - 장기
  - 일정
- `대기 / 보험 / 일반 / 장기`는 우선 `시트1.상태` 원문값 기준 분류
- `일정`은 `일정` 시트 active row 기준 별도 피드
- 재설계보다 기존 정보 위치/밀도 보존 우선

## 5. 현재 상태
- Flutter 앱 골격 구현 완료
- Supabase client 초기화 완료
- 원격 DB migration 적용 완료
- Google Sheets read-only 접근 확인 완료
- raw import / 1차 정규화 실행 완료
- 문서 구조는 슬림화 기준으로 재정리 완료
- 현황판 상단은 `빵빵카 + 예약/현황판 스위치 + sync` 1줄 구조로 축소 완료
- 현황판 탭 상단 설명 문구 제거 완료
- 대기 탭은 한줄형 `차량번호 + 차종 + 세차/실내 + 주차지` 구조까지 1차 반영 완료
- 일정 탭은 차량 상세가 아니라 일정 상세로 분기되도록 1차 반영 완료
- 차량 상세는 차량등록일 / 차량검사일 / 차령만료일 / 차량번호 세부 필드까지 1차 확장 완료
- related 일정은 차량 상세 상단 배치 + 오늘 이전 일정 제외 1차 반영 완료
- 현재 기준 잠금 커밋: `10e2e04` (`chore: bump release build to v1.0.0+8`)

## 6. 아직 확인 필요
### 예약 레이어
- AppSheet virtual column 실제 식
- 실제 시트 target column 최종명
- 운영 테스트용 API read/write 계약

### 현황판 레이어
- AppSheet 원본 slice / virtual column 실제 식
- `대기 / 일반 / 일정`의 보조 필터 존재 여부
- 탭별 정렬 기준
- 상세 / 액션 흐름
- 장기 탭 반납일 정렬이 실제 데이터 문자열 형식까지 포함해 안정적으로 맞는지 재검증 필요
- 대기 탭 1줄 행을 진짜 고정 컬럼 그리드처럼 보이게 할지 최종 레이아웃 고정 필요
- 일정 상세 / 차량 상세 typography와 field density를 운영 가독성 기준으로 재정렬 필요

## 7. 다음 작업 순서
1. 현황판 정렬/가독성 보정 phase 집행
2. 장기 반납일 정렬 파서 보강 및 overdue 색 기준 고정
3. 대기 탭 고정 컬럼형 레이아웃 확정
4. 일정 상세 / 차량 상세 typography 보강
5. AppSheet 원본 slice / virtual column 식 확인
6. 현황판 탭 필터 2차 확정
7. 예약 액션 / check write 로직 연결
8. outbox dry-run 연결
9. 마지막 phase 전까지 Sheets write 금지 유지

## 8. 마지막 메모
문서 위치가 헷갈리면 이 문서부터 본다.
기준 문서를 더 쪼개지 말고, 필요하면 이 문서가 가리키는 메인 문서로 흡수한다.

## 9. 현황판 다음 수정 phase 잠금
### Phase A. 장기 탭 정렬 보정
- 목적: 반납일이 가장 빠른 차량이 항상 위로 오게 고정
- 기준점: 현재 longTerm 정렬은 `sortAt` 오름차순이나, 실데이터 날짜 문자열 파싱 실패 가능성 존재
- 작업:
  - 장기 전용 날짜 정규화/파서 보강
  - parse 실패 row 처리 규칙 고정
  - 오늘 이전 날짜만 빨간색 유지 검증
- 종료 조건:
  - 장기 탭이 반납일 기준 오름차순으로 안정 정렬
  - overdue 색 기준 일관성 확인

### Phase B. 대기 탭 고정 컬럼화
- 목적: 대기 탭이 한줄 행이면서도 그리드처럼 상하 정렬되게 고정
- 기준점: 현재는 `Flexible/Expanded` 혼합 Row라 열 시작점이 흔들림
- 작업:
  - 차량번호 / 차종 / 세차 / 실내 / 주차지 열 폭 기준 고정
  - 필요 시 헤더 없는 테이블형 row 구조로 전환
  - 아이콘 크기/패딩/텍스트 baseline 통일
- 종료 조건:
  - 스크롤 시 각 행의 열 위치가 눈에 띄게 흔들리지 않음

### Phase C. 상세 가독성 보강
- 목적: 일정 상세 / 차량 상세를 운영 중 빠르게 읽히는 형태로 정리
- 작업:
  - 상단 요약 typography 강화
  - 필드를 `라벨 작게 / 값 크게` 2줄 구조로 전환 검토
  - 카드 패딩/섹션 간격/보조색 재조정
  - 예약번호/차량번호/일정번호 같은 key field 강조 기준 고정
- 종료 조건:
  - 일정 상세 / 차량 상세에서 라벨과 값 구분이 즉시 보임
  - 주요 식별값 가독성 개선
