create table if not exists public.rc00_ops_sheet_cars (
  id uuid primary key default gen_random_uuid(),
  sync_run_id uuid not null references public.rc00_ops_sheet_sync_runs(id) on delete cascade,
  sheet_row_number integer not null,
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
  payload_json jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (sync_run_id, sheet_row_number)
);

create index if not exists idx_rc00_ops_sheet_cars_car_number
  on public.rc00_ops_sheet_cars (car_number);
create index if not exists idx_rc00_ops_sheet_cars_status
  on public.rc00_ops_sheet_cars (status);
create index if not exists idx_rc00_ops_sheet_cars_customer_name
  on public.rc00_ops_sheet_cars (customer_name);
