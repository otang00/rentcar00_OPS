-- Canonical date/time columns for direct DB operation.
-- Policy: store operational datetimes as timestamptz; UI owns display formatting.

create or replace function public.rc00_ops_parse_kst_datetime(raw_value text)
returns timestamptz
language plpgsql
as $$
declare
  normalized text;
  m text[];
  year_i int;
  month_i int;
  day_i int;
  hour_i int := 0;
  minute_i int := 0;
  second_i int := 0;
begin
  normalized := btrim(coalesce(raw_value, ''));
  if normalized = '' then
    return null;
  end if;

  normalized := replace(normalized, ' ', ' ');
  normalized := regexp_replace(normalized, '\s+', ' ', 'g');
  normalized := regexp_replace(normalized, ',', '', 'g');
  normalized := replace(normalized, '.', '-');
  normalized := replace(normalized, '/', '-');
  normalized := regexp_replace(normalized, '-+', '-', 'g');

  m := regexp_match(normalized, '^(\d{4})-(\d{1,2})-(\d{1,2})$');
  if m is not null then
    return make_timestamptz(m[1]::int, m[2]::int, m[3]::int, 0, 0, 0, 'Asia/Seoul');
  end if;

  m := regexp_match(normalized, '^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?(?:\.\d+)?$');
  if m is not null then
    year_i := m[1]::int;
    month_i := m[2]::int;
    day_i := m[3]::int;
    hour_i := m[4]::int;
    minute_i := m[5]::int;
    second_i := coalesce(nullif(m[6], '')::int, 0);
    return make_timestamptz(year_i, month_i, day_i, hour_i, minute_i, second_i, 'Asia/Seoul');
  end if;

  m := regexp_match(normalized, '^(\d{2})-(\d{1,2})-(\d{1,2})$');
  if m is not null then
    return make_timestamptz(2000 + m[1]::int, m[2]::int, m[3]::int, 0, 0, 0, 'Asia/Seoul');
  end if;

  return null;
exception
  when others then
    return null;
end;
$$;

alter table public.rc00_ops_schedules
  add column if not exists schedule_type text,
  add column if not exists schedule_at timestamptz,
  add column if not exists schedule_done boolean not null default false,
  add column if not exists partial_return_at timestamptz;

update public.rc00_ops_schedules
set
  schedule_type = coalesce(nullif(btrim(schedule_type_raw), ''), schedule_type),
  schedule_at = coalesce(schedule_at, public.rc00_ops_parse_kst_datetime(schedule_at_raw)),
  schedule_done = lower(btrim(coalesce(schedule_done_raw, ''))) in ('true', 't', 'y', 'yes', '1', '완료'),
  partial_return_at = coalesce(partial_return_at, public.rc00_ops_parse_kst_datetime(partial_return_raw));

update public.rc00_ops_schedules
set schedule_type = '기타'
where schedule_type is null or btrim(schedule_type) = '';

alter table public.rc00_ops_schedules
  alter column schedule_type set not null;

create index if not exists idx_rc00_ops_schedules_schedule_at
  on public.rc00_ops_schedules (schedule_at);
create index if not exists idx_rc00_ops_schedules_schedule_done
  on public.rc00_ops_schedules (schedule_done);
create index if not exists idx_rc00_ops_schedules_schedule_type
  on public.rc00_ops_schedules (schedule_type);

alter table public.rc00_ops_cars
  add column if not exists start_at_ts timestamptz,
  add column if not exists end_at_ts timestamptz;

update public.rc00_ops_cars
set
  start_at_ts = coalesce(start_at_ts, public.rc00_ops_parse_kst_datetime(start_at)),
  end_at_ts = coalesce(end_at_ts, public.rc00_ops_parse_kst_datetime(end_at));

create index if not exists idx_rc00_ops_cars_start_at_ts
  on public.rc00_ops_cars (start_at_ts);
create index if not exists idx_rc00_ops_cars_end_at_ts
  on public.rc00_ops_cars (end_at_ts);

-- Existing reservation timestamptz values were created from local wall-clock input.
-- Reinterpret those UTC wall-clock components as Asia/Seoul local time once.
update public.rc00_ops_reservations
set
  start_at = case
    when start_at is null then null
    else make_timestamptz(
      extract(year from start_at at time zone 'UTC')::int,
      extract(month from start_at at time zone 'UTC')::int,
      extract(day from start_at at time zone 'UTC')::int,
      extract(hour from start_at at time zone 'UTC')::int,
      extract(minute from start_at at time zone 'UTC')::int,
      floor(extract(second from start_at at time zone 'UTC'))::int,
      'Asia/Seoul'
    )
  end,
  end_at = case
    when end_at is null then null
    else make_timestamptz(
      extract(year from end_at at time zone 'UTC')::int,
      extract(month from end_at at time zone 'UTC')::int,
      extract(day from end_at at time zone 'UTC')::int,
      extract(hour from end_at at time zone 'UTC')::int,
      extract(minute from end_at at time zone 'UTC')::int,
      floor(extract(second from end_at at time zone 'UTC'))::int,
      'Asia/Seoul'
    )
  end,
  updated_at = now()
where coalesce((meta_json->>'kst_reinterpreted_at'), '') = '';

update public.rc00_ops_reservations
set meta_json = coalesce(meta_json, '{}'::jsonb) || jsonb_build_object('kst_reinterpreted_at', now()::text)
where coalesce((meta_json->>'kst_reinterpreted_at'), '') = '';
