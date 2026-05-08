# rentcar00_OPS 설계안 v1

## 1. 문서 역할
이 문서는 `rentcar00_OPS` 제작을 위한 **실행 기준 설계 문서**다.

역할:
- 화면 구조 기준
- 상태 전이 기준
- 내부 저장 책임 기준
- 구현 phase 기준
- 검증 기준

문서 우선순위:
- 제품 범위/원칙은 `rentcar00_OPS-spec.md`
- 이 문서는 실제 제작 순서와 화면/동작 설계를 고정한다.
- DB 구조 세부는 `rentcar00_OPS-supabase-draft-v1.md`
- 네이밍/키 체계는 `rentcar00_OPS-naming-mapping-rules-v1.md`

## 2. 이 문서를 메인 제작 문서로 쓰는 방법
사장님이 실제 제작 진행 상황을 볼 때는 이 문서를 먼저 본다.

사용 원칙:
- 현재 phase 확인
- 현재 잠긴 결정 확인
- 다음 구현 순서 확인
- 세부 규칙이 필요할 때만 참조 문서로 내려간다.

즉,
- `design-v1` = 메인 제작 문서
- `spec` = 제품 기준
- `supabase-draft` = DB 기준
- `naming-rules` = 이름/키 기준

## 3. 참조 문서 목록
### 3-1. 제품 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-spec.md`
- 역할: 범위, 원칙, 금지 규칙, 외부 반영 경계

### 3-2. DB 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-supabase-draft-v1.md`
- 역할: raw / projection / status / logs / outbox 구조

### 3-3. 네이밍 기준
- `projects/rentcar00_OPS/docs/rentcar00_OPS-naming-mapping-rules-v1.md`
- 역할: `rc00_ops_*` 키 체계, 시트 매핑 어휘, 상태/액션/체크 규칙

## 4. 현재 고정 결정사항 요약
- 원본 원장은 Google Sheets `차량현황`의 `예약` + `일정` 탭이다.
- 예약 메인 연결키는 `reservation_id` 다.
- `reservation_number` 는 표시/검색용 보조키다.
- 차량 강한 연결 기준은 `car_number` ↔ `cars.car_number` 다.
- 메인 UI는 `예약중 / 오늘배차 / 배차중 / 반납일 / 완료` 5개 탭이다.
- OPS 앱은 AppSheet API를 직접 호출하지 않는다.
- AppSheet/기존 봇은 시트 변경에 반응하는 후속 자동화 레이어다.
- 업무 상태와 로그의 source of truth 는 Supabase다.
- Supabase 구조는 `예약 원장 / 예약별 상태 / 액션 로그` 3층으로 간다.
- 예약별 상태는 예약 1건당 1행이며 `tab_key`, `status`, 현재 체크값을 가진다.
- 수동 상태가 자동 계산보다 우선한다.
- Google Sheets write는 실운영 트리거이므로 **최종 phase 전까지 금지**한다.
- 초기 단계는 read-only import + 내부 상태 저장 + outbox dry-run까지만 허용한다.

## 5. 현재 phase
현재 기준 phase:
- **Phase 3 앱 골격 완료 / Supabase 연결 준비 단계**

현재 완료:
- 제품 기준 문서 정리
- 설계 문서 정리
- DB 구조 초안 정리
- 네이밍 규칙 정리
- 시트 write 금지 원칙 반영
- 액션 → 체크 → status 표 잠금
- outbound 최소 항목 잠금
- Flutter 제작 구조 잠금
- raw import / 레거시 일정 정규화 규칙 잠금
- Flutter 프로젝트 생성 및 메인 라우팅 구성
- 5탭 메인 구조 / 공용 상세 / Sync / Search 화면 골격 구현
- 메인 카드를 한 줄 중심 얇은 리스트로 축약
- Supabase 프로젝트 생성
- 앱용 공개 env 와 작업용 secret env 분리

현재 진행 대상:
- Flutter dotenv 연결
- Supabase client 초기화
- Supabase CRUD / repository 뼈대 생성
- outbox dry-run 검증 시나리오 정리

