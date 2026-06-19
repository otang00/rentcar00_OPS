# Fine Notice AI Parser - Model Validation

Status: REVIEW
Date: 2026-06-18
Scope: Phase 3 only

## Purpose

과태료/주정차/통행료 고지서 사진 5장을 기준으로 `fine-notice-ai-parser`의 1차 모델 후보를 검증한다.

이번 검증은 앱, DB, IMS, 제출 플로우를 건드리지 않고 사진 1장 API 파싱 가능성과 고지서별 분기 보정점을 확인하는 데 한정한다.

## Model Candidates

1. `gpt-4.1-nano`
   - 최저 비용 후보로 검증.
   - 공식 이미지/비전 문서에서 `gpt-4.1-nano` 계열 image input 비용 계산 대상임을 확인.
2. `gpt-4.1-mini`
   - 기존 `reservation-ai-parser` 기본 모델과 맞는 안정 후보.
   - `reservation_ai_parser/src/parser-core.js`의 기본값과 같은 계열이라 도입 리스크가 낮다.
3. `gpt-4.1`
   - 실운영 안정성 확인을 위한 상위 모델 후보.
   - `gpt-4.1-mini`보다 한 단계 높은 모델로 같은 5장 샘플을 재검증했다.
4. `gpt-5-mini`
   - 5계열 mini 후보.
   - 실운영 안정성 확인을 위해 10회 반복 검증에 포함했다.

## Prompt Contract Used

입력은 고지서 사진 1장, 출력은 JSON 단일 객체로 제한했다.

Required top-level fields:
- `notice_type`
- `issuer`
- `recipient`
- `vehicle_number`
- `notice_number`
- `electronic_payment_number`
- `giro_number`
- `total_amount`
- `due_date`
- `issue_date`
- `period_start`
- `period_end`
- `items[]`
- `routing_hint`
- `warnings[]`
- `confidence`

Required item fields:
- `item_no`
- `occurred_at`
- `amount`
- `base_amount`
- `discount_amount`
- `surcharge_amount`
- `location`
- `violation_detail`
- `law`
- `confidence`

## Sample Baseline

| Sample | Type | Key expected fields |
| --- | --- | --- |
| Photo 1 | 우면산인프라웨이 미납통행료 | 차량 `142호5626`, 금액 `2,500`, 기간 `2026-05-26`, 단일 item |
| Photo 2 | 남동구청 주정차 과태료 | 차량 `101호4703`, 위반 `2026-06-01 11:04:53`, 금액 `32,000`, 납기 `2026-07-08` |
| Photo 3 | 용산구 주정차 과태료 | 차량 `29하2763`, 위반 `2026-05-06 20:22`, 금액 `32,000`, 납기 `2026-06-28` |
| Photo 4 | 서울서초경찰서 속도위반 과태료 | 차량 `142호5684`, 위반 `2026-05-31 14:03`, 금액 `56,000`, 납기 `2026-07-09` |
| Photo 5 | 강남순환도로 미납통행료 | 차량 `142호2673`, 총액 `7,600`, 4개 item 분리 필수 |

## Result Summary

1회 샘플 검증 뒤, 사장님 기준에 맞춰 2026-06-18에 `10/10 full-run pass` 기준으로 재검증했다.

Acceptance rule:
- 모델당 10회 새 API 호출 세트 실행
- 1회 세트는 Photo 1~5 전체 통과가 필요
- 차량번호, 유형, 총액, 납기, item 개수, 핵심 발생일시가 맞아야 pass
- 10회 중 10회 모두 pass해야 운영 기본 모델 후보로 인정
- `gpt-4.1-nano`는 사장님 지시로 반복 테스트에서 제외하고 탈락 처리

| Model | Overall | Vehicle number | Date/time | Amount | Multi-item | Judgment |
| --- | --- | --- | --- | --- | --- | --- |
| `gpt-4.1-nano` | 탈락 | 오인식 다수 | 오인식 다수 | 대체로 가능 | Photo 5는 4개 분리 | 반복 테스트 제외, 단독 사용 불가 |
| `gpt-4.1-mini` | 최우수이나 불합격 | 대체로 안정 | Photo 1 납기 오독 2회 | 안정 | Photo 5 10/10 통과 | 48/50, full-run 8/10, 모델 단독 기준 불합격 |
| `gpt-4.1` | 불합격 | 오인식 다수 | 오인식 다수 | 대체로 가능 | Photo 5 흔들림 | 0/50, full-run 0/10 |
| `gpt-5-mini` | 불합격 | `호/하`를 `조/허`로 오인식 | 일부 일시 오독 | 안정 | Photo 5 5/10 | 29/50, full-run 0/10 |

