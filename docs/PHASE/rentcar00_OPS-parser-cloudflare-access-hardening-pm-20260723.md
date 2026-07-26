# rentcar00_OPS Parser API Auth Hardening PM

## 0. 문서 정보
- 작성일: 2026-07-23
- 작성자/agent: OpenClaw rentcar00_ops_developer
- 상태: Draft / Implementation Ready
- 승인 범위: OPS 앱 → parser API 인증 가드 구현 준비. 실행은 별도 승인 필요.
- 관련 문서:
  - `docs/PHASE/README.md`
  - `reservation_ai_parser/README.md`
  - `reservation_ai_parser/src/server.js`
  - OPS 앱 parser clients:
    - `lib/features/status_board/detail/data/reservation_ai_parser_client.dart`
    - `lib/features/reservations/detail/data/ims_reservation_client.dart`
    - `lib/features/fines/data/fine_notice_ai_parser_client.dart`
    - `lib/features/fines/data/fine_notice_contract_matching_client.dart`
    - `lib/features/fines/data/fine_notice_document_client.dart`
    - `lib/features/fines/data/fine_notice_contract_pdf_client.dart`
  - 홈페이지 outbox:
    - `/Users/otang_server/.openclaw/workspace/projects/rentcar00-booking-system/server/notifications/sendOpsAppReservationEvent.js`
- 완료 후 문서명: `docs/COMPLETED/COMPLETE_20260723_rentcar00_OPS_parser_api_auth_hardening_pm.md`
- 상태/정책문서 업데이트 대상:
  - `docs/PHASE/README.md`
  - `reservation_ai_parser/README.md`
  - 필요 시 `docs/GOAL/rentcar00_OPS-current.md`

## 1. 목적
- 목표: 공개된 `parser.00rentcar.com` 위험 API를 인증 없는 외부 요청에서 차단한다.
- 성공 기준:
  - OPS 앱용 parser API는 `X-Ops-Parser-Token` 없으면 `401`.
  - 홈페이지 예약 이벤트 `/api/integrations/rentcar00/reservation-events`는 기존 HMAC 유지.
  - `/health`는 공개 유지.
  - sync worker는 parser에 의존하지 않으므로 변경하지 않는다.
  - 정상 OPS 앱 호출은 토큰 헤더 포함 후 유지된다.
- 제외 범위:
  - Cloudflare Access 정책 변경
  - IMS 계정/비밀번호 변경
  - Supabase schema 변경
  - 홈페이지 outbox HMAC 구조 변경
  - sync worker 구조 변경
  - APK build/upload, deploy, restart, commit은 별도 승인

## 2. 현재 상태
- 확인한 파일/docs:
  - `reservation_ai_parser/src/server.js`
  - OPS 앱 parser client 6개 파일
  - 홈페이지 `sendOpsAppReservationEvent.js`
  - launchd 서비스 상태
- 현재 git 상태:
  - branch: `fix/ops-return-complete-end-at...origin/fix/ops-return-complete-end-at`
  - 기존 untracked phase docs 있음
- 현재 구현 상태:
  - parser는 Mac mini에서 `127.0.0.1:43110` 로컬 실행.
  - Cloudflare tunnel이 `https://parser.00rentcar.com`으로 외부 노출.
  - OPS 앱은 `AI_PARSER_BASE_URL` 기반으로 parser 공개 URL 호출.
  - OPS 앱 parser/IMS/fine-notice 호출에 인증 헤더 없음.
  - 홈페이지 예약 이벤트는 HMAC 서명 헤더 사용.
  - sync worker(`premove-ims-sync`, `carmore`, `zzimcar`)는 parser 호출이 아니라 DB/외부 API sync 구조.
- 공개 API 점검 결과:
  - `/health`: `200 OK`
  - 임의 경로 `/`, `/ops`, `/admin`, `/debug`: `404`
  - `/api/integrations/rentcar00/reservation-events`: 잘못된 HMAC `401`, 정상
  - `/parse-*`, `/ims/*`, `/fine-notices/*`, `/fine-notice-file-*`: 코드상 공통 인증 가드 없음
