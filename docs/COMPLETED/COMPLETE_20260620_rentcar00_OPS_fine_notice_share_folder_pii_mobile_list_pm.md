# COMPLETE 2026-06-20 rentcar00 OPS Fine Notice Share Folder / PII / Mobile List PM

## Summary
- Implemented `original/` and `share/` folder policy for newly generated fine notice document packages.
- Share package responses now expose only approved `share/` files.
- Contract original is preserved but not included in share packages.
- Application/list PDFs no longer show toll amount fields.
- Submission PDFs use full stored renter phone and identity/license fields when available.
- App main fine notice list was changed from a wide table to a mobile-first compact list.
- Duplicate share file display is guarded by deterministic paths and response dedupe.

## Changed Files
- `reservation_ai_parser/src/server.js`
- `lib/features/fines/domain/fine_notice_models.dart`
- `lib/features/fines/data/fine_notice_document_client.dart`
- `lib/features/fines/data/fine_notice_repository.dart`
- `lib/features/fines/presentation/fine_notice_page.dart`
- `test/fine_notice_models_test.dart`
- `docs/PHASE/rentcar00_OPS-fine-notice-share-folder-pii-mobile-list-pm.md`

## Verification
- `node --check reservation_ai_parser/src/server.js`
- `flutter analyze lib/features/fines test/fine_notice_models_test.dart`
- `flutter test test/fine_notice_models_test.dart`
- Parser service restart and `/health` smoke.
- Sample fine notice document generation executed twice.
- Share package API returned only approved `share` roles:
  - `renter_change_application`
  - `notice_original`
  - `contract_with_stamps`
  - `vehicle_application_list`
- Share file download returned PDF bytes successfully.
- Rendered application/list/contract PDFs and visually checked:
  - application/list have no toll amount field
  - phone is not masked
  - contract stamp is on first page only and does not cover 담당자/연락처

## Residual Risks
- Existing old smoke folders such as `contract/`, `documents/`, and `notice/` may remain in already-generated sample bundles. They are not returned by the share package API.
- Existing legacy files were not deleted by policy.
- If IMS source data does not provide resident/license values, generated PDFs show review-needed placeholders for those fields.
- Future custom official templates should be handled by a separate PM when the final template is supplied.

## Commit
- Pending at document creation time.
