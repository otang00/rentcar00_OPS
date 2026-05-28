# rentcar00_OPS Google Sheets Live Mapping v1

## 상태
- 실제 시트 inspect 실행 완료
- 서비스계정 read-only 접근 확인 완료

## 대상
- spreadsheet id: `1sEHaOI-zrLNzlGC8IdogQ3CidKuL4R_vFGGvFnGyGWk`
- spreadsheet title: `차량현황`
- 시트명:
  - `예약`
  - `일정`

## 실제 헤더
### 예약
- `예약ID`
- `예약번호`
- `차량번호`
- `차종`
- `대여일`
- `반납일`
- `배반차위치`
- `임차인`
- `고객번호`
- `생년월일`
- `소개처`
- `결제금액`
- `예약상태`

### 일정
- `일정번호`
- `예약번호`
- `차량번호`
- `Status`
- `Date`
- `차종`
- `위치`
- `상세정보`
- `가반납`
- `예약ID`
- `일정완료`

## 샘플 관찰
### 예약
- `대여일`, `반납일` 형식은 `2026-03-19 0:00:00` 형태 확인
- `예약취소` 행은 예약번호/고객정보가 많이 비어 있음
- `차종`, `배반차위치`, `임차인`, `고객번호` 공란 행 존재
- `예약ID` 는 안정적으로 채워진 편으로 보임

### 일정
- 현재 샘플 row 수가 적고 중간 blank row 가 섞여 있음
- `Date` 형식은 `2026/05/24, 10:00` 형태 확인
- `상세정보` 는 긴 메시지 원문이 들어가 있음
- `예약ID`, `예약번호` 공란 행이 존재함
- `Status` 는 `반납` 값 확인

## raw import 우선 규칙
- `예약` 시트는 header + blank row 제외 후 전행 적재
- `일정` 시트는 완전 blank row 제외 후 적재
- 원문 payload 는 전체 json 으로 보존
- row number 는 시트 실제 행 번호 기준 저장

## projection 연결 우선 규칙
1. `예약ID`
2. `예약번호` unique
3. 그 외는 orphan raw 유지
