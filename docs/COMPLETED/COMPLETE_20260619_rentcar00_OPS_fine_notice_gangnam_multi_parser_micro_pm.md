# rentcar00_OPS Gangnam Multi-row Fine Notice Parser Micro PM

## Document Metadata
- Created at: 2026-06-19
- Last updated at: 2026-06-19
- Author/agent: Codex
- Related milestone: 과태료/통행료 다중 row 파서 검증
- Related docs:
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_intake_policy_and_rollback_pm.md`
  - `docs/PHASE/rentcar00_OPS-fine-notice-next-operational-phases-pm.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
- Current status: Completed / Go for Gangnam split ledger UI
- Approval scope: `pa 1-2` 승인으로 성공 기준/harness 잠금과 parser prompt/profile 보강까지 진행됨. 이후 `pa` 승인으로 public parser restart와 5-run API validation까지 진행됨. APK build/upload, commit은 별도 승인 필요.

## 목적
강남순환도로 4건짜리 미납통행료 고지서 사진 1장을 기준으로, 다중 row 파서가 앱의 split ledger 저장 단계로 넘어갈 수 있는지 검증한다.

최종 목표는 `1차+필요 시 2차 보강 포함, 새 API 세션 기준 연속 5번 중 5번 성공`이다.

## 기준점
- Fixture image:
  - `fine_notice_ai_parser/src/fixtures/images/gangnam_sunhwan_4rows_20260506_20260512.jpg`
- Expected fixture JSON:
  - `fine_notice_ai_parser/src/fixtures/gangnam_toll_multi.json`
- Current public parser baseline:
  - row count: 4개 인식
  - vehicle: `142호2673` 인식
  - total amount: `7600` 인식
  - row amount/location: 대체로 인식
  - blocker: row별 `occurredAt`이 전부 `null`
  - profile/type drift: `toll_notice` / `unknown_notice`로 나오는 경우 있음
- Current local parser baseline after Phase 2:
  - noticeProfile: `toll_fee.gangnam_sunhwan`
  - noticeType: `toll_fee`
  - vehicle: `142호2673`
  - total amount: `7600`
  - row count: 4개
  - row dates: 4개 모두 인식
  - warnings: `[]`
  - secondPass: not triggered in the local one-shot because first pass completed after prompt hardening
- Current public parser baseline after Phase 3:
  - public parser process restarted
  - `npm --prefix fine_notice_ai_parser run gangnam-multi-smoke`
  - run count: 5
  - passed: 5
  - failed: 0
  - secondPass: not triggered in all 5 runs because first pass completed after prompt hardening
- Current model:
  - `gpt-4.1-mini`

## 성공 조건
각 run은 아래 조건을 모두 만족해야 성공이다.

1. `noticeProfile == toll_fee.gangnam_sunhwan`
2. `noticeType == toll_fee`
3. `issuer == 강남순환도로(주)` 또는 사람이 같은 기관으로 확인 가능한 원문값
4. `carNumber == 142호2673`
5. `totalAmount == 7600`
6. `items.length == 4`
7. 각 row는 위에서 아래 순서대로 유지
8. 각 row는 `occurredAt`, `location`, `amount`가 있어야 함
9. 기대 row:
   - `2026-05-06 09:45:25 / 금천 / 1900`
   - `2026-05-06 15:49:59 / 금천 / 1900`
   - `2026-05-06 15:59:50 / 선암 / 1900`
   - `2026-05-12 13:09:43 / 선암 / 1900`
10. `occurredAt_missing`, `rowDate_missing`, `invalid_model_json` 계열 경고가 없어야 함
11. `dueDate_missing`은 성공/실패 판단에 사용하지 않음
12. parser가 현재 날짜나 임의 연도를 보정하면 실패. 사진에 보이는 값만 써야 함

## 다중 처리 가능 조건
다중 row를 앱에서 원장 여러 건으로 처리하려면 아래 조건이 필요하다.

- row별 날짜가 반드시 있어야 한다.
- row 순서가 고지서 표 순서와 같아야 한다.
- row별 금액과 장소가 서로 섞이면 안 된다.
- 전체 총액은 참고값이고, 계약검색은 row별 `carNumber + occurredAt`로만 진행한다.
- 한 사진에서 나온 row들은 독립 원장이 되지만, 필요하면 나중에 `source_batch_id` 같은 묶음키로 제출만 같이 할 수 있어야 한다.
- 파서 실패 시 앱은 자동 저장하지 않고 row review/manual 입력으로 보내야 한다.

## 1차/2차/수동 전환 정책

### 1차 전체 판독
- 전체 사진 1장을 모델에 보낸다.
- 목적:
  - `noticeProfile`
  - `noticeType`
  - `issuer`
  - `carNumber`
  - `totalAmount`
  - row count
  - row별 `occurredAt/location/amount`
- 1차 결과가 성공 조건을 모두 만족하면 `auto_split_ready`.

### 2차 보강 판독 진입 조건
1차 결과가 아래 조건을 만족하면 2차로 간다.

