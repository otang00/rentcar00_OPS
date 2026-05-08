# rentcar00_OPS Next Phase Prep

## 목표
이 문서는 이제 준비 단계 완료 기록이다.
다음 작업은 원격 DB에 migration 을 적용하고, 앱 데이터 공급자를 mock 에서 Supabase 로 전환하는 것이다.

## 현재 기준
- Supabase 프로젝트 생성 완료
  - name: `rentcar00-ops`
  - ref: `wojisucidqzjrqbuiikl`
  - region: `ap-northeast-2 (Seoul)`
- 앱용 공개 env 와 작업용 secret env 를 분리했다.
- 앱 메인 리스트는 한 줄 중심 카드로 축약 완료했다.
- 현재 데이터 공급자는 mock repository 다.

## 완료된 범위
1. `flutter_dotenv` 연결 완료
2. 공개 env 로드 완료
3. Supabase Flutter client 초기화 완료
4. analyze / test 통과 완료
5. `rentcar00_OPS-db-build-order-v1.md` 기준 migration 초안 작성 완료

## 공개 env 원칙
앱 번들에 포함 가능한 값만 앱용 env 에 둔다.
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_PUBLISHABLE_KEY`

앱 번들에 넣지 말아야 하는 값은 작업/서버용으로만 둔다.
- DB password
- service role
- Google service account / API secret

## 다음 스키마 기준 문서
- `docs/rentcar00_OPS-db-build-order-v1.md`
- 이 문서를 기준으로 raw -> projection -> state -> log/outbox 순서로 생성한다.

## 단계별 구체 실행계획

### Phase 1. Flutter dotenv 연결
목적:
- 앱 시작 시 공개 env 를 읽을 수 있게 만든다.

실행:
1. `flutter_dotenv` 패키지 추가
2. `.env` 를 Flutter asset 로 로드하도록 연결
3. `main.dart` 에서 앱 시작 전 env load 실행

검증:
- `flutter analyze`
- `flutter test`
- env load 실패 시 앱 시작부 에러 확인

종료 조건:
- 앱 시작 코드에서 `.env` load 가 성공한다.

### Phase 2. Supabase client 초기화
목적:
- 공개 env 를 사용해 Supabase client 를 생성한다.

실행:
1. supabase flutter 패키지 추가
2. 앱 공통 config/provider 파일 생성
3. `SUPABASE_URL`, `SUPABASE_ANON_KEY` 기반 초기화
4. Riverpod 에서 client 접근 경로 고정

검증:
- `flutter analyze`
- `flutter test`
- 초기화 예외 없음 확인

종료 조건:
- 앱 어디서든 Supabase client 를 읽을 수 있다.

### Phase 3. DB migration 뼈대 생성
목적:
- Supabase migration 작업을 시작할 수 있는 로컬 구조를 만든다.

실행:
1. `supabase/` 디렉토리 초기화
2. migrations 디렉토리 생성
3. `rentcar00_OPS-db-build-order-v1.md` 기준으로 첫 migration 초안 작성
4. 생성 대상 7개 테이블 SQL 파일 분리 여부 결정

검증:
- migration 파일 존재 확인
- 테이블 생성 순서가 문서와 일치하는지 검토

종료 조건:
- migration 구조와 첫 SQL 초안이 준비된다.

### Phase 4. 테이블 생성 SQL 작성
목적:
- raw -> projection -> state -> action/outbox 생성 SQL 을 고정한다.

실행:
1. `rc00_ops_sheet_sync_runs`
2. `rc00_ops_sheet_reservations_raw`
3. `rc00_ops_sheet_schedules_raw`
4. `rc00_ops_reservations`
5. `rc00_ops_reservation_states`
6. `rc00_ops_action_logs`
7. `rc00_ops_outbox`

각 테이블에서 함께 정할 것:
- PK
- unique
- index
- FK
- nullable 범위
- json 컬럼 사용 범위

검증:
- SQL 검토
- 순서/참조관계 충돌 없는지 확인

종료 조건:
- 초기 DB 생성 SQL 이 준비된다.

### Phase 5. 앱 repository 전환 준비
목적:
- mock repository 를 Supabase repository 로 바꿀 준비를 끝낸다.

실행:
1. 현재 mock provider 주입 경로 확인
2. repository interface 유지 여부 결정
3. supabase repository skeleton 추가
4. mock/supabase 교체 포인트 고정

검증:
- 기존 UI 경로 영향 범위 확인
- 교체 대상 provider 식별 완료

종료 조건:
- repository 교체 작업을 바로 시작할 수 있다.

### Phase 6. read-only importer 준비
목적:
- Google Sheets -> raw import 구조를 착수 가능한 수준으로 정리한다.

실행:
1. importer 실행 위치 결정
   - Edge Function
   - 외부 worker
   - 수동 스크립트
2. 시트 인증 방식 결정
3. `예약` / `일정` read mapping 표 작성
4. raw insert -> projection upsert -> state recalc 순서 고정

검증:
- source/target 매핑 누락 체크
- orphan 일정 처리 기준 재확인

종료 조건:
- read-only importer 구현에 바로 들어갈 수 있다.

## 다음 착수 기준
- repository 교체 시작
- raw -> projection 정규화 작성
- importer 실행 위치 확정
- Google Sheets 수동 import 재실행/검증 기준 정리