## 10-Run Validation Results

| Model | Total sample calls | Sample pass | Full-run pass | Accepted |
| --- | ---: | ---: | ---: | --- |
| `gpt-4.1-mini` | 50 | 48 | 8/10 | No |
| `gpt-4.1` | 50 | 0 | 0/10 | No |
| `gpt-5-mini` | 50 | 29 | 0/10 | No |

## Profile-Specific Revalidation

사장님 제안에 따라 5개 고지서를 먼저 프로필로 나누고, `gpt-4.1-mini`에게 프로필별 위치/필드만 읽도록 지시해 다시 검증했다.

Profile map:
- Photo 1: `toll_fee.woomyeonsan`
- Photo 2: `parking.namdong`
- Photo 3: `parking.seoul_cartax`
- Photo 4: `traffic.police_efine`
- Photo 5: `toll_fee.gangnam_sunhwan`

Result:

| Strategy | Model | Total sample calls | Sample pass | Full-run pass | Accepted |
| --- | --- | ---: | ---: | ---: | --- |
| Generic full-document read | `gpt-4.1-mini` | 50 | 48 | 8/10 | No |
| Profile-specific field read | `gpt-4.1-mini` | 50 | 49 | 9/10 | No |

Per-sample pass after profile-specific read:

| Sample | Profile | Pass |
| --- | --- | ---: |
| Photo 1 | `toll_fee.woomyeonsan` | 9/10 |
| Photo 2 | `parking.namdong` | 10/10 |
| Photo 3 | `parking.seoul_cartax` | 10/10 |
| Photo 4 | `traffic.police_efine` | 10/10 |
| Photo 5 | `toll_fee.gangnam_sunhwan` | 10/10 |

Remaining failure:
- Photo 1 `toll_fee.woomyeonsan`: 납기 `2026-06-22`를 `2023-08-22`로 1회 오독.

Interpretation:
- 프로필별 위치 힌트만으로도 안정성이 상승했다.
- 그래도 우면산 납기처럼 비슷한 숫자/흐린 영역은 모델 지시만으로 10/10을 보장하지 못한다.
- 다음 단계는 실제 crop 기반 field parser로 Photo 1 납기 영역만 잘라 재판독하고, 날짜 후보 validator로 잠그는 방식이 필요하다.

## Crop Repair Revalidation

우면산/강남순환도로 문제 필드에 대해 실제 crop + 확대 재판독을 테스트했다.

Crop generation:
- 원본 이미지는 보존.
- `/tmp/fine_notice_crops/`에 임시 crop 생성.
- `sips`로 field crop 후 4x~8x 수준 확대.

Result:

| Target | Method | Result | Judgment |
| --- | --- | ---: | --- |
| 우면산 납부기한 | receipt block 넓은 crop + 4x 확대 | 6/10 또는 9/10 | 주변 행이 섞여 불안정 |
| 우면산 납부기한 | 날짜 숫자만 좁은 crop + 확대 | 원문 판독 보조로 채택 | 자동 보정 금지 |
| 강남순환도로 통행표 | 표 전체 crop + 확대 | 원문 판독 보조로 채택 | 자동 보정 금지 |

Findings:
- crop은 무조건 넓게 자르면 안 된다. 주변 행이 같이 보이면 모델이 `조회기간`, `문의처`, `납부기한`을 섞는다.
- 우면산 납부기한은 `납부기한` 날짜 숫자 영역만 잘라야 한다.
- 강남순환도로 표는 표 전체 crop이 유효하다.
- `validYear=2026`처럼 특정 연도를 고정하는 보정은 운영 부채이며 사용하지 않는다.
- 파서는 원문 판독값을 그대로 반환해야 한다. 사람이 최종 확인하고 필요하면 수동 수정한다.

Implementation implication:
- Phase 4는 profile별 `fieldCropMap`을 만든다.
- field별 crop은 좌표, 확대 배율, fieldName, ignoreRows를 함께 가진다.
- validator는 자동 보정용이 아니라 경고/확인 필요 표시용이다.
- 최종 확정은 사람이 한다.

Per-sample pass:

| Model | Photo 1 | Photo 2 | Photo 3 | Photo 4 | Photo 5 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `gpt-4.1-mini` | 8/10 | 10/10 | 10/10 | 10/10 | 10/10 |
| `gpt-4.1` | 0/10 | 0/10 | 0/10 | 0/10 | 0/10 |
| `gpt-5-mini` | 0/10 | 10/10 | 7/10 | 7/10 | 5/10 |