- 강남순환도로 profile 또는 issuer가 확인된다.
- 차량번호 `142호2673`과 총액 `7600`이 확인된다.
- row count가 4개로 확인된다.
- row별 날짜가 하나라도 빠졌거나, `noticeType/profile`이 alias/drift 상태다.

2차에서는 통행내역 표 영역만 crop/확대해서 다시 읽는다.
2차 prompt는 column을 강제한다:

`번호 / 통행일시 / 통행료 / 부가통행료 / 통행장소`

### 수동 review 전환 조건
아래 중 하나라도 해당하면 자동 split 저장으로 가지 않는다.

- 2차 후에도 row 날짜가 하나라도 없다.
- row count가 4개가 아니다.
- row 순서가 흔들린다.
- row 날짜/장소/금액이 서로 섞인다.
- 차량번호나 총액이 불일치한다.
- 모델이 보이지 않는 날짜/연도를 추정한다.

이 경우 상태는 `manual_row_review_required`로 본다.

## 확인 필요
- 강남순환도로 고지서의 row 날짜 영역을 모델이 안정적으로 읽도록 프롬프트/field hint를 얼마나 구체화할지
- 5회 연속 성공 기준을 public parser로 볼지, local parser로 먼저 볼지
- 이미지 crop/확대 전처리를 parser 내부에서 할지, 모델 프롬프트만으로 먼저 재검증할지

## Phase 1. Success Contract Lock
Status: COMPLETED

- 목적: 5회 연속 성공 판정 기준을 코드/문서에서 동일하게 만든다.
- 수정/작업 대상:
  - `fine_notice_ai_parser/src/fixture-check.js`
  - `fine_notice_ai_parser/src/gangnam-multi-policy-check.js`
  - 필요 시 새 public API harness `fine_notice_ai_parser/src/gangnam-multi-smoke.js`
  - 이 PM 문서
- 실행 방법:
  - 기대값을 hard-coded assertion으로 둔다.
  - 1차 결과가 날짜 누락이면 `second_pass_required`가 나오는지 검증한다.
  - 완전한 결과는 `auto_split_ready`가 나오는지 검증한다.
  - `dueDate`는 raw-only로 두고 성공 조건에서 제외한다.
  - profile/type drift도 실패로 본다.
- 종료 조건:
  - fixture JSON 기준 검증이 통과한다.
  - 분기 정책 harness가 통과한다.
  - 실사진 5-run harness가 어떤 필드를 실패로 보는지 명확하다.
- 검증 방법:
  - `npm --prefix fine_notice_ai_parser run fixture-check`
  - `npm --prefix fine_notice_ai_parser run gangnam-multi-policy-check`
- 리스크:
  - 성공 조건이 너무 느슨하면 잘못된 원장을 만들 수 있다.
- 되돌릴 방법:
  - harness/doc 변경 revert.

## Phase 2. Parser Prompt/Profile Hardening
Status: COMPLETED

- 목적: 강남순환도로 4건 사진에서 row 날짜와 profile/type을 안정적으로 읽고, 필요 시 2차 보강으로 복구하게 한다.
- 수정/작업 대상:
  - `fine_notice_ai_parser/src/parser-core.js`
  - 필요 시 fixture/harness
- 실행 방법:
  - 강남순환도로 profile 규칙을 prompt에 명시한다.
  - 통행내역 표는 `번호 / 통행일시 / 통행료 / 부가통행료 / 통행장소` column으로 읽게 한다.
  - multi-row는 row별 `occurredAt`을 최우선 필드로 요구한다.
  - 날짜가 안 보이면 null + warning으로 둔다. 추정 보정은 금지한다.
  - 1차 결과가 `second_pass_required`이면 표 영역 crop/확대 2차 판독으로 보강한다.
  - 2차 결과는 1차 결과를 덮어쓰는 것이 아니라, 부족한 row 날짜/표 값을 채우는 merge로 처리한다.
  - 모델 응답의 `toll_notice` 같은 alias는 normalize 단계에서 `toll_fee`로 흡수할지 검토한다.
- 종료 조건:
  - public 또는 local real-photo smoke에서 1차 또는 2차 후 4 row 날짜가 모두 채워진다.
- 검증 방법:
  - `npm --prefix fine_notice_ai_parser run check`
  - `npm --prefix fine_notice_ai_parser run gangnam-multi-policy-check`
  - real-photo one-shot smoke
- 리스크:
  - 프롬프트가 특정 사진에 과적합될 수 있다.
  - 다른 고지서 profile에 부작용이 생길 수 있다.
- 되돌릴 방법:
  - prompt/normalizer 변경 revert.

완료 증거:
- `fine_notice_ai_parser/src/parser-core.js` prompt/profile/type normalization 보강.
- local real-photo smoke 결과:
  - `noticeProfile: toll_fee.gangnam_sunhwan`
  - `noticeType: toll_fee`
  - `carNumber: 142호2673`
  - `totalAmount: 7600`
  - `items.length: 4`
  - row dates:
    - `2026-05-06 09:45:25`
    - `2026-05-06 15:49:59`
    - `2026-05-06 15:59:50`
    - `2026-05-12 13:09:43`
  - `warnings: []`
  - `secondPass: null`

