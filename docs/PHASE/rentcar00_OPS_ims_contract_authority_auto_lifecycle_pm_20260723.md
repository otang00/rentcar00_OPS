# OPS 플랫폼 신규 예약 → IMS 생성 기준 통합 오케스트레이션 PM

## 0. 문서 정보
- 작성일: 2026-07-23
- 수정일: 2026-07-24
- 작성자/agent: OpenClaw rentcar00_ops_developer
- 상태: Draft / 실행 전 정합성 보완 완료 / 구현 미승인
- 승인 범위: PM 문서 수정만 승인됨. 코드 수정, DB migration, parser restart, launchd/cron 변경, 운영 env 수정, commit, deploy, APK build/upload는 미승인.
- 핵심 기준:
  - 플랫폼 신규예약은 별도 권위로 오래 보관하지 않는다.
  - 먼저 intake에 원본을 안전하게 저장한다.
  - IMS 신규예약 생성이 성공한 뒤에만 OPS 예약과 IMS link를 확정한다.
  - 이후 다른 플랫폼 막기/차단은 생성된 IMS 예약을 기준으로 기존 sync 구조에 편입한다.
- 관련 문서:
  - `docs/PHASE/rentcar00_OPS-parser-cloudflare-access-hardening-pm-20260723.md`
  - `docs/COMPLETED/COMPLETE_20260707_rentcar00_OPS_ims_insurance_longterm_dispatch_lifecycle_pm.md`
  - `docs/PHASE/rentcar00_OPS-ops-return-simplification-license-photos-ims-connect-issue-20260721.md`
  - `docs/PHASE/README.md`
- 완료 후 문서명:
  - `docs/COMPLETED/COMPLETE_20260724_rentcar00_OPS_platform_new_reservation_to_ims_orchestrator_pm.md`
- 상태/정책문서 업데이트 대상:
  - `docs/PHASE/README.md`
  - 필요 시 `docs/GOAL/*`
  - 필요 시 `reservation_ai_parser/README.md`
  - 필요 시 booking-system sync runbook

## 1. 목적
- 목표:
  - 플랫폼/홈페이지 신규예약 수신 후 `IMS 신규예약 생성`을 가장 빠르게 수행한다.
  - 생성된 IMS 예약을 운영 권위로 삼아 OPS 예약, 외부 link, 타 플랫폼 차단을 연결한다.
  - 이후 계약/배차/반납/lifecycle은 IMS 기준 상태관리로 합류시킨다.
- 성공 기준:
  - 신규예약 원본은 idempotent intake row에 먼저 저장된다.
  - IMS 생성 필수값 검증 실패 시 OPS 예약을 확정하지 않고 예외로 남긴다.
  - IMS 생성 성공 후에만 OPS 예약과 `rc00_ops_external_reservation_links(provider='ims')` active binding이 생성된다.
  - IMS 생성 성공건은 `ims_sync_reservations` 또는 targeted IMS sync를 통해 차단 sync 기준에 반영된다.
  - 찜카/카모아 등 다른 플랫폼 막기는 기존 sync 구조를 재사용하되, 기준은 새 IMS 예약이다.
  - IMS 생성 실패/중복/차량불가/애매한 케이스는 자동 확정하지 않고 예외 큐로 남긴다.
- 제외 범위:
  - 플랫폼별 신규예약 수집 API 자체를 확정 없이 구현하지 않는다.
  - OPS 예약 스키마 전체 재설계는 제외한다.
  - Cloudflare Access/rules 변경은 제외한다.
  - 운영 `.env`, launchd, restart, deploy, commit은 별도 승인 전 제외한다.
  - 실제 IMS write smoke는 별도 승인 전 제외한다.

