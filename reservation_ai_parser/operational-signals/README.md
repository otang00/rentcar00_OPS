# OPS Operational SignalPack

This SignalPack names current OPS reservation-event outcomes.

It is an owner-local interpretation layer. It does not emit runtime logs, read
`.env`, query Supabase, call IMS, restart the parser, deploy code, or change
production behavior.

## Scope

Parser-side reservation-event signals only:

- `ops_reservation_event_received`
- `ops_reservation_event_imported`
- `ops_reservation_event_failed`
- `ops_ims_binding_conflict`
- `ops_ims_create_required_before_projection`
- `ops_projection_created`
- `ops_projection_reused`

## Safety Rule

Signal objects use safe identifiers and status fields only. They must not carry
raw payloads, booking objects, reservation input objects, customer names,
customer phone numbers, secrets, tokens, or environment values.

## Test Rule

Tests import only `operational-signals/*.js` and, where needed, the GatePack.

Do not import `src/server.js` from SignalPack tests because that module starts
the HTTP server at module load time.
