# rentcar00_OPS 예약 레이어 문서 인덱스 v1

## 1. 문서 목적
이 문서는 `rentcar00_OPS`의 **예약 레이어 전용 문서 인덱스**다.

원칙:
- 이 문서는 예약 처리 레이어만 다룬다.
- 현황판 레이어 문서는 여기서 다루지 않는다.
- 예약 레이어 문서를 볼 때는 이 문서 기준으로 읽는다.

## 2. 예약 레이어 기준 문서
### 1순위. 제품 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-spec.md`
- 역할: 제품 범위, 외부 반영 원칙, 금지 규칙

### 2순위. 예약 레이어 메인 설계
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-design-v1.md`
- 역할: 예약 레이어 화면 구조, 상태 전이, 구현 순서

### 3순위. 예약 레이어 DB 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-supabase-draft-v1.md`
- 역할: 예약 raw / projection / state / action / outbox 구조 초안
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-db-build-order-v1.md`
- 역할: 예약 레이어 DB 생성 순서 및 import 흐름

### 4순위. 예약 레이어 시트 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-sheet-live-mapping-v1.md`
- 역할: `예약` / `일정` 시트 실헤더 및 연결 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-google-sheets-import-runbook-v1.md`
- 역할: read-only inspect / raw import 실행 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-normalization-runbook-v1.md`
- 역할: raw -> projection 정규화 실행 기준

### 5순위. 예약 레이어 작업 준비
- `projects/rentcar00_OPS/docs/rentcar00_OPS-reservation-layer-next-phase-prep-v1.md`
- 역할: 예약 레이어 다음 단계 준비 기록

### 6순위. 공통 규칙
- `projects/rentcar00_OPS/docs/rentcar00_OPS-naming-mapping-rules-v1.md`
- 역할: 공통 네이밍 / 키 규칙

## 3. 예약 레이어 제외 범위
아래 문서는 예약 레이어 문서가 아니다.
- `rentcar00_OPS-status-board-layer-note-v1.md`
- `rentcar00_OPS-status-board-clone-spec-v1.md`
- `rentcar00_OPS-status-board-sheet1-ui-mapping-v1.md`

## 4. 읽는 순서
1. `rentcar00_OPS-current-index-progress.md`
2. `rentcar00_OPS-reservation-layer-index-v1.md`
3. `rentcar00_OPS-reservation-layer-design-v1.md`
4. `rentcar00_OPS-reservation-layer-db-build-order-v1.md`
5. `rentcar00_OPS-reservation-layer-supabase-draft-v1.md`
6. 필요 시 시트/정규화/runbook 문서
