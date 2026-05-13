# rentcar00_OPS IMS Roadmap Archive

원본 파일: `docs/rentcar00_OPS-ims-roadmap.md`
아카이브 시각: 2026-05-14 KST
사유: IMS 예약추가 1차 구현, dry-run, 실저장/삭제 검증, 예약 상세 독립 액션까지 완료되어 root roadmap 에서 archive 로 이동한다.

---

# rentcar00_OPS IMS Roadmap

## 1. 문서 역할
이 문서는 `rentcar00_OPS`의 IMS 예약추가 구조와 실행 로드맵을 잠그는 기준 문서다.
실구현 전에 형식, 변환 규칙, phase, 리스크를 먼저 확정한다.

## 2. 목표
- 예약생성에서 IMS 체크 시 내부 예약 생성 후 IMS 예약추가까지 안전하게 연결한다.
- 예약 상세/원장에서 나중에 `IMS 예약추가`를 독립 실행 가능하게 만든다.
- 파싱 여부와 무관하게 원장 데이터만으로 IMS payload 를 결정적으로 생성하게 만든다.

## 3. 구조 원칙
### 3-1. 계층 분리
1. 파싱 계층
- 원문 → 폼 자동채움
- 원장 저장 전 입력 보조 역할만 한다.

2. 원장 계층
- 앱의 canonical source of truth
- 수기입력 / AI파서입력 모두 같은 형식으로 저장한다.

3. IMS projection 계층
- 원장 데이터를 IMS 입력 구조로 변환한다.
- 길이 제한, 형식 보정, 누락 검사는 여기서 맡는다.

4. IMS 실행 계층
- 서버측 endpoint 가 IMS Playwright 스크립트를 호출한다.
- 앱은 IMS 사이트를 직접 다루지 않는다.

### 3-2. 실행 순서
- 예약생성 + IMS 체크 ON:
  1. 원장 저장
  2. IMS payload 생성
  3. preflight validation
  4. IMS 실행
  5. 사용자 확인줄 표시

- 예약 상세 / 원장 액션:
  1. 저장된 원장 로드
  2. IMS payload 생성
  3. preflight validation
  4. IMS 실행
  5. 결과 표시

## 4. Phase 1 잠금: 기준 문서 구조
### 남길 현재 문서
- `docs/rentcar00_OPS-main.md`
- `docs/rentcar00_OPS-current.md`
- `docs/rentcar00_OPS-ims-roadmap.md`

### archive 원칙
- 이전 current 성격 문서는 archive 로 이동한다.
- current 에는 지금 진행하는 한 작업만 남긴다.
- 폐기안/과거 탐색안은 current 에 두지 않는다.

## 5. Phase 2 잠금: 원장 canonical schema
### 5-1. 필수 필드
| 필드 | 의미 | 저장 형식 | 비고 |
|---|---|---|---|
| `reservationNumber` | 예약번호 | trim string | 외부/운영 식별용 |
| `customerName` | 고객명 | trim string | 필수 |
| `customerPhone` | 고객 연락처 | digits only string | 하이픈 제거 |
| `customerBirthDate` | 생년월일 | `YYYY-MM-DD` | 원장 필수 유지 |
| `paymentAmount` | 결제/예약 금액 | digits only string | 통화기호/쉼표 제거 |
| `carNumber` | 차량번호 | trim string | 차량 매칭 기준 |
| `carName` | 차량명 | trim string | 원장 유지 |
| `startAt` | 배차일시 | DateTime / ISO 저장 | IMS `rentalAt` 원천 |
| `endAt` | 반납일시 | DateTime / ISO 저장 | IMS `returnAt` 원천 |
| `pickupLocation` | 배차지 | trim string | IMS `address` 원천 |
| `noteText` | 원장 메모 | free text | AI파서 사용 시 원문 전체 저장 |

### 5-2. 선택 필드
| 필드 | 의미 | 저장 형식 | 비고 |
|---|---|---|---|
| `referralSource` | 소개처 | trim string | 운영용 |
| `dropoffLocation` | 반납지 | trim string | 원장엔 유지 가능, IMS 직접 입력은 아님 |

### 5-3. 저장 규칙
- 생년월일은 8자리/구분자 입력을 받아도 저장 전 `YYYY-MM-DD` 로 정규화한다.
- 전화번호는 숫자만 저장한다.
- 금액은 숫자만 저장한다.
- AI파서 사용 시 원장 메모에는 파싱 원문 전체를 저장한다.
- 원장은 IMS 입력 구조와 100% 동일할 필요는 없지만, IMS payload 는 원장에서 항상 같은 규칙으로 생성돼야 한다.

