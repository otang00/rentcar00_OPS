do $$
begin
  if to_regclass('public.rc00_ops_import_runs') is null
     and to_regclass('public.rc00_ops_sheet_sync_runs') is not null then
    alter table public.rc00_ops_sheet_sync_runs rename to rc00_ops_import_runs;
  end if;

  if to_regclass('public.rc00_ops_reservations_raw') is null
     and to_regclass('public.rc00_ops_sheet_reservations_raw') is not null then
    alter table public.rc00_ops_sheet_reservations_raw rename to rc00_ops_reservations_raw;
  end if;

  if to_regclass('public.rc00_ops_schedules_raw') is null
     and to_regclass('public.rc00_ops_sheet_schedules_raw') is not null then
    alter table public.rc00_ops_sheet_schedules_raw rename to rc00_ops_schedules_raw;
  end if;

  if to_regclass('public.rc00_ops_cars_raw') is null
     and to_regclass('public.rc00_ops_sheet_cars') is not null then
    alter table public.rc00_ops_sheet_cars rename to rc00_ops_cars_raw;
  end if;
end $$;

create table if not exists public.rc00_ops_cars (
  id uuid primary key default gen_random_uuid(),
  car_number text,
  car_name text,
  status text,
  car_wash text,
  interior_wash text,
  start_at text,
  end_at text,
  customer_name text,
  pickup_location text,
  customer_phone text,
  note_text text,
  parking_location text,
  car_registered_at text,
  car_inspection_at text,
  car_age_expiry_at text,
  car_number_front text,
  car_number_middle text,
  car_number_rear text,
  status_action text,
  source_import_run_id uuid references public.rc00_ops_import_runs(id) on delete set null,
  source_car_raw_id uuid references public.rc00_ops_cars_raw(id) on delete set null,
  payload_json jsonb not null default '{}'::jsonb,
  last_synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_rc00_ops_cars_car_number_unique
  on public.rc00_ops_cars (car_number);
create index if not exists idx_rc00_ops_cars_status
  on public.rc00_ops_cars (status);

create table if not exists public.rc00_ops_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_id text,
  reservation_id text,
  reservation_number text,
  car_number text,
  car_name text,
  schedule_type_raw text,
  schedule_at_raw text,
  location_text text,
  detail_text text,
  partial_return_raw text,
  schedule_done_raw text,
  source_import_run_id uuid references public.rc00_ops_import_runs(id) on delete set null,
  source_schedule_raw_id uuid references public.rc00_ops_schedules_raw(id) on delete set null,
  payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_rc00_ops_schedules_schedule_id_unique
  on public.rc00_ops_schedules (schedule_id);
create index if not exists idx_rc00_ops_schedules_reservation_id
  on public.rc00_ops_schedules (reservation_id);
create index if not exists idx_rc00_ops_schedules_car_number
  on public.rc00_ops_schedules (car_number);

with latest_import as (
  select id
  from public.rc00_ops_import_runs
  order by case when status = 'success' then 0 else 1 end, started_at desc
  limit 1
)
insert into public.rc00_ops_cars (
  car_number,
  car_name,
  status,
  car_wash,
  interior_wash,
  start_at,
  end_at,
  customer_name,
  pickup_location,
  customer_phone,
  note_text,
  parking_location,
  car_registered_at,
  car_inspection_at,
  car_age_expiry_at,
  car_number_front,
  car_number_middle,
  car_number_rear,
  status_action,
  source_import_run_id,
  source_car_raw_id,
  payload_json,
  last_synced_at,
  updated_at
)
select
  raw.car_number,
  raw.car_name,
  raw.status,
  raw.car_wash,
  raw.interior_wash,
  raw.start_at,
  raw.end_at,
  raw.customer_name,
  raw.pickup_location,
  raw.customer_phone,
  raw.note_text,
  raw.parking_location,
  raw.car_registered_at,
  raw.car_inspection_at,
  raw.car_age_expiry_at,
  raw.car_number_front,
  raw.car_number_middle,
  raw.car_number_rear,
  raw.status_action,
  raw.sync_run_id,
  raw.id,
  raw.payload_json,
  now(),
  now()
from public.rc00_ops_cars_raw raw
join latest_import li on li.id = raw.sync_run_id
where raw.car_number is not null and btrim(raw.car_number) <> ''
on conflict (car_number) do update set
  car_name = excluded.car_name,
  status = excluded.status,
  car_wash = excluded.car_wash,
  interior_wash = excluded.interior_wash,
  start_at = excluded.start_at,
  end_at = excluded.end_at,
  customer_name = excluded.customer_name,
  pickup_location = excluded.pickup_location,
  customer_phone = excluded.customer_phone,
  note_text = excluded.note_text,
  parking_location = excluded.parking_location,
  car_registered_at = excluded.car_registered_at,
  car_inspection_at = excluded.car_inspection_at,
  car_age_expiry_at = excluded.car_age_expiry_at,
  car_number_front = excluded.car_number_front,
  car_number_middle = excluded.car_number_middle,
  car_number_rear = excluded.car_number_rear,
  status_action = excluded.status_action,
  source_import_run_id = excluded.source_import_run_id,
  source_car_raw_id = excluded.source_car_raw_id,
  payload_json = excluded.payload_json,
  last_synced_at = now(),
  updated_at = now();

with latest_import as (
  select id
  from public.rc00_ops_import_runs
  order by case when status = 'success' then 0 else 1 end, started_at desc
  limit 1
)
insert into public.rc00_ops_schedules (
  schedule_id,
  reservation_id,
  reservation_number,
  car_number,
  car_name,
  schedule_type_raw,
  schedule_at_raw,
  location_text,
  detail_text,
  partial_return_raw,
  schedule_done_raw,
  source_import_run_id,
  source_schedule_raw_id,
  payload_json,
  updated_at
)
select
  raw.schedule_id,
  raw.reservation_id,
  raw.reservation_number,
  raw.car_number,
  raw.car_name,
  raw.schedule_type_raw,
  raw.schedule_at_raw,
  raw.location_raw,
  raw.detail_text,
  raw.partial_return_raw,
  raw.schedule_done_raw,
  raw.sync_run_id,
  raw.id,
  raw.payload_json,
  now()
from public.rc00_ops_schedules_raw raw
join latest_import li on li.id = raw.sync_run_id
where raw.schedule_type_raw in ('배차', '반납')
on conflict (schedule_id) do update set
  reservation_id = excluded.reservation_id,
  reservation_number = excluded.reservation_number,
  car_number = excluded.car_number,
  car_name = excluded.car_name,
  schedule_type_raw = excluded.schedule_type_raw,
  schedule_at_raw = excluded.schedule_at_raw,
  location_text = excluded.location_text,
  detail_text = excluded.detail_text,
  partial_return_raw = excluded.partial_return_raw,
  schedule_done_raw = excluded.schedule_done_raw,
  source_import_run_id = excluded.source_import_run_id,
  source_schedule_raw_id = excluded.source_schedule_raw_id,
  payload_json = excluded.payload_json,
  updated_at = now();