## 2. 현재 상태
- 확인한 파일/docs:
  - `reservation_ai_parser/src/homepage-reservation-mapper.js`
  - `reservation_ai_parser/src/server.js`
  - `lib/data/models/external_reservation_link.dart`
  - `lib/data/models/reservation_record.dart`
  - `lib/data/repositories/supabase_ops_repository.dart`
  - `lib/features/auth/domain/staff_account.dart`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/server/notifications/sendOpsAppReservationEvent.js`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/server/notifications/opsAppReservationEventOutbox.js`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/scripts/ims-sync/run-ims-reservation-sync.js`
  - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/scripts/zzimcar-sync/lib/fetch-desired-ims-reservations.js`
  - `supabase/migrations/20260515171000_add_external_reservation_links.sql`
  - `supabase/migrations/20260515182000_allow_unlinked_external_reservation_links.sql`
  - `docs/PHASE/README.md`
  - `PROJECT_DOCUMENTATION_RULES.md`
- 현재 git 상태:
  - branch: `fix/ops-return-complete-end-at`
  - untracked PM 문서 여러 개 존재
  - 현재 문서도 local draft 상태
- 기존 구현/문서 상태:
  - 홈페이지는 `reservation.created` 이벤트를 outbox + HMAC POST로 OPS parser에 전달할 수 있다.
  - OPS parser는 `mapHomepageReservationPayload()`로 홈페이지 예약을 OPS 신규예약 입력 구조로 정규화할 수 있다.
  - 현재 홈페이지 event import는 `rc00_ops_reservations`/states/schedules를 먼저 생성한다.
  - OPS parser에는 `/ims/create-reservation` 경로와 IMS 생성 후 binding 해석 함수가 있다.
  - `normalizeImsReservationPayload()` 필수값은 `rentalAt`, `returnAt`, `carNumber`, `totalFee`, `customerName`, `customerPhone`이다.
  - `rc00_ops_external_reservation_links.provider`는 현재 `ims`만 허용한다.
  - `external_status`는 현재 `linked`, `failed`, `deleted`, `unlinked`만 허용한다.
  - booking-system의 플랫폼 sync는 IMS projection(`ims_sync_reservations`)을 기준으로 찜카/카모아 차단을 수행하는 구조가 확인된다.
- 확인 필요:
  - 찜카/카모아 신규예약 수집 API가 실제로 가능한지와 endpoint/인증/필드 구조.
  - IMS 생성 직후 targeted IMS sync를 실행할지, projection table에 직접 반영할지, 다음 sync 주기를 기다릴지 최종 선택.
  - IMS 생성 성공 후 OPS 예약/link 저장 실패 시 복구 절차.
  - cross-project 변경 시 OPS repo와 booking-system repo의 commit/배포 순서.

## 3. 전체 변경 요약
- 변경점:
  - 기존 `OPS 예약 생성 후 IMS 생성` 순서를 `intake 저장 → IMS 생성 성공 → OPS 예약+IMS link 확정`으로 보정한다.
  - 신규 intake/오케스트레이션 이력/예외 테이블을 명시한다.
  - `external_reservation_links`는 IMS active binding 전용으로 유지하고, pending/exception은 별도 intake/orchestration 테이블에서 관리한다.
  - 플랫폼 신규예약 수집 가능성 확인을 선행 phase로 분리한다.
  - IMS 생성 직후 차단 반영 타이밍을 별도 phase에서 선택한다.
  - OPS repo 변경과 booking-system sync 변경을 분리한다.
- 변경대상:
  - OPS repo:
    - `reservation_ai_parser/src/server.js`
    - 신규 orchestrator module 후보
    - Supabase migration 후보
    - OPS 앱 예외 표시 UI 후보
    - `docs/PHASE/README.md`
  - booking-system repo:
    - reservation event outbox/payload 후보
    - `scripts/ims-sync/*`
    - `scripts/zzimcar-sync/*`
    - `scripts/carmore-sync/*`
    - sync runbook 후보
- 예상 영향:
  - 신규예약 자동생성의 기준점이 플랫폼 원본 예약이 아니라 생성된 IMS 예약으로 이동한다.
  - IMS 생성 실패 시 OPS 확정 예약이 생기지 않으므로 고아예약 위험이 줄어든다.
  - 차단 반영은 IMS projection 반영 타이밍에 의존한다.
