# rentcar00_OPS Current Snapshot Archive

원본 파일: `docs/rentcar00_OPS-current.md`
아카이브 시각: 2026-05-14 KST
사유: IMS 예약추가 1차 구현과 검증이 완료되어 current 문서를 다음 작업 기준으로 교체한다.

---

# rentcar00_OPS Current

## 1. 현재 작업
예약 원장 형식 잠금 + IMS 예약추가 구조 설계.

## 2. 현재 범위
- Phase 3. AI파서 후처리 보강 완료
- Phase 4. IMS projection / memo builder 준비 코드 반영 완료
- Phase 5. 서버측 IMS endpoint 초안 반영 완료
- Phase 6. 예약생성 IMS 체크 UI 연결 완료
- Phase 7. 성공/실패 확인줄 연결 완료
- Phase 8. IMS dry-run 호출 검증 완료
- Phase 9. IMS 실제 저장 후 즉시 삭제 검증 완료
- Phase 10. 예약 상세/원장 독립 `IMS 예약추가` 액션 연결 완료

## 3. 오늘 잠금 스냅샷 (2026-05-13 23:54 KST)
- IMS 예약추가는 **파싱 기능의 부속이 아니라 원장 기반 독립 기능**으로 본다.
- 예약생성에서 IMS 체크를 켜더라도 순서는 **내부 예약 생성 후 IMS 전송**이다.
- 나중에 예약 상세/원장에서도 **파싱 없이 IMS 예약추가만 따로 실행**할 수 있어야 한다.
- 기존 `parser.00rentcar.com` 터널은 재사용 가능하되, 현재는 파서용 API만 열려 있으므로 IMS 실행 endpoint 추가 설계가 필요하다.
- IMS 메모는 길이 제한 리스크가 있으므로 **원장 메모 전체 저장**과 **IMS용 축약 메모 생성**을 분리한다.

## 4. 현재 잠긴 구조
### 4-1. 책임 분리
1. 파싱 계층
- 원문 텍스트 → 예약 폼 자동채움
- IMS 전송 책임 없음

2. 원장 계층
- 예약 저장/수정/조회 기준
- IMS 전송의 source of truth

3. IMS projection / 전송 계층
- 원장에서 IMS payload 생성
- 파싱 없이도 독립 실행 가능

### 4-2. 실행 순서
- 체크 OFF:
  1. 내부 예약 생성
- 체크 ON:
  1. 내부 예약 생성
  2. IMS payload 생성
  3. IMS 전송
  4. 성공/실패 확인줄 표시

## 5. 형식 잠금 핵심
### 원장 저장 기준
- 생년월일: `YYYY-MM-DD`
- 전화번호: 숫자만 저장
- 금액: 숫자만 저장
- 배차일시/반납일시: 내부 `DateTime` 기준
- 주소 기준: 배차지 단일
- AI파서 사용 시 원장 메모에는 **원문 전체 저장**

### IMS 전송 기준
- `address = pickupLocation`
- `useDelivery = true`
- 생년월일은 원장 필수값으로 유지
- IMS 메모는 원장 메모 전체가 아니라 **별도 builder 로 축약 생성**

## 6. 현재 완료 상태
- main / current / roadmap 문서 역할 분리 완료
- 원장 canonical schema 저장 형식 잠금 완료
- AI파서 사용 시 원문 전체 메모 저장 반영 완료
- 6자리 생년월일 / 전화번호 / 금액 저장 정규화 반영 완료
- 원장 → IMS payload mapper / compact memo / preflight validation 반영 완료
- 파서 서버 `POST /ims/create-reservation` endpoint 반영 완료
- 운영 43110 기준 IMS dry-run 검증 완료
- 실제 차량번호(`101호4701`) 기준 IMS 저장 → 삭제 → 재확인 완료
- 예약 상세 화면 `IMS 예약추가` 버튼 반영 완료

## 7. 다음 단계 미리보기
- 현황판 차량 상태별 액션 분기 설계
- 대기 차량 배차 액션 정리
- 보험/장기/일반 반납 버튼 및 상태 초기화 구현