- 확인 필요:
  - 실제 배포 APK의 `AI_PARSER_BASE_URL` 값.
  - token 값을 어떤 이름으로 `.env`/앱 env에 둘지.
  - 운영 반영 시 parser restart 승인 여부.

## 3. 최종 보안 구조

### 호출 주체별 정책

| 호출 주체 | 경로 | 인증 방식 | 변경 여부 |
|---|---|---|---|
| OPS 앱 | `/parse-reservation` | `X-Ops-Parser-Token` | 추가 |
| OPS 앱 | `/parse-fine-notice` | `X-Ops-Parser-Token` | 추가 |
| OPS 앱 | `/ims/search-*` | `X-Ops-Parser-Token` | 추가 |
| OPS 앱 | `/ims/create-*`, `/ims/change-*`, `/ims/delete-*`, `/ims/complete-*` | `X-Ops-Parser-Token` | 추가 |
| OPS 앱 | `/fine-notices/*` | `X-Ops-Parser-Token` | 추가 |
| OPS 앱 | `/fine-notice-file-packages`, `/fine-notice-files/download` | `X-Ops-Parser-Token` | 추가 |
| 홈페이지 예약 outbox | `/api/integrations/rentcar00/reservation-events` | 기존 HMAC | 유지 |
| 상태 확인 | `/health` | 공개 | 유지 |
| sync worker | parser 호출 없음 | 해당 없음 | 변경 없음 |

### 설계 원칙
- 앱이 비공개 직원용 APK라는 운영 기준을 반영해 Supabase JWT 검증은 이번 범위에서 제외한다.
- APK 내 공통 토큰은 완전한 비밀은 아니지만, 현재 무인 공개 실행 가능 상태를 즉시 낮추는 1차 방어로 사용한다.
- IMS 계정정보는 계속 parser 서버 내부에만 둔다.
- Cloudflare는 보조 방어다. 핵심 차단은 parser 서버에서 직접 `401`로 수행한다.

## 4. 전체 변경 요약
- 변경점:
  - parser 서버에 OPS 앱용 shared token guard 추가.
  - OPS 앱 parser client 공통 헤더 추가.
  - 문서에 인증 정책 기록.
  - 운영 secret/env/restart는 별도 phase로 분리.