Representative failures:
- `gpt-4.1-mini`: Photo 1 납기를 `2026-06-22`가 아니라 `2026-08-22`로 2회 오독.
- `gpt-4.1`: Photo 1 차량번호 null, Photo 2 납기/위반일 오독, Photo 3 `29거2763`, Photo 4 `142소5684`, Photo 5 `142소2673`.
- `gpt-5-mini`: Photo 1 차량번호 null 또는 `142조5626`, Photo 3 `29허2763`, Photo 4 `142조5684`, Photo 5 `142조2673` 또는 item 일시 오독.

## Detailed Findings

### Photo 1 - 우면산인프라웨이

`gpt-4.1-mini`:
- 유형, 발행기관, 차량번호, 금액, 납기, 단일 item 추출 성공.
- `34300180097070`을 `giro_number`로 넣었으나 실제로는 고객 전용 입금계좌/전자납부 성격으로 별도 payment field가 필요하다.
- 발송일/발행일은 이미지상 혼동 가능성이 높아 `issue_date`는 낮은 신뢰도로 취급해야 한다.

`gpt-4.1-nano`:
- 차량번호를 `1422 5626`처럼 오인식.
- 납기와 통행일을 혼동.
- item 발생일시 오인식.

`gpt-4.1`:
- 차량번호를 null로 반환.
- 납기와 통행일/발송일을 혼동.
- 지로/OCR/계좌 성격의 번호를 섞어서 반환.

Prompt/schema 보정:
- 우면산/통행료는 `payment.virtual_account`, `payment.giro_number`, `payment.ocr_number`를 분리한다.
- `납부기한`, `조회기간`, `통행일시`, `안내문 발송일`을 명시적으로 구분시킨다.

### Photo 2 - 남동구청 주정차

`gpt-4.1-mini`:
- 차량번호, 위반일시, 장소, 금액, 감경액, 납기, 전자납부번호 추출 성공.
- 구청 고지서는 CCTV 이미지의 번호판과 표의 차량번호를 교차 검증할 수 있다.

`gpt-4.1-nano`:
- 차량번호를 `101허4703`으로 오인식.
- 위반일시/장소 누락.

`gpt-4.1`:
- 차량번호는 맞췄으나 위반일자를 `2024-06-01`로 오인식.
- 납부기한과 발행일을 혼동.
- 전자납부번호 일부 자리 오인식.

Prompt/schema 보정:
- 주정차 고지서는 `violation_at`, `violation_location`, `fine.base_amount`, `fine.discount_amount`, `fine.payable_amount`를 고정 필드로 둔다.
- 전자납부번호는 `notice_number`와 분리한다.

### Photo 3 - 용산구/서울시 주정차

`gpt-4.1-mini`:
- 차량번호, 위반일시, 금액, 납기, 전자납부번호, 장소 추출 성공.
- `issue_date`를 위반일로 착각했다. 발행일은 하단 직인 주변 날짜를 우선해야 한다.

`gpt-4.1-nano`:
- 차량번호를 `290가2763`으로 오인식.
- 은행 계좌번호를 전자납부번호로 오인식.

`gpt-4.1`:
- 차량번호를 `29거2763`으로 오인식.
- 위치를 실제 위반장소가 아니라 위반유형 `보도` 중심으로 반환.
- 기관번호/세목/부과번호 계열을 payment 식별자로 섞어 반환.

Prompt/schema 보정:
- 서울시/cartax 계열은 전자납부번호가 하이픈 패턴으로 나오며, 은행별 전용계좌 목록은 납부계좌로 분리한다.
- `발행일`, `위반일시`, `납기내` 날짜를 각각 따로 추출한다.

### Photo 4 - 경찰/속도위반

`gpt-4.1-mini`:
- 차량번호, 위반일시, 금액, 납기, 위반내용, 법조항 추출 성공.
- 장소는 긴 문장이라 low-confidence field로 둬야 한다.

`gpt-4.1-nano`:
- 차량번호를 `142소5684`로 오인식.
- 위반시각을 `14:14`로 오인식.
- 고지번호와 일련번호를 혼동.

`gpt-4.1`:
- 차량번호를 `142로5684`로 오인식.
- 위반시각을 `14:01`로 오인식.
- 위반장소 대신 수취인 주소를 location으로 반환.

Prompt/schema 보정:
- 경찰 고지서는 `notice_number`와 `serial_number`를 분리한다.
- `limit_speed`, `measured_speed`, `over_speed`를 구조화한다.
- 장소는 계약자 특정에는 보조 정보로만 사용한다.

### Photo 5 - 강남순환도로

