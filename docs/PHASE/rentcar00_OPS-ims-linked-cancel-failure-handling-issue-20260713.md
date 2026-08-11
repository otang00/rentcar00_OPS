# IMS 연동 예약취소 실패 처리 이슈 보고서

- 작성일: 2026-07-13
- 프로젝트: rentcar00_OPS
- 분류: Issue / PM 후보
- 상태: 확인 완료, 수정 대기
- 기준 브랜치: `fix/ops-return-complete-end-at`

## 1. 이슈 요약

IMS 연동 예약을 OPS에서 취소할 때 IMS 삭제 API 호출은 유지되어 있으나, IMS 삭제 실패가 응답에 포함되어도 앱/서버 흐름에서 성공 처리될 수 있다.

사장님 운영 기준:
- `external_status = linked`인 예약만 IMS 삭제 시도하는 기준은 맞다.
- IMS 삭제가 실패하면 OPS 내부 예약취소까지 성공 처리하지 않는다.
- 실패 건은 수동처리 대상으로 남기면 된다.

## 2. 확인된 현재 흐름

### OPS 예약취소 조건

IMS 삭제 시도 조건:
- `external_status = linked`
- `deleted_at = null`
- IMS schedule id가 존재하는 예약

이 조건이 아니면 IMS 삭제를 시도하지 않는 것이 현재 운영 기준에 맞다.

### 앱 → parser 요청 스키마

```json
{
  "scheduleId": "4332133",
  "reservationId": "R-..."
}
```

### parser → IMS 삭제 API 요청 스키마

```json
{
  "ids": ["4332133"]
}
```

## 3. 시간 차이 관련 판단

취소 요청 스키마에는 예약시간 값이 들어가지 않는다.

따라서 예약시간 변경 또는 시간 차이 때문에 IMS 삭제 요청이 직접 실패하는 구조는 아니다.
삭제는 시간 매칭이 아니라 저장된 IMS `scheduleId` 단일 기준으로 요청된다.

다만 아래 경우는 별도 확인 대상이다.
- IMS 등록/가져오기 시점에 잘못된 scheduleId가 OPS에 저장됨
- 이후 취소 시 저장된 scheduleId로 삭제 요청
- 기대한 예약과 다른 IMS 일정 삭제를 시도하거나 실패할 수 있음

## 4. 실패 사유 확인 결과

IMS 삭제 API 응답에는 상세 실패 사유 텍스트가 내려오지 않는 것으로 확인했다.
확인 가능한 값은 주로 아래 형태다.

```json
{
  "failed_deletion_schedule_ids": ["4332133"]
}
```

예시 확인 건:
- 장용필 / `scheduleId 4332133`
- IMS 상태: `returned`
- IMS 상세상태: `send_claim`
- 보험/반납완료 상태라 IMS 쪽에서 삭제 불가였을 가능성이 높음

단, `failed_deletion_schedule_ids`에 포함되어도 IMS 조회에서 이미 안 보이는 케이스가 있어 IMS 응답 의미는 완전히 안정적이라고 보기 어렵다.

## 5. 수정 기준

필수 수정 기준:
1. IMS 삭제 응답의 `failed_deletion_schedule_ids`에 요청한 scheduleId가 포함되면 실패로 처리한다.
2. 이 경우 OPS 예약취소 성공 처리 금지.
3. external link를 `deleted`로 바꾸지 않는다.
4. 사용자에게 `IMS 삭제 실패 / 수동처리 필요`로 보여준다.
5. IMS 실패 사유 텍스트는 현재 API에서 제공되지 않으므로 앱에서 임의 사유를 만들지 않는다.

## 6. 리스크

- IMS API가 실패 목록을 주면서도 실제로는 삭제된 케이스가 있을 수 있다.
- 그래도 운영상 더 안전한 기준은 `failed_deletion_schedule_ids` 포함 시 성공 처리 금지다.
- 잘못 성공 처리하면 OPS와 IMS 상태가 벌어지고, 수동처리 타이밍을 놓칠 수 있다.

## 7. 다음 PM 후보

### Phase 1. 실패 판정 강화

목적:
- IMS 삭제 실패 목록을 예약취소 성공 처리와 분리한다.

수정 후보:
- 예약취소 use case / repository / parser response handling 경로
- IMS delete reservation response parser
- 앱 표시 메시지

종료 조건:
- `failed_deletion_schedule_ids`에 요청 scheduleId가 있으면 OPS 취소가 완료 처리되지 않는다.
- external 상태가 `deleted`로 바뀌지 않는다.
- 앱에 수동처리 필요 메시지가 표시된다.

검증:
- mock 또는 fixture로 `failed_deletion_schedule_ids` 포함 응답 테스트
- 정상 삭제 응답 기존 흐름 유지 확인
- linked가 아닌 예약은 IMS 삭제 시도하지 않는 기존 기준 유지 확인

## 8. AI parser live 상태 확인

2026-07-13 19:29 KST 기준 확인:

- LaunchAgent label: `ai.otang.reservation-ai-parser`
- 상태: `running`
- PID: `797`
- 실행 시간: `03-09:34:35`
- 실행 명령: `/opt/homebrew/bin/node src/server.js`
- 작업 경로: `projects/rentcar00_OPS/reservation_ai_parser`
- stdout: `reservation_ai_parser/logs/stdout.log`
- stderr: `reservation_ai_parser/logs/stderr.log`
- last exit code: `(never exited)`

참고:
- 기존 메모의 `ai.otang.telegram-parser-bot` label은 현재 launchctl에서 발견되지 않았다.
- 현재 예약 AI parser로 확인되는 live 서비스는 `ai.otang.reservation-ai-parser`다.
