# rentcar00_OPS Google Sheets Import Runbook v1

## 1. 목적
이 문서는 `예약` / `일정` 탭을 Google Sheets에서 read-only로 읽어와
`rc00_ops_sheet_*_raw` 테이블에 적재하기 전 점검/실행 순서를 고정한다.

## 2. 입력값
- service account JSON 경로
- spreadsheet id
- 대상 시트명
  - `예약`
  - `일정`

## 3. 점검 순서
1. 서비스계정이 시트에 공유되어 있는지 확인
2. `tool/inspect_google_sheets.dart` 로 실제 시트 접근 확인
3. 헤더 행을 확정
4. 샘플 5행으로 날짜/공란 패턴 확인
5. raw import 매핑표 갱신
6. 수동 import 실행

## 4. inspect 명령
```bash
dart run tool/inspect_google_sheets.dart <service-account.json> <spreadsheet-id> 예약 일정
```

## 5. 원칙
- 초기 단계는 read-only만 허용
- 시트 원문은 raw에 그대로 보존
- parsing 실패가 있어도 payload는 버리지 않음
- 원장 생성은 `예약` 탭 기준으로만 수행
- `일정` orphan 행은 raw에 남긴다

## 6. 첫 실행 기록
- 실행 일시: 2026-05-09 (Asia/Seoul)
- spreadsheet: `차량현황`
- sync run id: `89fe1958-d25a-4b96-a100-b6bea28a93df`
- reservation raw count: `79`
- schedule raw count: `78`