## 6. 다음 작업 순서
1. Flutter dotenv 연결
2. Supabase client 초기화 및 연결 검증
3. Supabase 스키마 / repository 뼈대 작성
4. mock repository → Supabase repository 교체
5. read-only sync 화면 / importer 구조 연결
6. 액션 / 체크 / status 로직 연결
7. outbox dry-run 연결
8. 마지막 phase 전까지는 시트 apply 금지 유지

## 7. 업무 흐름 요약
이 앱은 예약 원장을 그대로 보여주는 앱이 아니다.
각 예약이 현재 어느 업무 단계에 있는지 판단하고,
그 단계에서 필요한 액션 버튼을 빠르게 제공해 처리 완료까지 밀어주는 앱이다.

핵심 처리 흐름은 아래와 같다.

1. 예약이 들어오면 `예약중`
2. 배차일이 오늘이 되면 `오늘배차`
3. 실제 출발 확인값이 잡히면 `배차중`
4. 반납일이 오늘이 되면 `반납일`
5. 반납 완료되면 `완료/기록`

즉, 운영자는 “현재 해야 할 버튼”만 보고 누르면 되고,
앱은 그 결과를 기록하고 다음 단계로 넘겨야 한다.

## 8. 지금 단계의 강한 제약
- Google Sheets는 원본이자 실운영 트리거다.
- 따라서 Google Sheets write는 **최종 phase 전까지 금지**한다.
- 초기 제작 단계에서는 read-only import, 내부 상태 저장, outbox dry-run까지만 허용한다.
- AppSheet는 직접 제어 대상이 아니라 시트 변경 반응자다.
- 설계는 AppSheet 복제가 아니라 OPS 앱 자체의 처리 흐름 완성에 집중한다.

## 9. 상태 전이 설명
### 고정 전이 기준
- 예약 생성/동기화 → 예약중
- 예약중 → 오늘배차: `start_at` 날짜가 오늘이면 이동
- 오늘배차 → 배차중: 실제 출발 확인값이 잡히면 이동
- 배차중 → 반납일: `end_at` 날짜가 오늘이 되는 00:00 에 이동
- 반납일 → 완료/기록: `rc00_ops_action_complete_return` 완료 시 이동
- 완료/기록 → 기본 탭 제외: 반납완료 후 7일 경과 시 제외

### 고정 보조 규칙
- 예약중에서 오늘배차로 이동할 때 준비 미완료여도 이동은 막지 않는다.
- 준비 미완료 오늘배차 카드는 주황 경고로 표시한다.
- `rc00_ops_action_request_delivery` 실행만으로는 오늘배차 → 배차중 이동을 만들지 않는다.
- MVP에서는 `rc00_ops_status_dispatch_in_progress` 또는 수동 확인을 실제 출발 확인값으로 본다.
- 반납 하루 전은 배차중 유지 + 노랑 경고로 표시한다.
- 반납일에서 차량 회수 완료 후 반납완료 처리한다.

### 우선순위 원칙
1. 상태테이블의 수동 `tab_key`
2. 상태테이블의 수동 `status`
3. 반납완료 여부
4. 반납일 오늘 여부
5. 실제 출발 확인 여부
6. 배차일 오늘 여부
7. 그 외 준비 상태

### 충돌 처리 원칙
- 날짜 기반 자동 분류와 수동 상태가 충돌하면 수동 상태 우선
- 단, 카드와 상세 화면에 `확인 필요` 경고 표시
- 자동 계산값은 이동 강제가 아니라 추천/경고 계산에만 사용

## 10. 개념 데이터 모델
실제 테이블명은 확정하지 않고, 개념 엔티티만 먼저 고정한다.

### A. 예약 엔티티
역할:
- 예약 1건의 기준 정보와 현재 업무 단계 보유

포함 개념:
- 예약 식별값
- 외부 원장 식별값
- 고객/차량/일정/주소/금액/메모/특이사항
- 현재 업무 상태
- 수동 상태 보정 여부
- 마지막 동기화 시각

