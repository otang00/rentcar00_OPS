do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rc00_ops_reservations'
  ) then
    alter publication supabase_realtime add table public.rc00_ops_reservations;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rc00_ops_reservation_states'
  ) then
    alter publication supabase_realtime add table public.rc00_ops_reservation_states;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rc00_ops_schedules'
  ) then
    alter publication supabase_realtime add table public.rc00_ops_schedules;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rc00_ops_cars'
  ) then
    alter publication supabase_realtime add table public.rc00_ops_cars;
  end if;
end $$;