주의:
- public parser process는 아직 재시작하지 않았다.
- public 5회 연속 검증은 Phase 3에서 진행한다.

## Phase 3. Five-run New-session Validation
Status: COMPLETED

- 목적: 우연히 한 번 맞춘 결과가 아니라 운영 후보로 볼 수 있는 안정성을 확인한다.
- 수정/작업 대상:
  - 5-run harness script
  - validation log/doc
- 실행 방법:
  - 같은 실사진으로 public parser API를 5회 연속 호출한다.
  - 각 호출은 독립 request로 실행한다.
  - 각 호출은 내부적으로 1차 결과를 먼저 판단하고, 필요하면 2차 보강까지 포함한다.
  - 결과를 JSON summary로 저장/출력한다.
  - 5번 중 1번이라도 최종 결과의 row 날짜/profile/type/금액/row count가 실패하면 Phase 3 실패.
- 종료 조건:
  - 5/5 성공.
- 검증 방법:
  - `npm --prefix fine_notice_ai_parser run gangnam-multi-smoke`
  - 필요 시 public `https://parser.00rentcar.com/parse-fine-notice` 사용
- 리스크:
  - API 비용이 작게 발생한다.
  - public parser restart가 필요할 수 있다.
- 되돌릴 방법:
  - harness/doc 변경 revert. public parser restart는 이전 코드로 재시작.

완료 증거:
- public parser process restarted:
  - service: `reservation_ai_parser`
  - health: `https://parser.00rentcar.com/health`
- `npm --prefix fine_notice_ai_parser run gangnam-multi-smoke` 통과.
- 5회 모두 동일 성공:
  - `noticeProfile: toll_fee.gangnam_sunhwan`
  - `noticeType: toll_fee`
  - `issuer: 강남순환도로(주)`
  - `carNumber: 142호2673`
  - `totalAmount: 7600`
  - `itemCount: 4`
  - row dates:
    - `2026-05-06 09:45:25`
    - `2026-05-06 15:49:59`
    - `2026-05-06 15:59:50`
    - `2026-05-12 13:09:43`
  - locations: `금천 / 금천 / 선암 / 선암`
  - amounts: `1900 / 1900 / 1900 / 1900`
  - warnings: `[]`
  - secondPass: `null`

판정:
- 강남순환도로 4건 fixture는 public parser 기준 5/5 성공.
- 2차 보강 분기는 정책/코드에 남겨두되, 이 샘플은 보강 prompt 이후 1차에서 통과한다.

## Phase 4. Go/No-go Decision
Status: COMPLETED

- 목적: split ledger 저장 UI로 넘어갈지, manual row entry로 막을지 결정한다.
- 수정/작업 대상:
  - `docs/COMPLETED/COMPLETE_20260619_rentcar00_OPS_fine_notice_intake_policy_and_rollback_pm.md`
  - `docs/GOAL/rentcar00_OPS-current.md`
- 실행 방법:
  - 5/5 성공이면 split ledger UI phase로 진입 가능.
  - 5/5 실패이면 강남순환도로 profile은 `manual_row_review_required`로 막는다.
- 종료 조건:
  - Go 또는 No-go가 문서에 명시된다.
- 검증 방법:
  - 문서 review
  - `git diff --check`
- 리스크:
  - 4/5 같은 애매한 결과를 운영 가능으로 착각할 수 있다.
- 되돌릴 방법:
  - decision doc revert.

결정:
- Go.
- 강남순환도로 4건 실사진 기준으로 split ledger UI 진입 가능.
- 근거:
  - public parser 5/5 성공.
  - row별 `occurredAt/location/amount`가 모두 안정적으로 일치.
  - warnings 없음.
- 제한:
  - 이 Go는 강남순환도로 4건 fixture/profile에 한정한다.
  - 다른 profile 또는 다른 다중 고지서는 별도 fixture 검증 전 자동 다중 추가를 열지 않는다.
  - 같은 강남순환도로라도 필수 데이터가 빠지면 `parse_failed`로 보고 수동 입력 모달에 추출값만 채운다.
  - AI 실패는 자동 split 저장 금지이며, 수동 입력 루트로 계속 진행한다.

## 중단 조건
- row 날짜가 5회 중 1회라도 빠진다.
- 4 row가 3/5 row로 줄거나 5 row 이상으로 흔들린다.
- row 날짜/장소/금액이 서로 섞인다.
- 모델이 보이지 않는 날짜/연도를 추정한다.
- public parser에 반영하려면 restart가 필요한데 restart 승인이 없다.

## 완료 예상치
- 이 micro PM 완료 시 다중 고지서 전체 목표의 약 20% 완료.
- 산정 기준:
  - 다중처리의 핵심 blocker는 row-level 날짜 안정성이다.
  - 이 검증은 DB/UI split 구현 전 go/no-go gate다.
  - 제출 묶음/batch, 문서 생성, 계약검색 UI는 별도 phase로 남는다.

## 승인 요청
- Completed. 다음 승인 후보는 split ledger UI/저장 PM이다.
