create table if not exists public.rc00_ops_staff_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  login_id text not null unique,
  display_name text,
  role text not null default 'staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz
);

create index if not exists idx_rc00_ops_staff_accounts_is_active
  on public.rc00_ops_staff_accounts (is_active);

alter table public.rc00_ops_staff_accounts enable row level security;
alter table public.rc00_ops_import_runs enable row level security;
alter table public.rc00_ops_cars enable row level security;
alter table public.rc00_ops_reservations enable row level security;
alter table public.rc00_ops_reservation_states enable row level security;
alter table public.rc00_ops_schedules enable row level security;
alter table public.rc00_ops_action_logs enable row level security;
alter table public.rc00_ops_outbox enable row level security;

drop policy if exists rc00_ops_staff_accounts_select_self on public.rc00_ops_staff_accounts;
create policy rc00_ops_staff_accounts_select_self
  on public.rc00_ops_staff_accounts
  for select
  to authenticated
  using (auth.uid() = auth_user_id);

drop policy if exists rc00_ops_import_runs_authenticated_all on public.rc00_ops_import_runs;
create policy rc00_ops_import_runs_authenticated_all
  on public.rc00_ops_import_runs
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_cars_authenticated_all on public.rc00_ops_cars;
create policy rc00_ops_cars_authenticated_all
  on public.rc00_ops_cars
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_reservations_authenticated_all on public.rc00_ops_reservations;
create policy rc00_ops_reservations_authenticated_all
  on public.rc00_ops_reservations
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_reservation_states_authenticated_all on public.rc00_ops_reservation_states;
create policy rc00_ops_reservation_states_authenticated_all
  on public.rc00_ops_reservation_states
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_schedules_authenticated_all on public.rc00_ops_schedules;
create policy rc00_ops_schedules_authenticated_all
  on public.rc00_ops_schedules
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_action_logs_authenticated_all on public.rc00_ops_action_logs;
create policy rc00_ops_action_logs_authenticated_all
  on public.rc00_ops_action_logs
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_outbox_authenticated_all on public.rc00_ops_outbox;
create policy rc00_ops_outbox_authenticated_all
  on public.rc00_ops_outbox
  for all
  to authenticated
  using (true)
  with check (true);