- 주요 리스크:
  - IMS 생성 성공 후 로컬 DB 확정 실패 시 복구가 필요하다.
  - 중복방지 키가 약하면 IMS 중복 예약이 생길 수 있다.
  - 플랫폼별 신규예약 필드 품질이 IMS 필수값을 만족하지 못할 수 있다.
  - booking-system sync와 OPS parser 배포 순서가 어긋나면 차단 지연이 생길 수 있다.

## 4. 기준 아키텍처
- 기준 흐름:
  1. 플랫폼/홈페이지 신규예약 수신
  2. 원본 payload를 `rc00_ops_external_reservation_intake`에 idempotent 저장
  3. canonical payload 정규화
  4. IMS 생성 필수값 preflight 검증
  5. IMS 신규예약 생성 시도
  6. IMS 생성 성공 응답 또는 검색 확인으로 IMS reservation/detail/schedule id 확보
  7. OPS 예약/reservation state/schedules 생성
  8. `rc00_ops_external_reservation_links(provider='ims')`에 active binding 저장
  9. `rc00_ops_reservation_orchestration_*`에 실행 결과 기록
  10. targeted IMS sync 또는 projection 반영 후 기존 찜카/카모아 차단 sync에 편입
  11. 이후 배차/반납은 IMS lifecycle 기준 처리
- 권장 구현 원칙:
  - `external_reservation_links`는 IMS 권위 링크만 저장한다.
  - pending/failed/exception/dry_run은 intake/orchestration 테이블에 저장한다.
  - IMS write는 반드시 idempotency key와 중복 검색 선행을 둔다.
  - IMS 생성 전에는 다른 플랫폼 차단을 확정하지 않는다.
  - IMS 생성 후 차단 sync 반영 전까지는 `차단 대기` 상태로 표시한다.

## 5. 신규/보강 테이블 제안

### 필수 후보: `rc00_ops_external_reservation_intake`
- 역할: 플랫폼/홈페이지 신규예약 원본 수신 및 중복방지.
- 주요 컬럼 후보:
  - `id uuid`
  - `source_provider text` (`homepage`, `zzimcar`, `carmore`, etc.)
  - `source_event_id text`
  - `source_reservation_id text`
  - `idempotency_key text unique`
  - `payload_json jsonb`
  - `canonical_payload_json jsonb`
  - `status text` (`received`, `preflight_failed`, `ims_create_pending`, `ims_created`, `ops_confirmed`, `exception`)
  - `ims_create_attempts int`
  - `last_error text`
  - `created_at`, `updated_at`

### 필수 후보: `rc00_ops_reservation_orchestration_runs`
- 역할: 오케스트레이터 실행 이력.
- 주요 컬럼 후보:
  - `id uuid`
  - `run_type text` (`homepage_event`, `platform_poll`, `ims_sync_attach`, `manual_retry`)
  - `status text`
  - `started_at`, `finished_at`
  - `summary_json jsonb`
  - `error_text text`

### 필수 후보: `rc00_ops_reservation_orchestration_exceptions`
- 역할: 자동 처리 실패/수동 검토 큐.
- 주요 컬럼 후보:
  - `id uuid`
  - `intake_id uuid`
  - `reservation_id text null`
  - `ims_reservation_id text null`
  - `exception_type text`
  - `severity text`
  - `message text`
  - `payload_json jsonb`
  - `status text` (`open`, `acknowledged`, `resolved`, `ignored`)

### 선택 후보: `rc00_ops_reservation_orchestration_links`
- 역할: source 예약 ↔ OPS 예약 ↔ IMS 예약 매핑 이력.
- 비고: 단순 구조면 intake + external link + run log로 대체 가능하다.

## 6. Phase 목록

### Phase 0. 실행 기준 보정 및 플랫폼 신규예약 API 확인
- 목적:
  - 실행 전에 순서/DB/차단 타이밍/cross-project 범위를 확정한다.
- 변경점:
  - PM 실행 기준을 `intake 저장 → IMS 생성 성공 → OPS 예약+IMS link 확정`으로 잠근다.
  - 찜카/카모아 신규예약 조회 API 가능 여부를 확인한다.
  - IMS 생성 직후 차단 반영 방식을 선택한다.