## 6. IMS projection 기준
### 6-1. 기본 매핑
| 원장 필드 | IMS 필드 | 규칙 |
|---|---|---|
| `startAt` | `rentalAt` | `YYYY-MM-DD HH:mm` 또는 서버 표준 포맷으로 출력 |
| `endAt` | `returnAt` | `YYYY-MM-DD HH:mm` 또는 서버 표준 포맷으로 출력 |
| `carNumber` | `carNumber` | 그대로 사용 |
| `paymentAmount` | `totalFee` | digits only |
| `customerName` | `customerName` | 그대로 사용 |
| `customerPhone` | `customerPhone` | digits only |
| `pickupLocation` | `address` | 그대로 사용 |
| fixed | `useDelivery` | 항상 `true` |
| `noteText` + 보조정보 | `memo` | IMS memo builder 가 축약 생성 |

### 6-2. IMS memo 원칙
- 원장 메모 전체를 직접 보내지 않는다.
- 별도 builder 로 길이 제한을 고려한 compact memo 를 생성한다.
- memo builder 는 추후 조정 가능 영역으로 분리한다.
- 최소 포함 후보:
  1. 예약번호
  2. 생년월일
  3. 보험/운전자 등 보조정보
  4. 필요 시 원문 일부 절삭

## 7. preflight validation 기준
IMS 전송 전 아래를 점검한다.
- 필수값 누락 여부
- 생년월일 형식 유효성
- 전화번호 숫자 여부
- 금액 숫자 여부
- 배차/반납일시 역전 여부
- 배차지 존재 여부
- memo 길이 초과 가능성 여부

## 8. 사용자 피드백 기준
- 성공: 초록 확인줄 `IMS 예약성공(차번호, 배차일)`
- 실패: 빨강 확인줄 `IMS 예약실패(실패이유)`
- 내부 예약 저장 성공 / IMS 실패는 분리해서 안내한다.

## 9. 실구현 로드맵
### Phase 1. 기준 문서 잠금
- main/current/roadmap 역할 분리

### Phase 2. 원장 형식 정규화 규칙 잠금
- canonical schema 확정

### Phase 3. AI파서 후처리 보강
- 생년월일 6자리/8자리 정규화
- 전화/금액/일시 정규화
- 원문 전체 메모 저장

### Phase 4. IMS projection / memo builder 구현
- mapper 분리
- compact memo builder 분리

### Phase 5. 서버측 IMS endpoint 구현
- 기존 터널 뒤 서버에 IMS endpoint 추가
- Playwright IMS 스크립트 호출

### Phase 6. 예약생성 UI 연결
- IMS 체크박스 추가
- 생성 후 IMS 실행 분기
- 성공/실패 확인줄 연결

### Phase 7. 예약 상세/원장 독립 액션 확장
- `IMS 예약추가`
- `IMS 재시도`

## 10. 현재 리스크
- IMS memo 길이 제한은 실제 운영 중 다시 조정될 수 있다.
- IMS 입력 DOM/정책이 바뀌면 서버측 실행 계층 보정이 필요하다.
- 원장 형식을 느슨하게 두면 이후 mapper 에서 예외처리가 급증한다.

## 11. 현재 구현 진행 메모
- Phase 1~2 문서 잠금 완료
- Phase 3: AI파서 후처리 보강 반영
  - 6자리 생년월일 정규화
  - 전화/금액 저장 정규화
  - AI파서 사용 시 원문 전체 메모 저장
- Phase 4: IMS payload mapper / compact memo / preflight validation 초안 반영
- Phase 5: 파서 서버 `POST /ims/create-reservation` endpoint 초안 반영
- 완료:
  - 예약생성 IMS 체크 UI 연결
  - 성공/실패 확인줄 연결
  - endpoint 실호출 검증
  - 실제 IMS 저장 후 즉시 삭제 테스트
  - 예약 상세/원장 독립 액션 연결
- 미완료:
  - 현황판 상태별 액션 분기
  - 반납 버튼 및 상태 초기화 액션 연결

## 12. 실구현 진입 기준
아래가 준비되면 UI 연결과 실테스트 단계로 진입 가능으로 본다.
- 문서 기준 확정
- canonical schema 확정
- IMS payload 매핑 확정
- memo builder 분리 원칙 확정
- 예약생성 UX 결과 문구 확정
- IMS endpoint dry-run 확인
