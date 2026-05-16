# rentcar00_OPS Current

## 문서 역할
이 문서는 `rentcar00_OPS`의 **유일한 현재 active 실행 문서**다.
현재 실행 중인 작업 1건만 적는다.
완료된 기능과 운영 확인 포인트는 `docs/completed/rentcar00_OPS-completed.md`로 옮긴다.

---

## 현재 active 작업
**b30 실기기 QA 대기**

## 목적
최신 APK가 실제 기기에서 입력 UX와 기존 예약/IMS 흐름을 깨지 않는지 확인한다.

## 현재 기준
- 최신 앱 커밋: `78dcd51 Bump Android build number to 30`
- 최신 기능 커밋: `7d2ca93 Improve reservation input formatting`
- 최신 업로드 APK: `rentcar00_ops-app-release-arm64-b30-78dcd51.apk`
- 위치: `gdrive:rentcar00_OPS/apk/`

## 실기기 QA 포인트
1. 예약수정
   - 전화번호 자동 하이픈
   - 생년월일 완성 입력만 저장
   - 날짜만 수정 시 기존 시간 유지
   - 예약 수정 후 연결 일정 동기화 유지
2. 예약생성
   - 전화번호 자동 하이픈
   - 생년월일 자동 하이픈
   - 날짜만 입력 시 `10:00` 저장
   - IMS 체크 시 기존 payload 검증 유지
3. 즉시배차/차량상태 수정
   - 전화번호 자동 하이픈
   - 날짜만 입력 시 `10:00` 저장
   - `배차 보험/일반/장기` 매핑 유지
4. 일정 생성/수정
   - 배차/반납/기타 모두 날짜만 입력 시 `10:00` 저장
   - 일정 수정 후 연결 예약 동기화 유지

## 다음 결정
- 실기기 QA에서 문제가 없으면 이 APK를 현장 테스트 기준으로 둔다.
- 문제가 있으면 입력 formatter UX를 보정하고 b31로 재빌드한다.

## 리스크
- 일시 입력 중 커서 중간 수정 UX는 실기기에서 확인이 필요하다.
- 대표번호 8자리 허용은 내부 저장은 가능하지만 IMS payload는 기존 10~11자리 검증을 유지한다.