- 변경대상:
  - 문서/조사 결과
  - 코드 변경 없음
- 실행방법:
  - 현재 찜카/카모아 sync 코드가 신규예약 조회를 지원하는지 확인한다.
  - 없으면 플랫폼 신규예약 수집은 별도 API discovery PM으로 분리한다.
  - 차단 반영 방식 후보를 비교한다:
    1. IMS 생성 직후 targeted IMS sync 실행
    2. 생성 결과를 `ims_sync_reservations`에 projection upsert
    3. 다음 정기 IMS sync까지 대기
  - 권장 기본값은 1번, 불가능하면 3번으로 시작한다. 2번은 schema/source 불일치 위험이 있어 후순위.
- 종료조건:
  - 플랫폼 신규예약 수집 가능/불가/확인필요가 구분된다.
  - 차단 반영 타이밍이 선택된다.
  - OPS repo와 booking-system repo 변경 경계가 고정된다.
- 검증방법:
  - 코드 inspection
  - sync dry-run 경로 확인
- 리스크:
  - 플랫폼 신규예약 API가 없으면 홈페이지 예약부터 먼저 적용해야 함.
- 되돌릴 방법:
  - 문서 기준 원복
- 출력보고:
  - API 가능성, 차단 반영 방식, repo별 변경 범위

### Phase 1. parser API 인증 선행 적용
- 목적:
  - IMS write API 확대 전에 공개 parser API 무단 호출 위험을 먼저 줄인다.
- 변경점:
  - `rentcar00_OPS-parser-cloudflare-access-hardening-pm-20260723.md` 기준으로 OPS parser token guard를 선행 적용한다.
