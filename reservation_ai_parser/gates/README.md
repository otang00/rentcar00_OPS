# OPS Reservation Event GatePack

This GatePack lists and tests the current OPS reservation-event gates.

It is an owner-local diagnostic landmark. It does not send events, read `.env`,
query Supabase, call IMS, restart the parser, or change production behavior.

## Scope

- receiver header/body gates
- source provider compatibility gate
- IMS binding-before-projection gates
- OPS projection identity gate

## Current Compatibility Rule

Unknown or missing `sourceProvider` still falls back to `homepage`.

That fallback is intentionally preserved here because changing it would alter
runtime behavior. A strict source-provider policy needs a separate PM.

## Test Rule

Tests import only `gates/*.js`.

Do not import `src/server.js` from GatePack tests because that module starts the
HTTP server at module load time.
