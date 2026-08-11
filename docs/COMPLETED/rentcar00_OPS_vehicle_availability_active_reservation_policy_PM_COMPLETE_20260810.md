# rentcar00_OPS Reservation Vehicle-Change Overlap Terminal Status PM Complete

## Document Metadata
- Created at: 2026-08-10 10:05 KST
- Revised at: 2026-08-10 10:22 KST
- Completed at: 2026-08-10 KST
- Author/agent: Codex
- Current status: Completed
- Execution scope: Reservation-detail vehicle-change overlap check only.
- Execution Mode: `NORMAL (pa all)`
- Related docs:
  - `docs/GOAL/rentcar00_OPS-current.md`
  - `docs/PHASE/README.md`
  - `docs/COMPLETED/rentcar00_OPS-completed.md`

## 0. Goal Lock
- Objective:
  - Fix the OPS reservation-detail vehicle-change bug where an overlapping `예약취소` reservation blocked changing `101하6688` to `101하9300`.
- Final success condition:
  - `fetchReservationVehicleOverlaps()` applies the existing terminal reservation status rule:
    - `예약취소` does not occupy a vehicle.
    - `완료` does not occupy a vehicle.
    - all other statuses, including blank/unknown, remain blocking if their time windows overlap.
  - The 6688 -> 9300 case is not blocked by the cancelled 9300 row.
  - Active overlaps still block vehicle change.
- Explicit non-goals:
  - No new vehicle-availability service.
  - No new shared helper.
  - No full consumer migration.
  - No reservation-create precheck change.
  - No status-board UI redesign.
  - No DB data edit, DB migration, parser runtime restart, or IMS write.

## 1. Current State Evidence
- Target reservation:
  - `WEB-b7aabf5a-40a2-48e9-a40a-9994ff2dbe92`
  - Current car: `101하6688`
  - Desired car: `101하9300`
  - Period: `2026-08-12 09:00 ~ 2026-08-13 09:00` KST
  - Status: `예약중`
  - IMS external link: none
- Current bug proof before fix:
  - Existing overlap logic against `101하9300` returned 1 row:
    - `EXT-carmore-2172_2026073101001`
    - status `예약취소`
    - period `2026-08-10 10:00 ~ 2026-08-13 10:00` KST
  - Same read-only query with `reservation_status not in ('예약취소', '완료')` returned 0 rows.
- Existing terminal status references:
  - `SupabaseOpsRepository._deriveReservationTabKey()` treats `예약취소` and `완료` as completed.
  - `status_board_detail_page.dart` vehicle availability display excludes `예약취소` and `완료`.

## 2. Completed Change
| Item | Before | After |
| --- | --- | --- |
| Vehicle-change overlap query | selected reservation id/number/customer/time only | also selects `reservation_status` |
| Overlap loop | blocked by any overlapping time window | skips `예약취소` and `완료` before time overlap check |
| Scope | one repository method | one repository method |

### Files Changed
- `lib/data/repositories/supabase_ops_repository.dart`
- `pubspec.yaml`

### Behavior
- Reservation-detail vehicle change now ignores cancelled/completed reservations for target-car occupancy.
- Active reservations still block if their time windows overlap.
- Blank or unknown statuses still block.
- Same reservation id remains ignored.
- Invalid/missing date rows remain ignored as before.

## 3. Deployment
- App version/build: `1.0.0+59`
- Code commit: `a5bb856 fix: ignore terminal reservation overlaps`
- Local APK: `build/releases/rentcar00_ops-app-release-arm64-b59-a5bb856.apk`
- Google Drive: `rentcar00_OPS/apk/rentcar00_ops-app-release-arm64-b59-a5bb856.apk`
- File size: `20,702,419 bytes`
- SHA-256: `890566762434b942161b46f958f41baadf901c11638cbb4a8f067ba58d19af0a`
- Final remote APK check:
  - `rentcar00_ops-app-release-arm64-b59-a5bb856.apk`
  - `20702419 rentcar00_ops-app-release-arm64-b59-a5bb856.apk`
- Old remote APKs b54-b58 were removed from `rentcar00_OPS/apk/`.

## 4. Verification
- `dart format lib/data/repositories/supabase_ops_repository.dart` completed.
- `flutter analyze lib/data/repositories/supabase_ops_repository.dart` passed with no issues.
- `flutter test` passed: 24 tests.
- `git diff --check -- lib/data/repositories/supabase_ops_repository.dart pubspec.yaml docs/PHASE/rentcar00_OPS_vehicle_availability_active_reservation_policy_PM_20260810.md` passed before PM move.
- `flutter build apk --release --target-platform android-arm64` passed.
- Read-only Supabase comparison confirmed:
  - old logic: 1 cancelled overlap row for `101하9300`
  - terminal-status rule: 0 active overlap rows for `101하9300`
- Google Drive upload and final remote list/size check passed.

## 5. Gate Judgment
- MCG: PASS
  - Code diff was narrowed to the confirmed broken repository method plus build-number bump.
  - No DB data/schema, parser runtime, `.env`, IMS write, or unrelated dirty file changed.
  - Analyze, tests, build, upload, and remote APK verification passed.
- BIG-M: GO
  - Bundle integrity is complete: code commit, b59 APK, remote latest-only APK, completed PM, current-state doc, phase index, and completed ledger are aligned.

## 6. Residual Risk
- 실기기에서 6688 -> 9300 차량변경 버튼 흐름 자체는 직원 단말 설치 후 1회 확인하면 된다.
- Historical data that uses a different terminal status string is intentionally not excluded by this PM.
- Full vehicle-availability consumer consolidation remains deferred to a separate PM.
