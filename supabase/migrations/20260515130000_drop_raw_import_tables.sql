-- Drop Google Sheets raw/import history after canonical DB source-of-truth migration.

alter table if exists public.rc00_ops_cars
  drop column if exists source_import_run_id,
  drop column if exists source_car_raw_id;

alter table if exists public.rc00_ops_schedules
  drop column if exists source_import_run_id,
  drop column if exists source_schedule_raw_id;

alter table if exists public.rc00_ops_schedules
  drop column if exists schedule_type_raw,
  drop column if exists schedule_at_raw,
  drop column if exists schedule_done_raw,
  drop column if exists partial_return_raw;

drop table if exists public.rc00_ops_reservations_raw cascade;
drop table if exists public.rc00_ops_schedules_raw cascade;
drop table if exists public.rc00_ops_cars_raw cascade;
drop table if exists public.rc00_ops_import_runs cascade;
