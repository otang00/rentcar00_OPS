# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **현재 실행 문서**다.
지금 실제로 실행 중인 작업 1건만 적는다.

## 현재 실행 작업
- 코드/데이터 기준 작업은 일단락됐다.
- 다음 active 는 **실기기 설치 후 운영 확인과 후속 미세조정**이다.

## 목적
- latest raw import 재구성 결과가 실제 운영 화면에서 문제없는지 확인한다.
- 현황판 / 일정 / 예약 상세 흐름에서 사용상 걸리는 지점을 다음 수정 phase 후보로 모은다.

## 기준점
- latest normalized run id: `fff8bdc5-f2ef-46e9-9f27-6908e485edf1`
- latest commit: `9c718f8`
- latest uploaded apk:
  - `gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b19-9c718f8.apk`

## 확인 대상
1. 현황판 5탭 분류
2. 일정탭 `기타` 표시와 수정 동작
3. 대기 차량 주차지 선택/직접추가 동작
4. 예약 상세 / 일정 상세 연결
5. 반납/일정완료 후 화면 재반영 체감

## 리스크
- 차량 raw 반납일 공란/역전값은 이번 phase에서 보정하지 않고 그대로 반영했다.
- 예약 미연결 일정은 의도적으로 유지했다.
- build number 는 여전히 `+19` 기준이라 재설치 전제다.

## 종료 조건
- 실기기 확인에서 치명 오류 없음
- 다음 수정 필요사항이 있으면 1건 active 작업으로 다시 current 에 잠근다.

## 상태
- 문서/코드/빌드 기준 정리 완료
- 지금은 다음 운영 확인 phase 대기 상태
