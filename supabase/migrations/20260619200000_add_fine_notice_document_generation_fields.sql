alter table public.rc00_ops_fine_notices
  add column if not exists source_batch_id uuid,
  add column if not exists source_row_index integer,
  add column if not exists source_row_count integer,
  add column if not exists document_list_group_key text,

  add column if not exists outbound_document_number text,
  add column if not exists outbound_document_issued_date date,

  add column if not exists renter_name text,
  add column if not exists renter_phone text,
  add column if not exists renter_address text,
  add column if not exists renter_identity_type text,
  add column if not exists renter_identity_no text,
  add column if not exists renter_driver_license_no text,
  add column if not exists renter_birth_date text,
  add column if not exists renter_snapshot_source text,
  add column if not exists renter_snapshot_confirmed_at timestamptz,

  add column if not exists contract_pdf_saved_at timestamptz,
  add column if not exists document_package_generated_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'rc00_ops_fine_notices_renter_identity_type_check'
      and conrelid = 'public.rc00_ops_fine_notices'::regclass
  ) then
    alter table public.rc00_ops_fine_notices
      add constraint rc00_ops_fine_notices_renter_identity_type_check
      check (
        renter_identity_type is null
        or renter_identity_type in (
          'resident_registration',
          'driver_license',
          'birth_date_only',
          'unknown'
        )
      );
  end if;
end $$;

create index if not exists idx_rc00_ops_fine_notices_source_batch_id
  on public.rc00_ops_fine_notices (source_batch_id);

create index if not exists idx_rc00_ops_fine_notices_document_list_group_key
  on public.rc00_ops_fine_notices (document_list_group_key);

create index if not exists idx_rc00_ops_fine_notices_document_package_generated_at
  on public.rc00_ops_fine_notices (document_package_generated_at);