### B. 업무 상태 엔티티
역할:
- 예약 1건당 현재 업무 상태 1행 관리

포함 개념:
- `tab_key`
- `status`
- 자동 계산 상태
- 수동 override 상태
- `check_payload_json`
- 긴급/확인 필요 플래그

설계 포인트:
- 초기부터 예약 원장과 상태 레코드를 분리한다.
- 체크 현재값은 개별 컬럼을 미리 넓히지 않고 `check_payload_json` 에 모은다.
- 자주 쓰는 체크만 나중에 실컬럼으로 승격한다.

### C. 업무 로그 엔티티
역할:
- 버튼 실행과 상태 변경의 감사 추적

포함 개념:
- 예약 참조
- 액션 유형
- 실행 전/후 상태
- 실행자 / 실행 시간
- 성공/실패 / 실패 사유
- 생성된 문구 원문
- 외부 연동 응답값

### D. 문자 템플릿 엔티티
역할:
- 템플릿 종류별 기본 문구 및 변수 관리

포함 개념:
- 템플릿 종류
- 활성 여부
- 제목/본문
- 사용 가능한 치환 변수
- 버전 또는 수정일

### E. 외부 연동 상태 엔티티 또는 메타 필드
역할:
- Google Sheets / IMS / 탁송 / 문자 연동 메모 및 상태 관리

포함 개념:
- 연동 대상 종류
- 최근 요청 시각
- 최근 성공 여부
- 실패 메모
- 외부 식별값

## 11. Google Sheets ↔ Supabase 매핑 전략
기준 원본은 Google Sheets `차량현황` 문서의 `예약` 탭 + `일정` 탭이다.
`ims_sync_reservations`, `booking_orders` 는 이번 ops 앱의 기준 원장으로 사용하지 않는다.

구체 컬럼명은 기존 시트를 본 뒤 확정한다.
지금은 아래 원칙으로 설계한다.

### 원칙 1. 원본 보존
- Google Sheets 원본 구조를 직접 변형하지 않음
- `예약` 탭과 `일정` 탭의 원문 의미를 그대로 보존함
- Supabase에는 업무앱용 읽기/처리 기준 구조를 별도로 둠
- 시트에는 최종적으로 필요한 최소 상태 체크만 되돌려 반영하는 방향으로 설계함

### 원칙 2. 식별값 분리
- 기존 시트의 예약 식별값은 외부 원장 키로 보존
- 앱 내부용 고유 식별값은 별도로 둘 수 있게 설계

### 원칙 3. 원장 데이터와 업무 데이터 분리
- 원장에서 오는 값: 고객명, 연락처, 차량, 일정, 주소 등
- 앱에서 누적되는 값은 `예약별 상태 1행 + 액션 로그 다건` 구조로 관리
- 현재 체크값은 상태테이블에 둔다
- 시트로 되돌려 쓰는 값은 세부 로그가 아니라 최소 상태 체크로 제한

### 원칙 4. 동기화 충돌 방지
- 원장에서 바뀌는 값과 앱 내부에서만 바뀌는 값을 분리
- 예: 고객명/일정은 sync 대상, 업무 로그/발송 횟수는 앱 관리 대상

### 원칙 5. 단계별 Sync
MVP 기준 후보:
1. `예약` 탭 + `일정` 탭 수동 import
2. 정해진 시점 수동 sync
3. 추후 스케줄 기반 자동 sync

### 매핑 시 반드시 확인할 것
- 기존 시트의 예약 고유키
- 차량 식별 기준
- 날짜/시간 컬럼 형식
- 배차/반납 주소 분리 여부
- 결제 상태 표현 방식
- 기존 AppSheet 계산 컬럼 존재 여부
- 중복 예약/변경 이력 처리 방식

## 12. 화면 구성안
## 12-1. 앱 구조
- 스플래시 / 초기 동기화 상태
- 메인 탭 화면
- 예약 상세 화면
- 템플릿 미리보기/문자 보내기 진입
- 로그/메모 하위 시트 또는 섹션
- 완료/검색 화면

