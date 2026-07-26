# 2026-07-27 — 외부예약 OPS 등록/IMS binding 보강

## 완료 내용

- `reservation.created` 이벤트 수신 시 기존 OPS 예약이 있으면 누락된 state/schedule projection을 idempotent하게 보강한다.
- 찜카/카모아 등 homepage가 아닌 provider 예약은 OPS 예약 생성 전에 IMS 예약 생성 또는 기존 IMS 예약 exact reuse가 성공해야 한다.
- IMS 생성/reuse 후 같은 IMS external id가 다른 OPS 예약에 이미 linked 되어 있으면 충돌로 차단한다.
- IMS link 저장 시 `source_type`을 함께 저장해 일반대차와 보험대차 구분 기반을 마련했다.
- 신규 OPS 예약 생성 시 state/schedule 삽입을 duplicate-ignore 방식으로 보강해 재수신 event에 더 안전하게 했다.

## 핵심 기준

- 홈페이지 예약은 홈페이지 기준으로 OPS 예약을 생성하고 IMS 자동생성은 하지 않는다.
- 외부 provider 예약은 IMS 생성/연결이 먼저 확정되어야 OPS 예약을 만든다.
- 과거 중복 link는 별도 정리 대상이며, 앞으로 새 중복 IMS binding은 차단한다.

## 주요 파일

- `reservation_ai_parser/src/server.js`
- `lib/data/models/external_reservation_link.dart`
- `lib/data/repositories/supabase_ops_repository.dart`
- `supabase/migrations/20260726121316_add_ims_lifecycle_link_source_type.sql`
- `supabase/migrations/20260726193000_enforce_future_unique_ims_binding.sql`

## 남은 확인

- migration apply와 parser restart는 이번 커밋 범위에 포함하지 않는다.
- 실제 외부예약 단일 live 검증은 별도 승인 후 진행한다.
