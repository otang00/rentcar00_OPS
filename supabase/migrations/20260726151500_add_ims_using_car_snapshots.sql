create table if not exists public.rc00_ops_ims_using_car_snapshots (
  id uuid primary key default gen_random_uuid(),
  source_type text not null,
  external_id text not null,
  external_detail_id text,
  car_number text,
  customer_name text,
  rental_at timestamptz,
  return_at timestamptz,
  raw_status text,
  raw_payload_json jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  missing_since timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rc00_ops_ims_using_car_snapshots_source_type_check
    check (source_type in ('normal_schedule', 'insurance_claim')),
  constraint rc00_ops_ims_using_car_snapshots_identity_unique
    unique (source_type, external_id)
);

create index if not exists idx_rc00_ops_ims_using_car_snapshots_active
  on public.rc00_ops_ims_using_car_snapshots (active, source_type, last_seen_at desc);

create index if not exists idx_rc00_ops_ims_using_car_snapshots_car_number
  on public.rc00_ops_ims_using_car_snapshots (car_number)
  where car_number is not null and car_number <> '';

create or replace function public.preserve_ims_using_car_snapshot_first_seen()
returns trigger
language plpgsql
as $$
begin
  new.first_seen_at = old.first_seen_at;
  new.created_at = old.created_at;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_preserve_ims_using_car_snapshot_first_seen
  on public.rc00_ops_ims_using_car_snapshots;

create trigger trg_preserve_ims_using_car_snapshot_first_seen
before update on public.rc00_ops_ims_using_car_snapshots
for each row
execute function public.preserve_ims_using_car_snapshot_first_seen();

alter table public.rc00_ops_ims_using_car_snapshots enable row level security;

comment on table public.rc00_ops_ims_using_car_snapshots
  is 'Current and historical IMS using-car snapshot rows used for lifecycle diff detection. First run is bootstrap/no-action.';

comment on column public.rc00_ops_ims_using_car_snapshots.source_type
  is 'normal_schedule for company-car-schedules, insurance_claim for rencar-claims.';

comment on column public.rc00_ops_ims_using_car_snapshots.external_id
  is 'IMS schedule id for normal_schedule or claim id for insurance_claim. Never car number.';
