create or replace view public.rc00_ops_ims_binding_exceptions as
select
  external_reservation_id,
  count(*)::integer as binding_count,
  array_agg(reservation_id order by created_at, reservation_id) as reservation_ids,
  min(created_at) as first_bound_at,
  max(updated_at) as last_updated_at
from public.rc00_ops_external_reservation_links
where provider = 'ims'
  and external_status = 'linked'
  and external_reservation_id is not null
  and trim(external_reservation_id) <> ''
group by external_reservation_id
having count(*) > 1;

create or replace function public.enforce_future_unique_ims_binding()
returns trigger
language plpgsql
as $$
begin
  if new.provider <> 'ims'
     or new.external_status <> 'linked'
     or new.external_reservation_id is null
     or trim(new.external_reservation_id) = '' then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.provider = new.provider
     and old.external_status = new.external_status
     and old.external_reservation_id is not distinct from new.external_reservation_id
     and old.reservation_id = new.reservation_id then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.external_reservation_id, 0));

  if exists (
    select 1
    from public.rc00_ops_external_reservation_links existing
    where existing.provider = 'ims'
      and existing.external_status = 'linked'
      and existing.external_reservation_id = new.external_reservation_id
      and (tg_op = 'INSERT' or existing.id is distinct from new.id)
      and existing.reservation_id <> new.reservation_id
  ) then
    raise exception
      using
        errcode = '23505',
        message = 'ims_external_reservation_already_bound',
        detail = format(
          'IMS reservation %s is already linked to another OPS reservation',
          new.external_reservation_id
        );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_future_unique_ims_binding
  on public.rc00_ops_external_reservation_links;

create trigger trg_enforce_future_unique_ims_binding
before insert or update of provider, external_status, external_reservation_id, reservation_id
on public.rc00_ops_external_reservation_links
for each row
execute function public.enforce_future_unique_ims_binding();

comment on view public.rc00_ops_ims_binding_exceptions
  is 'Pre-existing duplicate IMS bindings retained as historical exceptions; new duplicates are blocked by trigger.';
