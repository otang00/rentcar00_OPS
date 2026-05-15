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

## 리스크
- `test001 / test001` 은 테스트용 약한 비밀번호라 운영 전 변경이 필요하다.
- `rentcar00`, `rentcar0079` 는 현재 같은 비밀번호를 쓰므로 장기 운영 전 분리 권장.
- APK 파일명 sha 는 커밋 전 HEAD `594d9bf` 기준 빌드명이다.
- build number 는 기존 `+19` 유지라 재설치 기준이다.

## 종료 조건
- 실기기 로그인/로그아웃/세션 유지 검증 완료
- 로그인 후 기존 현황판/예약 주요 화면 진입 확인
- 필요 시 비밀번호 정리 여부 결정
