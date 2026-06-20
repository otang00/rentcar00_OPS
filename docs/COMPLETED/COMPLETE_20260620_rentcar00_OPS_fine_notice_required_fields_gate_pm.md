# COMPLETE 2026-06-20 - Fine Notice Required Fields Gate

## Result
- Implemented a hard document-generation gate for fine notice packages.
- If any value that would appear as `확인 필요` remains, the server rejects document generation before creating or replacing files.
- The app now receives the missing-field list and opens `고지서수정` so the operator can manually fill required values.

## Policy Locked
- No generated application/list PDF may contain `확인 필요` as a normal output.
- Required renter fields:
  - 임차인명
  - 임차인 전화번호
  - 임차인 주소
  - 주민등록번호
  - 운전면허번호
- Required notice fields per bundled row:
  - 고지서번호
  - 차량번호
  - 위반/통행일시
  - 위반/통행장소
  - 고지서 유형
- Required representative field:
  - 발행기관

## Code Changes
- `reservation_ai_parser/src/server.js`
  - Added required-field validation before bundle key update, file copy, PDF generation, metadata upsert, and `document_ready` state update.
  - Added `missingFields` to API error responses.
  - Existing sample now rejects with `409 document_required_fields_missing` when 주민등록번호/운전면허번호 are missing.
- `lib/features/fines/domain/fine_notice_models.dart`
  - Added explicit renter fields mapped to `renter_*` DB columns.
- `lib/features/fines/presentation/fine_notice_page.dart`
  - Added renter fields to `고지서수정`.
  - On document-generation required-field failure, shows the missing list and opens the edit dialog.
- `lib/features/fines/data/fine_notice_document_client.dart`
  - Parses `missingFields` from server errors.
- `test/fine_notice_models_test.dart`
  - Added renter field persistence/mapping assertions.

## Verification
- `node --check reservation_ai_parser/src/server.js`
- `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
- `flutter test test/fine_notice_models_test.dart`
- Runtime smoke:
  - `GET http://127.0.0.1:43110/health` passed.
  - `POST /fine-notices/generate-documents` for `5ec6b200-d553-443c-85f6-03ba1e99b738` rejected as expected:
    - HTTP `409`
    - error `document_required_fields_missing`
    - missing fields: `주민등록번호`, `운전면허번호`

## Residual Risk
- A fully valid live generation smoke needs one confirmed notice row with both resident registration number and driver license number populated.
- Existing previously generated preview PDFs can still exist in local `output/` or old bundle folders; the new gate prevents new incomplete generation.

## Commit
- Recorded in the commit that includes this completion document.
