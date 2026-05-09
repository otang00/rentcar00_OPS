drop index if exists public.idx_rc00_ops_reservation_states_status_key;

alter table if exists public.rc00_ops_reservation_states
  drop column if exists status_key,
  drop column if exists auto_tab_key,
  drop column if exists auto_status_key,
  drop column if exists manual_override;
