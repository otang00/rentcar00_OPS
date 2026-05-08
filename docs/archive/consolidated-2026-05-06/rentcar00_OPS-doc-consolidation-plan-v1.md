# rentcar00_OPS 문서 통폐합 준비안 v1

## 1. 목적
기존 문서는 수가 많고, 기준 문서와 중간 메모가 섞여 있다.
이 상태로는 구현 기준이 흔들린다.

이번 통폐합은 아래 **고정 기준**만 남기기 위한 작업이다.
- 원본은 Google Sheets `차량현황`의 `예약` 탭 + `일정` 탭
- 앱 메인 구조는 **예약 상태별 탭 리스트**
- 상세는 메인이 아니라 보조
- 업무 상태/로그는 Supabase 관리
- 최종적으로 시트에는 필요한 상태 체크만 반영
- `ims_sync_reservations`, `booking_orders` 는 이번 앱 기준에서 제외

---

## 2. 통폐합 후 남길 문서
### 2-1. 마스터 기능 문서
`docs/rentcar00_OPS-master-spec.md`

이 문서에는 아래만 넣는다.
- 앱 목적
- 원본 기준
- 탭 구조
- 탭별 리스트 의미
- 탭별 카드에 보여줄 정보
- 탭별 핵심 버튼
- 상태 전이 원칙
- 상세 화면의 보조 역할
- MVP 범위

핵심:
- 이 문서는 **탭 중심 기능 문서**여야 한다.
- 상세 화면 중심 구조로 쓰지 않는다.

### 2-2. 마스터 데이터 문서
`docs/rentcar00_OPS-master-data-design.md`

이 문서에는 아래만 넣는다.
- Google Sheets `예약` 탭 구조
- Google Sheets `일정` 탭 구조
- `예약ID`, `일정번호`, `차량번호` 연결 기준
- Supabase 업무 상태 구조
- 로그 구조
- 시트 상태 체크 반영 원칙
- sync/outbound 원칙

핵심:
- 원본 시트와 업무 DB 역할을 분리해서 적는다.
- 쓰지 않는 기존 예약 테이블 설명은 최소화한다.

### 2-3. 구현 실행 문서
`docs/rentcar00_OPS-implementation-plan.md`

이 문서에는 아래만 넣는다.
- 구현 phase
- 탭별 구현 순서
- 탭별 필요한 데이터
- 탭별 필요한 버튼
- 공통 컴포넌트
- 검증 기준

### 2-4. 마스터 체크리스트
`tasks/rentcar00_OPS-master-checklist.md`

---

## 3. 기존 문서 처리 기준
### 마스터 문서에 흡수 후 정리 대상
- `docs/rentcar00_OPS-spec.md`
- `docs/rentcar00_OPS-design-v1.md`
- `docs/rentcar00_OPS-db-management-v1.md`
- `docs/rentcar00_OPS-sheet-to-supabase-mapping-v1.md`
- `docs/rentcar00_OPS-sync-strategy-v1.md`
- `docs/rentcar00_OPS-concept-schema-v1.md`
- `docs/rentcar00_OPS-supabase-draft-v1.md`

### 참고용으로만 둘 문서
- `docs/rentcar00_OPS-discovery-2026-05-06.md`

---

## 4. 다음 설계 재작성의 고정 순서
이번엔 아래 순서를 바꾸지 않는다.

1. 탭 정의
2. 탭별 리스트 의미
3. 탭별 카드 표시값
4. 탭별 버튼
5. 탭별 상태 전이
6. 공통 로그 규칙
7. 상세 화면 보조 역할
8. 마지막에 데이터/DB 연결

즉,
**상세 화면부터 잡지 않는다.**

---

## 5. 결론
통폐합 목적은 문서를 멋있게 늘리는 게 아니라,
사장님 기준을 흔들지 않는 최소 문서 세트로 줄이는 것이다.

이후 실설계는 반드시
**탭 중심 → 카드/버튼 → 상태 전이 → 보조 상세**
순서로 다시 작성한다.