## 12-2. 메인 탭 화면
탭:
- 예약중
- 오늘배차
- 배차중
- 반납일
- 완료/검색

각 탭 공통:
- 상단 필터 또는 정렬 최소화
- 상태 배지 강조
- 카드 탭 시 상세 이동
- 긴급/확인 필요 상단 우선 노출 가능
- 탭 네비게이션 아래에 탭 요약/카운트 영역을 둔다.
- 카드 상단에는 현재 탭 기준 핵심 경고 1~2개만 우선 노출한다.
- 카드는 한 줄 중심의 얇은 리스트를 기본으로 한다.

카드 공통 최소 필드:
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
- 완료: `completed_at` 이 있으면 우선, 없으면 `end_at`

탭별 핵심 배지 기준:
- 예약중: 신분증 미확보 / 주소 미확보
- 오늘배차: 준비 미완료 / 탁송·계약·서명 미완료
- 배차중: 반납 임박 / 연장·이슈
- 반납일: 반납완료 직전 미처리
- 완료: 특이사항

색상/강조 규칙:
- `오늘배차`에서 준비 미완료 카드는 주황 강조
- `배차중`에서 반납일이 내일인 카드는 노랑 강조
- 액션이 완료된 버튼은 상태색이 바뀌어 재실행 여부를 직관적으로 보여준다.

## 12-3. 예약 상세 화면 섹션
1. 기본 정보 섹션
2. 고객 준비 섹션
3. 계약 섹션
4. 배차 섹션
5. 이용 중 섹션
6. 반납 섹션
7. 업무 로그 섹션
8. 메모 섹션

핵심 원칙:
- 현재 상태에서 필요한 버튼을 상단 또는 고정 액션 영역에 먼저 배치
- 모든 정보를 다 보여주기보다 “지금 필요한 처리”를 우선 배치
- 액션 영역은 상세 상단 배지 아래, 본문 섹션 위에 둔다.
- 체크/완료 상태 영역은 액션 영역 아래에 둔다.

상세 화면 정보 구조:
- 헤더: 고객명 / 차량번호 / 일정 요약 / 현재 탭
- 상태 배지: 확인필요 / 취소 / 완료 / 긴급
- 액션 버튼 묶음: `rc00_ops_action_*`
- 완료 체크 묶음: `rc00_ops_check_*`
- 상태칩: `rc00_ops_status_*`
- 원본 정보: 시트 원문 + 정규화 필드 병행 표시

## 13. 상태별 버튼 설계 원칙
### 예약중
- 연락처 저장
- 신분증/주소 요청 문자
- 신분증 확보 확인
- 주소 확보 확인
- 배차준비완료

### 오늘배차
- 고객에게 전화
- 고객 배차 안내 문자
- 탁송 요청문 생성
- 탁송기사 연락
- 배차계약서 작성
- 고객 차량확인/서명 안내 문자

### 배차중
- 고객에게 전화
- 서명확인
- 반납 전 안내 문자
- 반납 일정 변경
- 긴급출동 안내
- 사고접수

### 반납일
- 반납 안내 문자
- 반납 탁송 요청문 생성
- 반납지 변경
- 연장시 추가요금 안내
- 반납 완료

공통 원칙:
- 버튼은 실행 단위이며 완료 판정과 분리한다.
- 액션 실행 자체는 `rc00_ops_action_*`, 완료 판정은 `rc00_ops_check_*`, 진행 표시는 `rc00_ops_status_*` 로 다룬다.
- 카드/상세는 같은 키 체계를 사용한다.

모든 버튼 공통:
- 실행 전 확인 팝업 가능
- 실행 후 로그 저장
- 상태값 변경
- 실패/취소 시 메모 기록 가능

## 14. MVP 범위 재정리
### 이번 단계에서 구현할 것
- Supabase용 개념 데이터 구조 반영
- 탭별 상태 분류 로직
- 카드 리스트
- 상세 화면
- 상태 버튼
- 문자 템플릿 치환 및 문자앱 열기
- 연락처 저장용 데이터 생성 또는 저장 화면 호출
- 탁송 요청문 생성
- 로그 저장

