create table if not exists public.rc00_ops_reservation_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  event_type text not null,
  booking_order_id text,
  reservation_code text,
  payload_json jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  status text not null default 'received',
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id)
);

create index if not exists idx_rc00_ops_reservation_events_event_type
  on public.rc00_ops_reservation_events (event_type);
create index if not exists idx_rc00_ops_reservation_events_booking_order_id
  on public.rc00_ops_reservation_events (booking_order_id);
create index if not exists idx_rc00_ops_reservation_events_reservation_code
  on public.rc00_ops_reservation_events (reservation_code);
create index if not exists idx_rc00_ops_reservation_events_received_at
  on public.rc00_ops_reservation_events (received_at desc);

alter table public.rc00_ops_reservation_events enable row level security;

drop policy if exists rc00_ops_reservation_events_authenticated_select on public.rc00_ops_reservation_events;
create policy rc00_ops_reservation_events_authenticated_select
  on public.rc00_ops_reservation_events
  for select
  to authenticated
  using (true);