`gpt-4.1-mini`:
- 차량번호, 총액, 납기, 기간, 4개 item 분리 성공.
- 첫 번째 통행시각 초 단위는 사진 품질상 재검증 필요.

`gpt-4.1-nano`:
- 4개 item 분리는 성공.
- 첫 번째 통행시각이 흔들렸고 발행일을 통행기간과 혼동.

`gpt-4.1`:
- 4개 item 분리는 했으나 차량번호를 `142소2673`으로 오인식.
- 통행시각과 통행장소가 흔들렸다.
- 수취인명을 `뺑뺑카(주)`로 오인식.

`gpt-5-mini`:
- 차량번호를 `142조2673`으로 오인식하는 회차가 있었다.
- 4개 item 분리는 일부 성공했지만 item 일시가 흔들렸다.

Prompt/schema 보정:
- 통행료 고지서는 반드시 표의 행 단위로 `items[]`를 생성한다.
- 각 item은 이후 계약자 매칭 단위가 될 수 있으므로, 고지서 1장 단위가 아니라 item 단위로 `contractMatchRequired=true`를 둔다.

## Decision

새 기준에서는 모델 단독으로 운영 보조 파서의 안정 기준에 합격한 후보가 없다.

`gpt-4.1-nano`는 탈락이다.

`gpt-4.1`은 운영 보조 파서 기본 모델로 부적합하다. 상위 모델이지만 OCR 표 판독에서 핵심 번호/날짜를 반복적으로 잘못 확신했다.

`gpt-5-mini`도 운영 보조 파서 기본 모델로 부적합하다. 특히 `호/하` 문자 인식이 흔들렸다.

`gpt-4.1-mini`가 가장 좋은 후보지만, 10/10 기준에는 미달했다. 따라서 Phase 4는 "모델 선택"이 아니라 "모델 + template validator + deterministic correction" 구조로 가야 한다.

운영 안정성은 모델 크기 상향보다 다음 구조로 확보한다.
- `gpt-4.1-mini` 1차 파싱
- raw OCR 값 보존
- schema-level warning 생성
- 차량번호/날짜/금액 required field 확인 필요 표시
- 고지서 유형별 payment 번호 분리
- low-confidence 또는 검증 실패 건은 수동확인/재촬영/수동입력으로 분리
- 고지서 발행기관별 template validator로 납기/통행일/위반일 위치를 안내
- 차량번호 문자는 `호/하/허/거/소/로/조` 혼동 가능성을 warning으로 표시
- 우면산/강남순환도로는 crop repair를 필수 phase로 둔다.
- 계약서 검색은 AI 확정값뿐 아니라 사람이 수정한 차량번호/날짜 기준으로도 가능해야 한다.

## Phase 4 Inputs

Phase 4 schema/fixture에 반영할 필드:
- `noticeType`
- `issuer`
- `recipient`
- `vehicleNumber`
- `noticeNumber`
- `serialNumber`
- `payment.electronicPaymentNumber`
- `payment.giroNumber`
- `payment.ocrNumber`
- `payment.virtualAccounts[]`
- `fine.baseAmount`
- `fine.discountAmount`
- `fine.payableAmount`
- `dueDate`
- `issueDate`
- `items[]`
- `items[].occurredAt`
- `items[].amount`
- `items[].location`
- `items[].violationDetail`
- `items[].law`
- `items[].contractMatchRequired`
- `warnings[]`
- `confidence`

Branch keys:
- `toll_fee.woomyeonsan`
- `toll_fee.gangnam_sunhwan`
- `parking.namdong`
- `parking.seoul_cartax`
- `traffic.police_efine`

## Remaining Risks

- 발행일과 위반일/통행일은 OCR이 혼동하기 쉬우므로 field-level confidence가 필요하다.
- 은행 계좌번호, 전자납부번호, 지로번호, OCR 번호는 같은 payment block 안에서 분리해야 한다.
- 사진 기울기, 접힘, 손가락 가림, 겹친 다른 고지서는 실제 앱 촬영 단계에서 crop/retake 안내가 필요하다.
- 우면산/강남순환도로처럼 한 장에 여러 통행건이 있는 경우 계약자 매칭은 고지서 단위가 아니라 item 단위다.

## Review Gate

사장님 확인 필요:
- Phase 4 기준 모델을 `gpt-4.1-mini`로 잠글지
- `gpt-4.1-mini`를 단독 모델이 아니라 validator 포함 1차 파서로 쓸지
- `gpt-4.1`과 `gpt-5-mini`는 기본 모델과 fallback에서 제외할지
- 고지서 종류별 제출 정책 문서를 나중에 별도 phase로 잠글지