### 이번 단계에서 구현하지 않을 것
- 실시간 문자 수신 분석
- 자동 카카오 발송
- 실제 IMS API 연동
- 실제 IMS Connect 차량정보 조회
- 실제 시동제어 호출
- 실제 탁송 API 호출
- 관리자용 복합 대시보드

## 15. 탭별 카드/상세 설계 메모
### 8-1. 예약중
카드 핵심:
- 고객명 / 차량번호 / `start_at`
- 위치 요약
- 신분증 미확보 / 주소 미확보

상세 핵심:
- 고객 준비 상태를 상단에서 바로 확인
- 요청 문자와 확인 체크를 분리

### 8-2. 오늘배차
카드 핵심:
- `start_at` / 차량번호 / 위치 요약
- 주황 경고 배지(준비 미완료 시)
- 탁송/계약/서명 관련 핵심 미완료 표시

상세 핵심:
- 전화 → 안내 → 탁송 → 계약/서명 흐름을 위에서 아래로 배치

### 8-3. 배차중
카드 핵심:
- 고객명 / 차량번호 / `end_at`
- 위치 요약
- 노랑 경고 배지(반납일 내일), 연장/이슈 표시

상세 핵심:
- 이용 중 확인, 연장, 긴급/사고 대응을 한 묶음으로 둔다.

### 8-4. 반납일
카드 핵심:
- 고객명 / 차량번호 / `end_at`
- 위치 요약
- 반납완료 직전 핵심 미완료 표시

상세 핵심:
- 반납 안내 → 탁송 → 반납지 변경 → 추가요금 → 반납완료 흐름을 따른다.

### 8-5. 완료
카드 핵심:
- 고객명 / 차량번호 / `completed_at` 우선, 없으면 `end_at`
- 위치 요약
- 특이사항
- 조회 중심으로만 사용한다.

## 16. 추후 연동 포인트
### 9-1. Google Sheets
- import adapter
- sync worker
- 변경분 비교 로직

### 9-2. IMS 계약서
- 계약 상태 조회 adapter
- 계약서 발송 adapter
- 실패 시 수동 fallback

### 9-3. IMS Connect
- 차량 위치 조회 adapter
- 차량 상태 조회 adapter
- 상태 메모 fallback

### 9-4. 문자 발송
- 기본은 문자앱 deep link
- 추후 문자 API provider adapter 추가

### 9-5. 탁송 요청
- MVP는 요청문 생성/복사/공유
- 추후 업체별 adapter 분기 가능

### 9-6. 시동 제어
- 위험 액션 분리
- 이중 확인
- 강한 로그 보존

## 17. 액션 → 체크 → status 고정 표
원칙:
- 버튼 클릭 자체는 `action_key` 다.
- 완료 판정은 `check_key` 다.
- 현재 업무 단계 표현은 `status` 다.
- 한 액션이 바로 탭 전이를 만들지 않는 경우, 체크만 남기고 탭은 유지한다.
- 탭 전이는 `tab_key` 재계산 결과로만 일어난다.

