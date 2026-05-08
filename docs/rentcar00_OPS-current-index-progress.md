# rentcar00_OPS Current Index + Progress

## 0. 최상위 작업 규칙
- 앞으로 `rentcar00_OPS` 작업은 **무조건 이 문서를 먼저 기준으로 시작**한다.
- 작업 전에는 이 문서에서
  - 현재 확정 사항
  - 남은 운영 확인 사항
  - 다음 작업 순서
  를 먼저 확인한다.
- 실제 제작/설계/정리 작업은 이 문서가 가리키는 기준 문서를 따라 진행한다.
- 작업이 끝나면 **반드시 이 문서를 마지막에 업데이트**한다.
- 즉, 작업 순서는 항상 아래로 고정한다.
  1. 이 문서 확인
  2. 기준 문서 확인
  3. 작업 진행
  4. 기준 문서 반영
  5. 이 문서 업데이트
  6. 종료
- archive 문서는 참고만 하고, 현재 기준 판단은 이 문서와 이 문서가 지정한 기준 문서로만 한다.

## 1. 문서 목적
이 문서는 `rentcar00_OPS`의 **현재 기준 문서 목차 + 진행상태판**이다.

이 문서 하나로 아래를 바로 확인한다.
- 어디 문서를 기준으로 봐야 하는지
- 지금 무엇이 확정됐는지
- 남은 운영 확인이 무엇인지
- 지금 바로 제작 가능한 범위가 어디까지인지

원칙:
- 실제 결정 내용은 원문 기준 문서에 반영한다.
- 이 문서는 요약, 우선순위, 진행상태만 관리한다.
- archive 문서는 기준 문서가 아니라 참고 문서다.

---

## 2. 현재 기준 문서 우선순위
### 1순위. 제품 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-spec.md`
- 역할: 제품 범위, 상태 흐름, 카드 최소 기준, 탭 전이 기준, 외부 반영 원칙

### 2순위. 메인 제작 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-design-v1.md`
- 역할: 실제 제작 기준 문서
- 포함: 현재 phase, 화면 구조, 상태 전이 설명, 카드 기준, 구현 우선순위

### 3순위. DB 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-supabase-draft-v1.md`
- 역할: raw / projection / reservation_states / action_logs / outbox 구조 초안

### 4순위. 네이밍 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-naming-mapping-rules-v1.md`
- 역할: `rc00_ops_*` 키 체계, 시트 매핑 어휘, status/action/check 규칙

### 5순위. 진행 체크
- `tasks/rentcar00_OPS-master-checklist.md`
- `tasks/rentcar00_OPS-design-checklist.md`
- 역할: 확정/미확정 항목 체크용

---

## 3. 참고 문서
### archive 참고
- `projects/rentcar00_OPS/docs/archive/consolidated-2026-05-06/rentcar00_OPS-tab-function-list-v1.md`
  - 탭별 기능 정리 원본 참고
- `projects/rentcar00_OPS/docs/archive/consolidated-2026-05-06/rentcar00_OPS-page-design-prep-v1.md`
  - 초기 탭 중심 설계 메모 참고
- `projects/rentcar00_OPS/docs/archive/consolidated-2026-05-06/rentcar00_OPS-implementation-plan.md`
  - 초기 구현 순서 참고

원칙:
- archive는 기준이 아니다.
- 현재 기준은 반드시 `spec / design-v1 / supabase-draft / naming-rules`에 반영된 내용만 인정한다.

---

## 4. 현재 확정된 것
### 제품/구조
- 원본 source는 Google Sheets `예약` + `일정`
- 앱은 Flutter 기반 Android 우선
- AppSheet는 조회용 유지, OPS 앱은 처리용
- 메인 구조는 예약 상태별 탭 리스트
- 메인 탭 5개 고정
  - 예약중
  - 오늘배차
  - 배차중
  - 반납일
  - 완료

### 데이터/식별 기준
- 메인 연결키: `reservation_id`
- 표시/검색용 보조키: `reservation_number`
- 차량 연결 기준: `car_number`
- 상태 source of truth: `rc00_ops_reservation_states`
- 현재 체크값 저장: `check_payload_json`
- `check_payload_json` 키 규칙: `snake_case`

### 키 체계
- 탭 키: `rc00_ops_tab_*`
- 액션 키: `rc00_ops_action_*`
- 체크 키: `rc00_ops_check_*`
- 상태 키: `rc00_ops_status_*`

