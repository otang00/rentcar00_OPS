alter table public.rc00_ops_reservations
  drop column if exists source_sync_run_id,
  drop column if exists source_reservation_raw_id,
  drop column if exists primary_schedule_raw_id;