| tab | action_key | check_key | status after action | tab result | note |
|---|---|---|---|---|---|
| 예약중 | `rc00_ops_action_save_customer_phone` | 없음 | 유지 | 유지 | 로그만 남김 |
| 예약중 | `rc00_ops_action_request_id_address` | 없음 | `rc00_ops_status_waiting_for_id` 또는 `rc00_ops_status_waiting_for_address` 유지 | 유지 | 요청 로그만 남김 |
| 예약중 | `rc00_ops_action_check_id` | `rc00_ops_check_id_verified` | 주소 미확보면 `rc00_ops_status_waiting_for_address`, 아니면 `rc00_ops_status_pending` | 유지 | 체크 완료 |
| 예약중 | `rc00_ops_action_check_address` | `rc00_ops_check_address_verified` | 신분증 미확보면 `rc00_ops_status_waiting_for_id`, 아니면 `rc00_ops_status_pending` | 유지 | 체크 완료 |
| 예약중 | `rc00_ops_action_mark_pickup_ready` | `rc00_ops_check_pickup_ready` | `rc00_ops_status_ready` | 유지, 단 오늘이면 오늘배차 재계산 | 예약중 내부 완료 상태 |
| 오늘배차 | `rc00_ops_action_call_customer` | 없음 | 유지 | 유지 | 로그만 남김 |
| 오늘배차 | `rc00_ops_action_send_pickup_notice` | `rc00_ops_check_pickup_notice_sent` | `rc00_ops_status_ready_for_dispatch` 또는 유지 | 유지 | 안내 완료 체크 |
| 오늘배차 | `rc00_ops_action_request_delivery` | `rc00_ops_check_delivery_requested` | `rc00_ops_status_dispatch_prepared` 또는 유지 | 유지 | 요청만으로 배차중 전이 금지 |
| 오늘배차 | `rc00_ops_action_contact_delivery_driver` | 없음 | 유지 | 유지 | 기사 연락 로그 |
| 오늘배차 | `rc00_ops_action_create_contract` | `rc00_ops_check_contract_created` | `rc00_ops_status_dispatch_prepared` 또는 유지 | 유지 | 계약 준비 체크 |
| 오늘배차 | `rc00_ops_action_send_signature_notice` | `rc00_ops_check_signature_notice_sent` | `rc00_ops_status_dispatch_prepared` 또는 유지 | 유지 | 서명 안내 체크 |
| 오늘배차 | `rc00_ops_action_confirm_dispatch_start` | `rc00_ops_check_dispatch_started` | `rc00_ops_status_dispatch_in_progress` | `배차중` 으로 전이 | 실제 출발 확인값 |
| 배차중 | `rc00_ops_action_call_customer` | 없음 | 유지 | 유지 | 로그만 남김 |
| 배차중 | `rc00_ops_action_check_signature` | `rc00_ops_check_signature_verified` | `rc00_ops_status_in_use` | 유지 | 인수/서명 확인 |
| 배차중 | `rc00_ops_action_send_return_notice` | `rc00_ops_check_return_notice_sent` | `rc00_ops_status_return_preparing` | 유지 | 반납 준비 진입 |
| 배차중 | `rc00_ops_action_change_end_at` | `rc00_ops_check_end_at_changed` | `rc00_ops_status_extension_review` | 재계산 | 연장/변경 검토 상태 |
| 배차중 | `rc00_ops_action_send_emergency_notice` | `rc00_ops_check_emergency_notice_sent` | `rc00_ops_status_issue_handling` | 유지 | 긴급 대응 |
| 배차중 | `rc00_ops_action_report_accident` | `rc00_ops_check_accident_reported` | `rc00_ops_status_issue_handling` | 유지 | 사고 대응 |
| 반납일 | `rc00_ops_action_send_return_notice` | `rc00_ops_check_return_notice_sent` | `rc00_ops_status_return_due` | 유지 | 반납 당일 안내 |
| 반납일 | `rc00_ops_action_request_delivery` | `rc00_ops_check_delivery_requested` | `rc00_ops_status_return_in_progress` | 유지 | 회수 탁송 요청 |
| 반납일 | `rc00_ops_action_change_dropoff_address` | `rc00_ops_check_dropoff_address_changed` | `rc00_ops_status_return_in_progress` | 유지 | 반납지 변경 |
| 반납일 | `rc00_ops_action_send_extension_fee_notice` | `rc00_ops_check_extension_fee_notice_sent` | `rc00_ops_status_settlement_needed` | 유지 | 정산 필요 상태 |
| 반납일 | `rc00_ops_action_complete_return` | `rc00_ops_check_return_completed` | `rc00_ops_status_return_completed` | `완료` 로 전이 | 완료 처리 |