### 전이 기준
- 예약중 → 오늘배차: `start_at` 날짜가 오늘
- 오늘배차 → 배차중: 실제 출발 확인값
- 배차중 → 반납일: `end_at` 날짜의 00:00
- 반납일 → 완료: `rc00_ops_action_complete_return`
- 완료 → 기본 목록 제외: 반납완료 후 7일

보조 규칙:
- 오늘배차는 준비 미완료여도 진입 막지 않음
- 오늘배차 준비 미완료는 주황 경고
- 배차중 반납 하루 전은 노랑 경고
- `request_delivery` 실행만으로 배차중 전이하지 않음

### 카드 최소 기준
공통 최소 필드:
- 고객명
- 차량번호
- 일정 기준 시각 1개
- 위치 요약
- 핵심 경고 배지 1~2개

탭별 기준 시각:
- 예약중: `start_at`
- 오늘배차: `start_at`
- 배차중: `end_at`
- 반납일: `end_at`
- 완료: `completed_at` 우선, 없으면 `end_at`

탭별 핵심 배지:
- 예약중: 신분증 미확보 / 주소 미확보
- 오늘배차: 준비 미완료 / 탁송·계약·서명 미완료
- 배차중: 반납 임박 / 연장·이슈
- 반납일: 반납완료 직전 미처리
- 완료: 특이사항

### 외부 반영 원칙
- OPS 앱은 AppSheet API 직접 호출 안 함
- 외부 반영은 Google Sheets 수정 기반
- 실제 시트 write는 최종 phase 전까지 금지
- 초기 단계는 read-only + 내부 상태 저장 + outbox dry-run까지만 허용
- MVP outbox 생성 대상은 4개만 고정
  - `request_delivery`
  - `change_end_at`
  - `change_dropoff_address`
  - `complete_return`

### 구현 구조 고정
- 라우팅: `go_router`
- 상태관리: `flutter_riverpod`
- 상세 화면: 공용 1개
- 탭 계산 source of truth: `rc00_ops_reservation_states`
- 예약 원장 생성 기준: `예약` 탭 only
- 일정 연결 우선순위: `reservation_id` → `reservation_number` unique → orphan raw

---

## 5. 아직 미확정
### MVP 핵심 설계 미확정
- 없음

### 운영/실사 확인 필요
- AppSheet virtual column 실제 식
- 실제 시트 target column 최종명
- 운영 테스트용 API read/write 계약

---

## 6. 현재 진행 상태
현재 phase:
- **Phase 2 제작 준비 완료 단계**

지금 상태 판단:
- MVP 핵심 설계 잠금 완료
- 바로 제작 들어가도 되는 기준 문서 세트 확보
- 운영 실사 항목만 후순위 확인으로 남김

### 지금 바로 가능한 것
- Flutter 앱 골격
- 5탭 네비 구조
- 공용 상세 화면 레이아웃
- action/check/status/tab key 상수
- 실제 자동 탭 분류 로직 구현
- 액션 후 status 변경 로직 구현
- outbound dry-run 생성 구현
- Supabase 스키마 / repository 뼈대 구현

### 아직 보류할 것
- 실제 Google Sheets write
- 운영 실계정 대상 AppSheet/시트 반영 테스트
- 마지막 phase 외부 apply

---

## 7. 다음 작업 순서
1. Flutter 프로젝트 뼈대 생성
2. Supabase 스키마 / 모델 / repository 뼈대 작성
3. 탭 리스트 + 공용 상세 UI 구현
4. 액션 / 체크 / status 로직 연결
5. outbox dry-run / sync 화면 연결

원칙:
- 제작은 이 문서 기준으로 진행한다.
- 작업 종료 직전에 기준 문서와 이 문서를 함께 갱신한다.
- 실제 시트 write는 마지막 phase 별도 승인 전까지 금지한다.

---

## 8. 지금 읽는 순서
다음에 다시 볼 때는 아래 순서로 읽는다.

1. 이 문서
2. `rentcar00_OPS-design-v1.md`
3. `rentcar00_OPS-spec.md`
4. `rentcar00_OPS-supabase-draft-v1.md`
5. `rentcar00_OPS-naming-mapping-rules-v1.md`
6. 필요 시 checklist / archive 참고

---

## 9. 마지막 메모
이 문서는 `rentcar00_OPS`의 현재 허브 문서다.
앞으로는 문서 위치를 헷갈리면 먼저 이 문서를 본다.