create extension if not exists pgcrypto;

create table if not exists public.rc00_ops_sheet_sync_runs (
  id uuid primary key default gen_random_uuid(),
  source_type text not null default 'google_sheets',
  status text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  meta_json jsonb not null default '{}'::jsonb,
  error_text text,
  created_at timestamptz not null default now()
);

create table if not exists public.rc00_ops_sheet_reservations_raw (
  id uuid primary key default gen_random_uuid(),
  sync_run_id uuid not null references public.rc00_ops_sheet_sync_runs(id) on delete cascade,
  sheet_row_number integer not null,
  reservation_id text,
  reservation_number text,
  car_number text,
  car_name text,
  start_at_raw text,
  end_at_raw text,
  location_raw text,
  customer_name text,
  customer_phone text,
  customer_birth_date_raw text,
  referral_source text,
  payment_amount_raw text,
  status_raw text,
  payload_json jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (sync_run_id, sheet_row_number)
);

create index if not exists idx_rc00_ops_sheet_reservations_raw_reservation_id
  on public.rc00_ops_sheet_reservations_raw (reservation_id);
create index if not exists idx_rc00_ops_sheet_reservations_raw_reservation_number
  on public.rc00_ops_sheet_reservations_raw (reservation_number);
create index if not exists idx_rc00_ops_sheet_reservations_raw_car_number
  on public.rc00_ops_sheet_reservations_raw (car_number);

create table if not exists public.rc00_ops_sheet_schedules_raw (
  id uuid primary key default gen_random_uuid(),
  sync_run_id uuid not null references public.rc00_ops_sheet_sync_runs(id) on delete cascade,
  sheet_row_number integer not null,
  schedule_id text,
  reservation_id text,
  reservation_number text,
  car_number text,
  car_name text,
  schedule_type_raw text,
  schedule_at_raw text,
  location_raw text,
  detail_text text,
  partial_return_raw text,
  schedule_done_raw text,
  payload_json jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (sync_run_id, sheet_row_number)
);

create index if not exists idx_rc00_ops_sheet_schedules_raw_schedule_id
  on public.rc00_ops_sheet_schedules_raw (schedule_id);
create index if not exists idx_rc00_ops_sheet_schedules_raw_reservation_id
  on public.rc00_ops_sheet_schedules_raw (reservation_id);
create index if not exists idx_rc00_ops_sheet_schedules_raw_reservation_number
  on public.rc00_ops_sheet_schedules_raw (reservation_number);
create index if not exists idx_rc00_ops_sheet_schedules_raw_car_number
  on public.rc00_ops_sheet_schedules_raw (car_number);

create table if not exists public.rc00_ops_reservations (
  id uuid primary key default gen_random_uuid(),
  reservation_id text not null,
  reservation_number text,
  car_id uuid,
  car_number text,
  car_name text,
  customer_name text,
  customer_phone text,
  customer_birth_date text,
  referral_source text,
  payment_amount text,
  start_at timestamptz,
  end_at timestamptz,
  pickup_location text,
  dropoff_location text,
  reservation_status text,
  last_synced_at timestamptz not null default now(),
  note_text text,
  meta_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (reservation_id)
);

create index if not exists idx_rc00_ops_reservations_reservation_number
  on public.rc00_ops_reservations (reservation_number);
create index if not exists idx_rc00_ops_reservations_car_number
  on public.rc00_ops_reservations (car_number);
create index if not exists idx_rc00_ops_reservations_start_at
  on public.rc00_ops_reservations (start_at);
create index if not exists idx_rc00_ops_reservations_end_at
  on public.rc00_ops_reservations (end_at);

create table if not exists public.rc00_ops_reservation_states (
  id uuid primary key default gen_random_uuid(),
  reservation_id text not null,
  reservation_ref_id uuid not null references public.rc00_ops_reservations(id) on delete cascade,
  tab_key text not null,
  status_key text not null,
  auto_tab_key text,
  auto_status_key text,
  manual_override boolean not null default false,
  needs_attention boolean not null default false,
  warning_level text,
  check_payload_json jsonb not null default '{}'::jsonb,
  last_action_at timestamptz,
  completed_at timestamptz,
  memo_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (reservation_id),
  unique (reservation_ref_id)
);

create index if not exists idx_rc00_ops_reservation_states_tab_key
  on public.rc00_ops_reservation_states (tab_key);
create index if not exists idx_rc00_ops_reservation_states_status_key
  on public.rc00_ops_reservation_states (status_key);
create index if not exists idx_rc00_ops_reservation_states_needs_attention
  on public.rc00_ops_reservation_states (needs_attention);

create table if not exists public.rc00_ops_action_logs (
  id uuid primary key default gen_random_uuid(),
  reservation_id text not null,
  reservation_ref_id uuid not null references public.rc00_ops_reservations(id) on delete cascade,
  action_key text not null,
  before_tab_key text,
  after_tab_key text,
  before_status_key text,
  after_status_key text,
  actor_id text,
  actor_name text,
  message_text text,
  result_status text not null,
  error_text text,
  meta_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_rc00_ops_action_logs_reservation_id
  on public.rc00_ops_action_logs (reservation_id);
create index if not exists idx_rc00_ops_action_logs_action_key
  on public.rc00_ops_action_logs (action_key);
create index if not exists idx_rc00_ops_action_logs_created_at
  on public.rc00_ops_action_logs (created_at desc);

create table if not exists public.rc00_ops_outbox (
  id uuid primary key default gen_random_uuid(),
  reservation_id text not null,
  reservation_ref_id uuid not null references public.rc00_ops_reservations(id) on delete cascade,
  action_log_id uuid references public.rc00_ops_action_logs(id) on delete set null,
  target_type text not null,
  target_ref text,
  payload_json jsonb not null default '{}'::jsonb,
  delivery_status text not null default 'pending',
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  delivered_at timestamptz,
  error_text text,
  created_at timestamptz not null default now()
);

create index if not exists idx_rc00_ops_outbox_reservation_id
  on public.rc00_ops_outbox (reservation_id);
create index if not exists idx_rc00_ops_outbox_delivery_status
  on public.rc00_ops_outbox (delivery_status);
create index if not exists idx_rc00_ops_outbox_created_at
  on public.rc00_ops_outbox (created_at desc);