고정 규칙:
- `rc00_ops_status_waiting_for_id`, `rc00_ops_status_waiting_for_address`, `rc00_ops_status_ready_for_dispatch` 는 카드 경고/진행 표현용이다.
- `rc00_ops_status_dispatch_in_progress` 와 `rc00_ops_status_return_completed` 만 강한 전이 트리거로 본다.
- 체크가 done 이어도 수동 `rc00_ops_status_hold` 상태면 자동 전이보다 hold 를 우선한다.

## 18. 시트 outbound 최소 반영 항목 잠금
주의:
- 아래는 **MVP 최소 outbound 고정안**이다.
- 실제 apply는 여전히 Phase 5 별도 승인 전까지 금지다.

### 18-1. outbox 생성하는 액션 4개만 고정
| action_key | outbox 생성 | target_sheet | row_key | expected downstream reaction | fallback |
|---|---|---|---|---|---|
| `rc00_ops_action_request_delivery` | 예 | `일정` 우선 | `reservation_id` | 탁송/회수 일정 후속 반응 | apply 실패 시 요청문 공유 + 내부 체크 유지 |
| `rc00_ops_action_change_end_at` | 예 | `예약` + 필요 시 `일정` | `reservation_id` | 반납 일정 재계산/후속 반응 | apply 실패 시 내부 상태 `rc00_ops_status_extension_review` 유지 |
| `rc00_ops_action_change_dropoff_address` | 예 | `예약` 또는 `일정` | `reservation_id` | 반납 위치 후속 반응 | apply 실패 시 내부 메모 + 확인필요 |
| `rc00_ops_action_complete_return` | 예 | `예약` + `일정` | `reservation_id` | 반납완료 후속 반응 / 일정완료 | apply 실패 시 완료탭 이동 금지, `has_issue=true` |

### 18-2. 나머지 액션 고정 원칙
- 나머지 액션은 **내부 로그 + check_payload_json 갱신만** 한다.
- 시트로 보내지 않는다.
- 나중에 운영상 꼭 필요하다고 확인되기 전까지 outbound 범위를 늘리지 않는다.

## 19. Flutter 정보구조 / 라우팅 / 상태관리 고정안
### 19-1. 기술 선택
- 라우팅: `go_router`
- 상태관리: `flutter_riverpod`
- 서버 접근: Supabase client + repository 계층
- 화면 단위 상태는 Riverpod provider, 영속 데이터는 repository 를 거쳐 읽고 쓴다.

### 19-2. 폴더 구조
- `lib/app/`
- `lib/app/router/`
- `lib/features/reservations/`
- `lib/features/reservations/list/`
- `lib/features/reservations/detail/`
- `lib/features/reservations/actions/`
- `lib/features/sync/`
- `lib/data/models/`
- `lib/data/repositories/`
- `lib/data/datasources/supabase/`
- `lib/shared/widgets/`
- `lib/shared/constants/`

### 19-3. 라우트 구조
- `/` : shell + 5탭 메인
- `/reservation/:reservationId` : 예약 상세
- `/search` : 완료/검색
- `/sync` : 수동 sync / dry-run 확인

### 19-4. 화면 구조 고정
- 메인: 탭 + 카드 리스트 + 카운트
- 상세: header / 상태배지 / 액션영역 / 체크영역 / 섹션정보 / 로그 / 메모
- 검색: 완료탭 확장 조회용
- sync: raw import 결과, outbox dry-run 확인용

### 19-5. provider 책임 고정
- `tabListProvider(tabKey)` : 탭 카드 목록
- `reservationDetailProvider(reservationId)` : 상세 데이터
- `reservationActionsProvider(reservationId)` : 액션 실행
- `tabCountsProvider` : 탭 카운트
- `syncRunsProvider` : sync 실행 이력
- `outboxPreviewProvider(reservationId)` : dry-run payload 미리보기

### 19-6. 구현 원칙
- 상세 화면은 탭별로 따로 만들지 않고 **공용 상세 1개** 로 간다.
- 액션 버튼은 탭별 분기 렌더링만 한다.
- 카드 계산 로직은 UI에서 즉흥 계산하지 않고 repository/view 기준으로 읽는다.
- 액션 실행 후에는 `detail + current tab + counts` 만 최소 refresh 한다.

