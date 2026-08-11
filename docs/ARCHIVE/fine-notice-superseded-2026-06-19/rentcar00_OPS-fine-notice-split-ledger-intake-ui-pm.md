# rentcar00_OPS Fine Notice Split Ledger Intake UI PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료/통행료 원장 intake UI
- Related docs:
  - `docs/PHASE/rentcar00_OPS-fine-notice-intake-policy-and-rollback-pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-gangnam-multi-parser-micro-pm.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
- Current status: Planned
- Approval scope: 문서 작성만 완료. Flutter UI/repository change, DB migration, parser restart, APK build/upload, commit은 별도 승인 필요.

## 목적
과태료 `+` 입력 흐름을 새 정책에 맞춘다.

- 수동 입력은 항상 기본 루트.
- AI parser 성공 시 자동 입력/자동 추가.
- AI parser 실패 시 추출값만 모달에 채우고 수동 입력으로 계속 진행.
- 다중 row 성공 시 각 row를 독립 과태료 원장으로 추가.

## 잠긴 정책
- Manual input:
  - 사용자가 직접 입력 후 저장하면 원장 1건 생성.
- AI parser success:
  - 필수 데이터 충족 시 단일 row는 1건, 다중 row는 row 수만큼 독립 원장 후보/원장 생성.
  - 각 row는 차량 소유 guard를 통과해야 계약검색으로 갈 수 있다.
- AI parser failure:
  - 필수 데이터 부족이면 `parse_failed`.
  - 읽힌 값은 모달에 채운다.
  - 자동 원장 추가는 하지 않는다.
  - 사용자는 같은 모달에서 수동 입력/수정 후 저장한다.

## 필수 데이터 계약
자동 추가가 가능한 최소 조건:
- `noticeProfile`
- `noticeType`
- `carNumber`
- row별 `occurredAt` 또는 `passAt`
- row별 `amount` 또는 전체/row 금액이 명확해야 함
- 다중 row면 `items.length >= 2`이고 각 row 날짜/금액/순서가 있어야 함

자동 추가 실패 조건:
- 차량번호 없음
- row 날짜 없음
- 다중 row 수가 불안정
- row 금액/장소/날짜가 섞임
- parser warnings에 `invalid_model_json`, `rowDate_missing`, `occurredAt_missing` 등 핵심 경고 포함

## Phase 1. Data Contract and Mapping
- 목적: parser 결과를 단일/다중 원장 draft로 변환하는 규칙을 만든다.
- 수정/작업 대상:
  - `lib/features/fines/domain/fine_notice_models.dart`
  - `lib/features/fines/presentation/fine_notice_page.dart`
  - 필요 시 parser result model
- 실행 방법:
  - parser `rawCandidate.items[]`가 2개 이상이면 row별 draft list로 변환.
  - row가 없으면 기존 단일 draft 변환 유지.
  - 필수 데이터 부족이면 `parse_failed`로 판정하고 단일 모달 prefilling만 한다.
- 종료 조건:
  - 단일/다중/실패 판정 규칙이 코드로 분리된다.
- 검증 방법:
  - Flutter unit/widget test 추가 또는 기존 테스트 확장
  - `flutter analyze`
- 리스크:
  - 매핑을 UI 안에 너무 많이 넣으면 복잡해진다.
- 되돌릴 방법:
  - mapping helper/UI 변경 revert.

## Phase 2. AI Success Auto-add Flow
- 목적: AI 성공 결과를 자동 원장 추가 흐름으로 연결한다.
- 수정/작업 대상:
  - `lib/features/fines/presentation/fine_notice_page.dart`
  - `lib/features/fines/data/fine_notice_repository.dart`
- 실행 방법:
  - AI parser 성공/단일: 현재 모달에 입력 후 저장 또는 바로 저장 정책 중 하나로 구현.
  - AI parser 성공/다중: row별 draft를 저장하고 “N건 추가됨” 메시지 표시.
  - 각 저장 전 차량 소유 guard 적용.
- 종료 조건:
  - 강남순환도로 4건 parser 성공 결과가 4개 원장 draft/row로 변환된다.
- 검증 방법:
  - mocked parser result test
  - `flutter analyze`
  - `flutter test`
- 리스크:
  - 자동 저장이 너무 빠르면 사용자가 확인할 틈이 없다.
- 되돌릴 방법:
  - 자동 추가를 비활성화하고 수동 모달 prefilling으로 fallback.

## Phase 3. AI Failure Prefill Manual Flow
- 목적: parser 실패 시에도 사용자가 계속 수동 입력할 수 있게 한다.
- 수정/작업 대상:
  - `lib/features/fines/presentation/fine_notice_page.dart`
- 실행 방법:
  - `parse_failed`면 가능한 값만 모달에 채운다.
  - 메시지: `파싱 실패: 확인 후 수동 입력으로 저장하세요.`
  - 저장 버튼은 기존 수동 저장 루트를 사용한다.
- 종료 조건:
  - 필수 데이터 부족 결과가 자동 저장되지 않고 모달에 남는다.
- 검증 방법:
  - mocked missing-date result
  - `flutter analyze`
  - `flutter test`
- 리스크:
  - 실패와 성공 메시지가 헷갈리면 사용자가 자동 처리된 것으로 오해할 수 있다.
- 되돌릴 방법:
  - parser 실패 시 기존처럼 경고만 표시하도록 revert.

## Phase 4. DB/Batch Need Review
- 목적: 지금 테이블로 다중 row 저장이 가능한지, batch key가 즉시 필요한지 판단한다.
- 수정/작업 대상:
  - docs only unless 별도 승인
  - `supabase/migrations/*`는 이 phase에서는 금지
- 실행 방법:
  - 현재 `rc00_ops_fine_notices`에 각 row를 독립 저장 가능한지 확인.
  - 같은 사진에서 나온 row들을 묶을 최소 메타가 필요한지 검토.
  - 필요 시 별도 DB migration PM으로 분리.
- 종료 조건:
  - “DB 변경 없음으로 MVP 가능” 또는 “batch field migration 필요” 둘 중 하나로 결정.
- 검증 방법:
  - schema/repository review
  - 문서 review
- 리스크:
  - batch를 미리 안 두면 나중에 묶음 제출 추적이 불편할 수 있다.
- 되돌릴 방법:
  - 문서 결정 revert.

## Phase 5. Verification and Release Prep
- 목적: 실기기 APK 전에 최소 검증을 닫는다.
- 수정/작업 대상:
  - tests/docs
- 실행 방법:
  - analyzer/test
  - 강남순환도로 mocked 다중 result -> 4건 draft/add 검증
  - parser failure -> manual prefill 검증
- 종료 조건:
  - APK 빌드 후보로 올릴 수 있는 상태.
- 검증 방법:
  - `flutter analyze`
  - `flutter test`
  - parser smoke는 이미 micro PM 5/5 기준 사용
- 리스크:
  - 실제 카메라/갤러리 흐름은 실기기에서만 확인 가능.
- 되돌릴 방법:
  - feature hide 또는 자동 추가만 비활성화.

## 중단 조건
- 자동 저장 전에 사용자가 확인해야 한다는 요구로 정책이 바뀐다.
- 현 DB로 row별 원장 저장이 불가능하다.
- 차량 소유 guard와 다중 저장이 충돌한다.
- parser 성공/실패 판정이 UI에서 명확히 분리되지 않는다.

## 승인 요청
- `pa 1`: data contract/mapping만 구현
- `pa 1-3`: 수동/AI 성공/AI 실패 intake UI 핵심 구현
- `pa all`: DB/batch 검토와 검증까지 진행
