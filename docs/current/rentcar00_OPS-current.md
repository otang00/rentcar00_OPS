# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **현재 실행 문서**다.
지금 실제로 실행 중인 작업 1건만 적는다.

## 현재 실행 작업
- **로그인 1차 도입 후 실기기 검증 대기**

## 목적
- 직원 로그인 1차 도입 APK가 실제 Android 기기에서 정상 동작하는지 확인한다.
- 로그인/로그아웃/세션 유지/본문 차단 흐름을 운영 투입 전 점검한다.

## 기준점
- 로그인 1차 코드 반영 완료
- Supabase remote migration 적용 완료: `20260515111500`
- hosted Auth 공개 signup 차단 완료: `disable_signup=true`
- email 로그인 유지 확인 완료: `external.email=true`
- `flutter analyze` 통과
- arm64 release APK 빌드 및 gdrive 업로드 완료:
  - `gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b19-594d9bf.apk`

## 로그인 계정
- `rentcar00` / `오 태진` / `admin`
- `rentcar0079` / `직원` / `staff`
- `test001` / `직원` / `staff`

## 확인 대상
1. 앱 최초 실행 시 로그인 화면이 먼저 뜨는지
2. `rentcar00` 로그인이 되는지
3. `rentcar0079` 로그인이 되는지
4. `test001` 로그인이 되는지
5. 로그아웃 후 본문 접근이 막히는지
6. 앱 재실행 시 세션이 유지되는지
7. 현황판/예약/상세 화면 데이터가 로그인 후 정상 조회되는지
8. 일정 상세 수정 후 `schedule_at_raw` 가 `YYYY-MM-DD HH:mm:ss` 형식으로 저장되는지
9. 차량 상세/일정 상세의 수정 액션 버튼 크기와 톤이 동일 계열로 보이는지

## 리스크
- `test001 / test001` 은 테스트용 약한 비밀번호라 운영 전 변경이 필요하다.
- `rentcar00`, `rentcar0079` 는 현재 같은 비밀번호를 쓰므로 장기 운영 전 분리 권장.
- APK 파일명 sha 는 커밋 전 HEAD `594d9bf` 기준 빌드명이다.
- build number 는 기존 `+19` 유지라 재설치 기준이다.
- 일정 수정 저장 포맷은 ISO 대신 `YYYY-MM-DD HH:mm:ss` 로 통일했다.
- 기존 ISO 일정 row 1건은 DB에서 보정 완료했다.

## 종료 조건
- 실기기 로그인/로그아웃/세션 유지 검증 완료
- 로그인 후 기존 현황판/예약 주요 화면 진입 확인
- 필요 시 비밀번호 정리 여부 결정


## 2026-05-15 데이터 정책 반영 상태
- 데이터 정책 문서 생성: `docs/current/rentcar00_OPS-data-policy.md`
- canonical 날짜/시간 1차 적용 완료
  - `rc00_ops_schedules.schedule_at timestamptz`
  - `rc00_ops_schedules.schedule_done boolean`
  - `rc00_ops_cars.start_at_ts/end_at_ts timestamptz`
- 앱 일정/차량 날짜 읽기·쓰기 경로를 canonical 컬럼 기준으로 전환
- raw/import drop 은 아직 미진행
- 차량 start date 중 연도 없는 3건은 확인 필요


## 2026-05-15 raw/import drop 완료
- migration: `20260515130000_drop_raw_import_tables.sql`
- 제거: raw/import 테이블 4개 및 source/raw 일정 컬럼
- 제거: Google Sheets raw import/normalize tool
- Sync 화면은 `운영 진단`으로 전환
- 검증: remote migration 적용, raw/import 테이블 REST 404, `flutter analyze`, `git diff --check`
- 남은 확인: 차량 시작일 연도 없는 3건
  - `29하2763` — `11월25일`
  - `34호7488` — `6월12일`
  - `34호7499` — `10월18일`


## 2026-05-15 IMS 체크 예약 생성 잠금 완료
- 차량 상세 `예약생성`에서 IMS 체크 시 원장 insert 전에 payload 검증
- 검증 실패 시 예약/일정 생성 없이 수정 요구
- 예약 상세 IMS 실패 문구도 코드 대신 한글 수정 안내로 변경
- 검증 타입: `rentalAt/returnAt YYYY-MM-DD HH:mm`, 차량번호, 0보다 큰 가격, 고객명, 전화번호 10~11자리, 배차지, 생년월일 실제 날짜, 반납>배차, memo 120자
- 차량 시작일 수동 보정 완료
  - `29하2763` → `2021-11-25 00:00 KST`
  - `34호7488` → `2018-06-12 00:00 KST`
  - `34호7499` → `2017-10-18 00:00 KST`


## 2026-05-15 UI/참조명 정리
- 상단 sync/logout 버튼과 로그인 사용자명 표시 제거
- 예약 탭 상단 제목/설명 문구 제거
- 앱 표시명 `예약번호` 를 `외부예약번호` 로 정리
- 일정 상세 예약 연결은 `예약ID` 를 클릭 기준으로 표시하고 외부예약번호는 참고값으로 분리
- 예약 카드 상단을 `차량번호 / 배차일 / 반납일` 구조로 조정하고 하단 `고객명 / 차종 / 배차지` 유지
- 예약 상세 페이지를 차량상세와 유사한 섹션 카드 구조로 정리
- IMS 체크 예약 생성 필수값: 고객번호, 가격, 생년월일 입력칸 validator 강화


## 2026-05-15 일정 예약 연결 표시 잠금
- 일정 상세의 예약 연결은 실제 예약 원장에 존재하는 `reservation_id` 만 클릭 가능하게 표시한다.
- orphan `reservation_id` 는 `연결된 예약 없음` 으로 표시한다.
- 외부예약번호는 참고값으로 유지한다.