## 20. raw import / 레거시 일정 정규화 규칙 잠금
### 20-1. 예약 원장 생성 기준
- `rc00_ops_reservations` 의 기준 원장은 **무조건 `예약` 탭**이다.
- `일정` 탭만으로 새 예약을 만들지 않는다.
- 예약 탭에 없는 일정 행은 orphan schedule raw 로만 남긴다.

### 20-2. 일정 행 연결 우선순위
1. `reservation_id` direct match
2. `reservation_number` unique match
3. 둘 다 실패하면 orphan

### 20-3. 레거시 일정 행 처리
- `reservation_id` 가 없고 `reservation_number` 도 불명확하면 레거시 메모 일정으로 본다.
- 레거시 메모 일정은 raw 에 저장하되 카드/탭 계산에는 사용하지 않는다.
- 추후 운영 검토가 끝나기 전까지 자동 병합하지 않는다.

### 20-4. 일정 타입 정규화
- `schedule_type_raw` 는 원문 보존
- 내부 계산용 normalized type 은 아래 4개만 사용
  - `pickup`
  - `return`
  - `maintenance`
  - `other`
- 매핑 실패는 `other` 로 둔다.

### 20-5. projection 계산 기준
- 카드 시간 기본값은 예약 원장의 `start_at`, `end_at`
- 일정 탭은 위치 보강, pickup/return 보조 판단, outbox 대상 확인에만 쓴다.
- 일정 raw 가 예약 원장 시간과 충돌하면 예약 원장 값을 우선하고 `has_issue=true` 로 표시한다.

## 21. 구현 우선순위 고정
### Phase 1. 데이터/상태 뼈대
- 예약 개념 모델
- 상태 분류 규칙
- 로그 구조
- 템플릿 구조
- outbox 구조

### Phase 2. UI 뼈대
- 메인 탭
- 카드 리스트
- 공용 상세 화면
- 탭/카운트 provider

### Phase 3. 업무 액션
- 문자 생성
- 상태 체크 버튼
- 탁송 요청문 생성
- 로그 기록
- detail/tab/count refresh

### Phase 4. 데이터 연결
- Supabase CRUD
- 원장 import/sync
- outbox dry-run
- 실행자 기록

### Phase 5. 운영 검증
- 검색/완료 기록
- 충돌 경고
- 에러 처리
- 제한된 테스트 시나리오 검증

## 22. 구현 시 주의점
- 기존 AppSheet의 조회 역할을 침범하지 말 것
- Flutter 앱은 처리 속도와 버튼 흐름이 우선
- 수동 fallback이 항상 가능해야 함
- 중요한 액션은 반드시 로그로 남길 것
- AppSheet virtual column / 계산 로직은 미확인이어도 MVP 규칙은 현재 문서 기준으로 고정한다.
- Google Sheets write는 마지막 phase의 별도 승인 범위로만 수행한다.
- outbox는 초기 단계에서 `generate only`, `apply 금지` 다.

## 23. 현 시점 잠금 결론
- 전이 기준 고정 완료
- 카드 최소 필드 고정 완료
- 액션 → 체크 → status 고정 완료
- outbound 최소 항목 고정 완료
- Flutter 구현 구조 고정 완료
- raw import / 레거시 일정 정규화 규칙 고정 완료
- 따라서 이제 **MVP 제작 착수 가능** 상태로 본다.

## 24. 제작 직전 체크리스트
- 탭 계산 기준이 문서상 고정되었는가
- 액션 / 체크 / 상태 키가 naming rules와 일치하는가
- 카드 필드와 상세 필드가 분리되었는가
- raw / reservation master / reservation state / log / outbox 책임이 분리되었는가
- 시트 write 없이도 핵심 플로우를 검증할 수 있는가
- 실제 시트 apply가 마지막 phase로 격리되어 있는가
