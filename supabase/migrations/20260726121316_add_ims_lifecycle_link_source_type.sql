alter table public.rc00_ops_external_reservation_links
  add column if not exists source_type text;

alter table public.rc00_ops_external_reservation_links
  drop constraint if exists rc00_ops_external_reservation_links_source_type_check;

alter table public.rc00_ops_external_reservation_links
  add constraint rc00_ops_external_reservation_links_source_type_check
  check (
    source_type is null
    or source_type in ('normal_schedule', 'insurance_claim')
  );

create index if not exists idx_rc00_ops_external_links_lifecycle_source
  on public.rc00_ops_external_reservation_links (
    provider,
    external_status,
    source_type,
    external_reservation_id
  );

comment on column public.rc00_ops_external_reservation_links.source_type
  is 'IMS lifecycle source discriminator. null means historical/untyped and is excluded from automatic lifecycle handling.';