- 변경대상:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/parser-core.js`
  - OPS 앱 parser clients
  - README/docs
- 실행방법:
  - `/health` 공개 유지
  - 홈페이지 HMAC endpoint 유지
  - `/ims/create-reservation` 포함 위험 API는 `X-Ops-Parser-Token` 필요
- 종료조건:
  - token 없는 IMS write API가 차단된다.
  - 홈페이지 HMAC 이벤트는 영향 없다.
- 검증방법:
  - parser check
  - Flutter analyze
  - 로컬 smoke
- 리스크:
  - 운영 env/restart/APK 배포 순서가 어긋나면 기존 앱 기능 차단
- 되돌릴 방법:
  - token guard/client header 원복
- 출력보고:
  - 보호 경로, 제외 경로, 검증 결과

### Phase 2. intake canonical payload 및 dedupe key 확정
- 목적:
  - 신규예약 원본 저장과 IMS 생성 입력 변환 기준을 잠근다.
- 변경점:
  - 홈페이지 mapper를 기준으로 canonical payload 필드셋 확정
  - source별 idempotency key 규칙 확정
- 변경대상:
  - parser mapper/orchestrator 설계
  - 필요 시 schema 문서
- 실행방법:
  - IMS 필수값: `rentalAt`, `returnAt`, `carNumber`, `totalFee`, `customerName`, `customerPhone`
  - 홈페이지는 `eventId`, `booking_order_id`, `reservation_code` 우선
  - 플랫폼은 `source_provider + source_reservation_id` 우선
- 종료조건:
  - canonical payload 필드 목록과 필수값 누락 차단 기준이 잠긴다.
- 검증방법:
  - mapper와 IMS create input 비교 inspection
- 리스크:
  - 플랫폼별 필드 차이 누락
- 되돌릴 방법:
  - schema 초안 원복
- 출력보고:
  - canonical 필드셋, 필수값, dedupe 규칙

### Phase 3. Supabase intake/orchestration migration 설계 및 적용
- 목적:
  - 자동화 원본/이력/예외를 추적할 DB 구조를 만든다.
- 변경점:
  - `rc00_ops_external_reservation_intake`
  - `rc00_ops_reservation_orchestration_runs`
  - `rc00_ops_reservation_orchestration_exceptions`
  - 필요 시 `rc00_ops_reservation_orchestration_links`
- 변경대상:
  - `supabase/migrations/*`
  - repository/parser DB helpers
- 실행방법:
  - `external_reservation_links.provider`는 `ims` 유지
  - `external_reservation_links.external_status`에 pending/exception을 억지로 넣지 않는다.
  - pending/exception은 intake/orchestration 테이블에서 관리한다.
- 종료조건:
  - 원본 수신, IMS 생성 시도, 예외 기록이 모두 DB로 추적 가능하다.
- 검증방법:
  - migration SQL review
  - local/remote apply는 별도 승인
- 리스크:
  - DB migration은 protected target
- 되돌릴 방법:
  - migration rollback script 또는 down 계획
- 출력보고:
  - 생성 테이블, constraint, index, RLS 기준

### Phase 4. intake 저장 → IMS 생성 → OPS 확정 오케스트레이터 구현
- 목적:
  - 신규예약을 안전한 순서로 IMS 예약까지 자동 생성한다.
- 변경점:
  - 기존 홈페이지 import의 `OPS 예약 선생성` 흐름을 `intake first` 흐름으로 보정한다.
  - IMS 생성 성공 후 OPS 예약/states/schedules/link를 확정한다.
- 변경대상:
  - `reservation_ai_parser/src/server.js`
  - 신규 orchestrator module 후보
  - IMS create helper
  - Supabase REST/admin helper
- 실행방법:
  - raw event 저장
  - canonical transform
  - preflight validate
  - duplicate IMS candidate search
  - IMS create
  - IMS binding resolve
  - OPS reservation/state/schedule/link insert
  - run/exception 기록
- 종료조건:
  - 홈페이지 신규예약 1건이 dry-run/mock 기준으로 intake→IMS→OPS/link 흐름을 통과한다.
- 검증방법:
  - unit/fixture test
  - dry-run
  - 실제 IMS write smoke는 별도 승인
- 리스크:
  - IMS 생성 성공 후 OPS 저장 실패 시 복구 필요
- 되돌릴 방법:
  - orchestrator off, 기존 import 경로로 원복
- 출력보고:
  - 성공/실패/중복/예외 결과

### Phase 5. IMS 생성 직후 차단 sync 연결
- 목적:
  - 생성된 IMS 예약이 다른 플랫폼 차단 기준에 빠르게 반영되게 한다.
- 변경점:
  - booking-system IMS sync/reconcile과 연결 방식을 구현한다.
- 변경대상:
  - booking-system repo:
    - `scripts/ims-sync/run-ims-reservation-sync.js`
    - `scripts/ims-sync/upsert-ims-reservations.js`
    - `scripts/zzimcar-sync/*`
    - `scripts/carmore-sync/*`
  - OPS repo는 link/result만 제공
- 실행방법:
  - 기본 추천: IMS 생성 성공 후 targeted IMS sync 또는 다음 IMS sync 주기에서 `ims_sync_reservations` 반영 확인
  - 반영 확인 후 기존 찜카/카모아 reconcile이 차단을 수행한다.
  - 차단 write는 no-write smoke → 승인된 write 순서로만 진행한다.
- 종료조건:
  - 새 IMS 예약이 `ims_sync_reservations`에 나타난다.
  - 기존 platform reconcile dry-run에서 차단 대상이 확인된다.
- 검증방법:
  - booking-system no-write smoke
  - targeted IMS sync dry-run
- 리스크:
  - cross-project 배포/커밋 순서 혼선
- 되돌릴 방법:
  - booking-system sync 연결부 원복
- 출력보고:
  - IMS projection 반영 방식, 차단 sync dry-run 결과

### Phase 6. IMS lifecycle 자동 반영 정렬
- 목적:
  - 생성된 IMS 예약 이후의 배차/반납 상태를 IMS lifecycle 자동화 방향에 맞춘다.
- 변경점:
  - 신규 자동생성 예약은 곧바로 IMS-linked 예약으로 취급한다.
  - 수동완료 제한/자동 배차/반납 반영 정책과 연결한다.
- 변경대상:
  - OPS 앱 UI 정책
  - lifecycle sync worker 또는 IMS sync attach module
- 실행방법:
  - IMS sync 결과를 기준으로 OPS `completeSchedule()`에 해당하는 상태 변경을 자동 적용한다.
  - 예외/중복/상태불명은 자동처리 금지.
- 종료조건:
  - intake 이후 예약이 별도 예외 흐름 없이 IMS lifecycle에 합류한다.
- 검증방법:
  - 상태 전이 표
  - dry-run 대상/결과 비교
- 리스크:
  - 기존 lifecycle PM과 책임 경계 혼선
- 되돌릴 방법:
  - lifecycle attach off
- 출력보고:
  - intake 이후 lifecycle handoff 지점

### Phase 7. 예외 큐 및 수동 검토 경로
- 목적:
  - IMS 자동생성 실패/애매/중복 케이스를 안전하게 수동 검토로 넘긴다.
- 변경점:
  - 예외 유형 분류: 필수값 부족, 차량중복, IMS 생성 실패, timeout, duplicate candidate, projection delay
  - 관리자/예외권한 검토 경로 설계
- 변경대상:
  - 예외 저장 구조
  - OPS 앱 예외 표시 UI
  - repository/helper
- 실행방법:
  - auto fail 시 `확인 필요`와 원인 저장
  - 일반 직원 자동확정 금지
  - 권한자만 재시도/수정/수동연결 가능
- 종료조건:
  - 실패건이 유실되지 않고 수동처리 가능하다.
- 검증방법:
  - exception scenario matrix review
- 리스크:
  - 예외 큐 설계가 약하면 운영 누락
- 되돌릴 방법:
  - 예외 구조 원복
- 출력보고:
  - 예외 유형, 수동검토 기준, 권한 조건

### Phase 8. 운영 스케줄러/런타임 적용
- 목적:
  - 신규예약 intake와 후속 sync/lifecycle이 실제 운영에서 끊기지 않게 한다.
- 변경점:
  - parser inline 처리 vs outbox worker 분리 최종 선택
  - launchd/cron/runtime restart/secret 점검
- 변경대상:
  - launchd 또는 운영 scheduler
  - parser runtime
  - booking-system sync runtime
  - 운영 `.env` / secret 참조
- 실행방법:
  - 운영 승인 후 no-write smoke
  - 이후 제한된 실예약 1건 smoke
  - 문제 없을 때 주기 작업 활성화
- 종료조건:
  - 신규예약 수신→IMS 생성→OPS 확정→IMS projection→차단 연계가 운영에서 재현된다.
- 검증방법:
  - runtime log
  - dry-run
  - 승인된 실예약 smoke
- 리스크:
  - protected target 변경
  - 실운영 중복 생성 위험
- 되돌릴 방법:
  - scheduler disable, worker off
- 출력보고:
  - job 방식, 로그 위치, 마지막 smoke 결과

### Final Phase. 검수·완료판정·상태/정책문서 정리·문서 COMPLETE 변경·커밋
- 목적:
  - 전체 phase가 승인 범위대로 끝났는지 검수하고 완료 문서/커밋까지 정리한다.
- 변경점:
  - 전체 변경 검수
  - 완료판정
  - 상태변경/정책변경 문서 업데이트
  - PM 문서를 `docs/COMPLETED/COMPLETE_20260724_*`로 이동 또는 rename
  - OPS repo commit
  - booking-system repo 변경이 있다면 별도 commit
- 변경대상:
  - `docs/PHASE/README.md`
  - `docs/COMPLETED/COMPLETE_20260724_rentcar00_OPS_platform_new_reservation_to_ims_orchestrator_pm.md`
  - 관련 README/runbook
  - git commit
- 실행방법:
  - 테스트/analyze/dry-run/smoke 결과 정리
  - 문서 최신화
  - commit 승인 포함 시에만 commit
- 종료조건:
  - 모든 승인 phase 완료
  - 검증 결과 기록
  - 완료 문서 생성
  - 커밋 또는 커밋 제외 사유 기록
- 검증방법:
  - `git status`
  - analyze/test/dry-run 결과
  - 문서 경로 확인
- 리스크:
  - 문서와 실제 구현 불일치
- 되돌릴 방법:
  - 완료 문서/README 변경 원복
  - commit 전이면 diff 기준 원복
- 출력보고:
  - 완료 phase, 변경 파일, 검증 결과, 완료 문서, 커밋 해시/제외 사유, 남은 리스크

## 7. 승인 및 중단 조건
- 승인 요청:
  - 이 문서는 실행 승인이 아니다.
  - 첫 실행 추천은 `Parser API Auth Hardening PM`의 Phase 1~2 또는 본 문서의 Phase 0이다.
  - 실제 구현 순서는 아래 `8. 진행 우선순위 판정`을 따른다.
  - 코드 구현은 phase별 별도 승인 필요.
  - DB migration, 운영 env, launchd, restart, 실제 IMS write/smoke, commit은 각 phase별 별도 승인 필요.
- 중단 조건:
  - 플랫폼별 필수값 품질이 IMS 생성 기준을 만족하지 못하는 경우
  - 중복방지 키를 안정적으로 잠글 수 없는 경우
  - IMS 생성 API 응답이 부분성공/중복생성에 안전하지 않은 경우
  - 차단 sync가 새 canonical IMS link를 읽을 수 없는 경우
  - 운영 secret/env/launchd 수정이 필요한데 별도 승인이 없는 경우
- protected target 별도 승인 필요 여부:
  - 필요함
  - 대상:
    - `.env*`, IMS/Supabase/service role secret
    - launchd plist / scheduler
    - parser restart/deploy
    - DB migration/apply
    - 운영 worker enable
    - 실제 IMS write smoke

## 8. 진행 우선순위 판정

### 1순위: Parser API Auth Hardening
- 이유:
  - 신규예약 자동화는 `/ims/create-reservation` 같은 write 성격 API 사용을 확대한다.
  - 현재 parser API 인증 PM은 구현 준비가 가장 잘 되어 있다.
  - 보안 가드 없이 자동 생성 기능을 넓히면 외부 오남용 리스크가 커진다.
- 선행 범위:
  - parser route guard
  - OPS 앱 client header
  - 운영 반영 순서 문서화
- 단, 운영 env/restart/APK는 별도 승인 전 미실행.

### 2순위: 본 PM Phase 0~3
- 이유:
  - 실제 자동화 구현 전에 플랫폼 신규예약 API 가능성, DB 구조, 차단 타이밍을 잠가야 한다.
  - 특히 DB migration 구조가 확정돼야 orphan/중복/예외 추적이 가능하다.
- 권장 범위:
  - Phase 0 실행 기준 보정
  - Phase 2 canonical/dedupe
  - Phase 3 DB migration 설계

### 3순위: 홈페이지 신규예약 → IMS 생성 자동화
- 이유:
  - 홈페이지 outbox/HMAC/mapper가 이미 있어 가장 먼저 검증하기 좋다.
  - 찜카/카모아 신규예약 수집은 아직 API 확인이 필요하다.
- 권장 범위:
  - Phase 4를 홈페이지 source 한정으로 먼저 구현
  - dry-run/mock 후 실예약 1건 smoke는 별도 승인

### 4순위: booking-system IMS projection/차단 sync 연결
- 이유:
  - IMS 생성 성공건이 기존 차단 sync에 실제 반영되어야 전체 목적이 완성된다.
  - cross-project 변경이므로 OPS repo 구현과 분리해 검증한다.

### 5순위: 플랫폼 신규예약 수집 확장
- 이유:
  - 찜카/카모아는 현재 차단/동기화 코드는 확인됐지만 신규예약 추출 API는 확인 필요다.
  - API 확인 전 자동생성 구현은 불가.

## 9. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- 완료 문서 경로:
- 상태/정책문서 업데이트:
- 커밋:
- 남은 리스크:
