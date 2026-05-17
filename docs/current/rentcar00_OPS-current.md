# rentcar00_OPS Current

## 문서 역할
이 문서는 rentcar00_OPS의 유일한 현재 active 실행 문서다.
현재 실행 중인 작업 1건만 적는다.
완료된 기능과 운영 확인 포인트는 `docs/completed/rentcar00_OPS-completed.md`로 옮긴다.

---

## 현재 active 작업
**b32 실기기 QA 대기**

## 목적
수리중/배차 UX + 예약상세 차량변경 + IMS 차량변경 연동이 포함된 b32 APK를 실기기에 설치해 운영 흐름을 확인한다.

## 현재 기준
- 최신 구현 커밋: `5b33dfc`
- 최신 build number: `32`
- 최신 APK: `rentcar00_ops-app-release-arm64-b32-5b33dfc.apk`
- 업로드 위치: `gdrive:rentcar00_OPS/apk/`
- 완료 기능 인수인계: `docs/completed/rentcar00_OPS-completed.md`
- IMS 차량변경 API 기준: 루트 `IMS_API_MANUAL.md`

## QA 체크리스트
1. 수리중 처리
   - 대기 차량 상세에서 `수리중` 버튼이 보이는지
   - 입고공장 선택/공장추가가 가능한지
   - 수리중 차량이 대기탭에 남고 어둡게/배차불가로 보이는지
   - 수리완료 확인 후 대기중으로 복귀하는지
2. 배차 UX
   - 배차 다이얼로그가 카드 버튼형으로 보이는지
   - 보험/일반/장기 선택 후 수정창이 바로 열리는지
   - 배차지/주차지 빈값, 대여일시 현재시각 기준이 맞는지
3. 예약상세 차량변경
   - 차량검색/선택/확인 다이얼로그가 정상인지
   - OPS 예약시간 중복이면 변경이 차단되는지
   - 변경 성공 시 예약 원장과 연결 배차/반납 일정 차량이 같이 바뀌는지
4. IMS 연동 차량변경
   - IMS active binding 예약에서 IMS 차량변경을 먼저 시도하는지
   - IMS 실패 시 `연동 끊고 원장만 변경` / `변경취소` 분기가 보이는지
   - 실제 운영 예약 변경은 사장님 확인 후 진행한다.

## 검증 완료
- `flutter analyze` 통과
- `flutter test test/ops_input_formatters_test.dart test/ims_reservation_payload_test.dart` 통과
- `npm --prefix reservation_ai_parser run check` 통과
- `flutter build apk --release --target-platform android-arm64` 성공
- `rclone ls gdrive:rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b32-5b33dfc.apk` 확인

## 다음 단계
- 실기기 설치 후 위 QA 체크리스트 확인
- 문제 발견 시 b33 수정 phase로 분리
