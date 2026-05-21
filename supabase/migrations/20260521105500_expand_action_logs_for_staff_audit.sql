alter table public.rc00_ops_action_logs
  alter column reservation_id drop not null,
  alter column reservation_ref_id drop not null,
  add column if not exists target_type text not null default 'reservation',
  add column if not exists target_ref text,
  add column if not exists car_number text,
  add column if not exists reservation_number text,
  add column if not exists action_label text;

create index if not exists idx_rc00_ops_action_logs_target
  on public.rc00_ops_action_logs (target_type, target_ref);

create index if not exists idx_rc00_ops_action_logs_actor_id
  on public.rc00_ops_action_logs (actor_id);