- 변경대상:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/parser-core.js` 또는 config load 영역
  - OPS 앱 client 파일 6개
  - `reservation_ai_parser/README.md`
  - `docs/PHASE/README.md`
- 예상 영향:
  - token 없는 외부 요청은 차단.
  - token이 없는 기존 앱 빌드는 parser 기능 실패.
  - 새 APK 배포 전 운영 parser에 token guard를 켜면 직원 앱 기능이 막힐 수 있음.
- 주요 리스크:
  - `.env`/앱 env token 값은 protected target.
  - parser restart 필요.
  - APK 내부 token 추출 가능성은 남음.
  - 구버전 APK와 운영 parser 호환성 관리 필요.

## 5. Phase 목록

### Phase 1. 구현 기준점 고정 및 테스트 설계
- 목적: 변경 전 route/client/검증 기준을 고정한다.
- 변경점: 없음. 읽기/검증 명령만 수행.
- 변경대상: 없음.
- 실행방법:
  - parser route 목록 재확인.
  - OPS 앱 client별 호출 path 재확인.
  - 홈페이지 HMAC 경로가 이번 guard 대상에서 제외되는지 확인.
  - test/check 명령 확정.
- 종료조건:
  - 보호 대상 path 목록과 제외 path 목록이 확정된다.
- 검증방법:
  - grep/코드 inspection 결과 기록.
- 리스크:
  - 누락 path가 있으면 일부 API가 계속 열릴 수 있음.
- 되돌릴 방법: 읽기 전용이라 불필요.
- 출력보고: path 정책표와 수정 대상 파일 목록.

### Phase 2. parser 서버 token guard 구현
- 목적: 인증 없는 위험 API를 서버에서 직접 차단한다.
- 변경점:
  - env config에 `OPS_APP_PARSER_TOKEN` 또는 동등 key 추가.
  - `requireOpsParserToken(req)` 추가.
  - 위험 API route 앞에서 token 검증.
  - missing/mismatch 시 `401 invalid_ops_parser_token` 반환.
  - `/health`와 `/api/integrations/rentcar00/reservation-events`는 제외.
- 변경대상:
  - `reservation_ai_parser/src/server.js`
  - `reservation_ai_parser/src/parser-core.js`
  - 필요 시 `.env.example`
- 실행방법:
  - 실제 secret 값은 코드에 넣지 않는다.
  - token 비교는 timing-safe 방식 후보.
  - env가 비어 있으면 운영 차단 방식 결정 필요:
    - 권장: 위험 API는 `503 parser_token_not_configured`로 fail-closed
    - 구버전 호환 필요 시 별도 승인 전에는 fail-open 금지
- 종료조건:
  - token 없는 요청이 로컬 테스트에서 차단된다.
  - HMAC 이벤트와 health는 기존대로 통과한다.
- 검증방법:
  - `node --check reservation_ai_parser/src/server.js`
  - `npm --prefix reservation_ai_parser run check`
  - 로컬 curl smoke:
    - no token → `401`
    - wrong token → `401`
    - valid token → 기존 validation error 또는 정상 응답
    - `/health` → `200`
    - reservation-events invalid HMAC → `401` 유지
- 리스크:
  - 운영 `.env` token 설정 전 restart하면 위험 API가 `503/401`로 막힘.
- 되돌릴 방법:
  - server/config diff revert.
- 출력보고: 변경 파일, route별 차단 결과, 테스트 결과.

### Phase 3. OPS 앱 client 헤더 추가
- 목적: 직원용 OPS 앱이 parser token을 첨부해 정상 호출되도록 한다.
- 변경점:
  - `AppEnv`에 `OPS_PARSER_API_TOKEN` 또는 동등 key 추가.
  - parser client 생성부/clients에 token 전달.
  - 모든 parser/IMS/fine-notice 요청에 `X-Ops-Parser-Token` 헤더 추가.
- 변경대상:
  - `lib/shared/config/app_env.dart`
  - parser client provider/생성부 확인 필요
  - client 파일 6개:
    - `reservation_ai_parser_client.dart`
    - `ims_reservation_client.dart`
    - `fine_notice_ai_parser_client.dart`
    - `fine_notice_contract_matching_client.dart`
    - `fine_notice_document_client.dart`
    - `fine_notice_contract_pdf_client.dart`
  - 필요 시 `.env.example` 또는 앱 환경 문서
- 실행방법:
  - token 값은 코드에 하드코딩하지 않는다.
  - request 생성 직후 공통 방식으로 header set.
  - GET download/list에도 동일 헤더 적용.
- 종료조건:
  - 앱의 모든 parser 호출에 token 헤더가 들어간다.
  - token 없는 설정이면 명확한 앱 오류 메시지 또는 설정 실패로 처리한다.
- 검증방법:
  - `flutter analyze`
  - 관련 unit/widget test 가능 범위 실행
  - client 코드 inspection
- 리스크:
  - 앱 env 설정 누락 시 앱 시작/호출 실패.
  - 기존 직원 APK는 새 parser token guard와 호환 안 됨.
- 되돌릴 방법:
  - 앱 client/env diff revert.
- 출력보고: 변경 파일, 헤더 적용 범위, analyze/test 결과.

### Phase 4. 문서 및 운영 반영 준비
- 목적: 운영 token/restart/APK 배포 전 필요한 절차를 잠근다.
- 변경점:
  - README에 경로별 인증 정책 추가.
  - `docs/PHASE/README.md`에 PM 상태 반영.
  - 운영 반영 순서 문서화.
- 변경대상:
  - `reservation_ai_parser/README.md`
  - `docs/PHASE/README.md`
- 실행방법:
  - secret 값은 문서에 기록하지 않는다.
  - 운영 순서:
    1. 앱/env token 준비
    2. 새 APK build/test
    3. parser `.env` token 설정
    4. parser restart
    5. public smoke
    6. 직원 APK 배포
- 종료조건:
  - 운영자가 문서만 보고 반영 순서를 알 수 있다.
- 검증방법:
  - 문서 inspection
  - `git diff --check`
- 리스크:
  - 순서를 틀리면 앱/parser 불일치 장애.
- 되돌릴 방법:
  - 문서 diff revert.
- 출력보고: 운영 반영 체크리스트.

### Phase 5. 운영 env/restart/public smoke 준비 또는 실행
- 목적: 승인된 경우 실제 운영 parser에 token guard를 반영한다.
- 변경점:
  - parser `.env`에 token 추가.
  - 필요 시 앱 env에도 token 추가.
  - parser restart.
  - public smoke.
- 변경대상:
  - protected target: `.env`, launchd/restart, APK build/upload
- 실행방법:
  - 별도 명시 승인 전 미실행.
  - 기존 `.env` 백업/값 보존 확인.
  - `launchctl kickstart -k gui/$(id -u)/ai.otang.reservation-ai-parser` 후보.
- 종료조건:
  - public no-token 요청이 `401`.
  - valid-token 요청이 기존 로직까지 도달.
  - `/health` 정상.
  - homepage HMAC endpoint 기존 차단/허용 동작 유지.
- 검증방법:
  - curl smoke
  - launchctl 상태 확인
  - 앱 최소 parser 기능 smoke
- 리스크:
  - 운영 장애 가능.
  - 구버전 앱 parser 기능 차단.
- 되돌릴 방법:
  - `.env` 백업 복구.
  - 코드 revert 후 restart.
- 출력보고: 반영 여부, smoke 결과, rollback 가능 여부.

### Final Phase. 검수·완료판정·문서 COMPLETE 변경·커밋
- 목적: 구현/검증/문서 정리를 완료하고 커밋 가능 상태로 만든다.
- 변경점:
  - 전체 diff 검수.
  - 테스트 결과 정리.
  - PM 문서를 COMPLETED로 이동/이름 변경.
  - 관련 문서 최신화.
  - 승인 범위에 포함되면 commit.
- 변경대상:
  - `docs/COMPLETED/COMPLETE_20260723_rentcar00_OPS_parser_api_auth_hardening_pm.md`
  - 관련 README/PHASE 문서
- 실행방법:
  - `git status`
  - `git diff --check`
  - 테스트/분석 결과 확인
  - commit은 별도 승인 시에만 수행
- 종료조건:
  - 계획된 phase 완료 여부가 문서와 일치.
  - 완료 문서 경로 확정.
  - 커밋 해시 또는 커밋 제외 사유 기록.
- 검증방법:
  - final smoke/test 결과
  - 문서 경로 확인
- 리스크:
  - 운영 반영 전 코드만 커밋되면 배포 순서 관리 필요.
- 되돌릴 방법:
  - 문서 이동/commit 전 diff revert.
- 출력보고:
  - 완료 phase
  - 변경 파일
  - 검증 결과
  - 완료 문서 경로
  - 커밋 해시 또는 제외 사유

## 6. 승인 및 중단 조건
- 승인 요청 단위:
  - `Phase 1 기준점 점검 승인`
  - `Phase 2 parser token guard 구현 승인`
  - `Phase 3 OPS 앱 헤더 추가 승인`
  - `Phase 4 문서/운영 절차 정리 승인`
  - `Phase 5 운영 env/restart/smoke 승인`
  - `Final COMPLETE 문서 변경 및 commit 승인`
- 중단 조건:
  - token 설정 위치가 불명확.
  - 앱 build/env 흐름이 예상과 다름.
  - 홈페이지 HMAC endpoint가 새 guard에 걸릴 위험 발견.
  - sync worker가 parser를 호출하는 숨은 경로 발견.
  - `.env`, launchd, Cloudflare 등 protected target 수정 필요가 승인 범위를 초과.
  - 운영 장애 가능성이 예상보다 큼.
- protected target 별도 승인 필요 여부:
  - 필요함.
  - `.env`, secret/token, launchd/restart, Cloudflare, APK build/upload, commit은 별도 승인 전 미실행.

## 7. 완료 보고 형식
- 완료 phase:
- 변경 파일:
- 검증 결과:
- 운영 반영 여부:
- 완료 문서 경로:
- 상태/정책문서 업데이트:
- 커밋:
- 남은 리스크:
