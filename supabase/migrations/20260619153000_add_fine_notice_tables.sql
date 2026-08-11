create table if not exists public.rc00_ops_fine_notices (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'draft',
  notice_profile text not null default 'unknown_notice',
  notice_type text,
  issuer text,
  document_number text,
  car_number text not null,
  occurred_at_text text not null,
  occurred_at timestamptz,
  location text,
  total_amount_text text,
  total_amount numeric,
  due_date_text text,
  memo text,
  raw_candidate_json jsonb not null default '{}'::jsonb,
  review_warnings jsonb not null default '[]'::jsonb,
  confirmed_contract_source_type text,
  ims_contract_id text,
  ims_claim_id text,
  renter_snapshot_json jsonb not null default '{}'::jsonb,
  contract_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rc00_ops_fine_notices_status_check
    check (status in (
      'draft',
      'review_needed',
      'ready_for_contract_search',
      'contract_candidates_ready',
      'contract_confirmed',
      'document_ready',
      'submission_ready',
      'submitted',
      'on_hold'
    )),
  constraint rc00_ops_fine_notices_contract_source_check
    check (
      confirmed_contract_source_type is null
      or confirmed_contract_source_type in (
        'ims_normal_contract',
        'ims_insurance_claim'
      )
    )
);

create index if not exists idx_rc00_ops_fine_notices_status
  on public.rc00_ops_fine_notices (status);

create index if not exists idx_rc00_ops_fine_notices_car_number
  on public.rc00_ops_fine_notices (car_number);

create index if not exists idx_rc00_ops_fine_notices_occurred_at
  on public.rc00_ops_fine_notices (occurred_at);

create index if not exists idx_rc00_ops_fine_notices_occurred_at_text
  on public.rc00_ops_fine_notices (occurred_at_text);

create index if not exists idx_rc00_ops_fine_notices_notice_profile
  on public.rc00_ops_fine_notices (notice_profile);

create index if not exists idx_rc00_ops_fine_notices_contract_source
  on public.rc00_ops_fine_notices (confirmed_contract_source_type);

create table if not exists public.rc00_ops_fine_notice_files (
  id uuid primary key default gen_random_uuid(),
  fine_notice_id uuid not null references public.rc00_ops_fine_notices(id) on delete cascade,
  file_role text not null,
  local_path text not null,
  sha256 text,
  mime_type text,
  size_bytes bigint,
  source_type text,
  parser_request_id text,
  backup_status text not null default 'not_required',
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint rc00_ops_fine_notice_files_role_check
    check (file_role in (
      'notice_original',
      'contract_original',
      'contract_with_stamps',
      'renter_change_application',
      'vehicle_application_list',
      'submission_bundle_pdf',
      'submission_receipt'
    )),
  constraint rc00_ops_fine_notice_files_backup_status_check
    check (backup_status in (
      'not_required',
      'pending',
      'backed_up',
      'failed'
    ))
);

create index if not exists idx_rc00_ops_fine_notice_files_notice_id
  on public.rc00_ops_fine_notice_files (fine_notice_id);

create index if not exists idx_rc00_ops_fine_notice_files_role
  on public.rc00_ops_fine_notice_files (fine_notice_id, file_role);

alter table public.rc00_ops_fine_notices enable row level security;
alter table public.rc00_ops_fine_notice_files enable row level security;

drop policy if exists rc00_ops_fine_notices_authenticated_all
  on public.rc00_ops_fine_notices;
create policy rc00_ops_fine_notices_authenticated_all
  on public.rc00_ops_fine_notices
  for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists rc00_ops_fine_notice_files_authenticated_all
  on public.rc00_ops_fine_notice_files;
create policy rc00_ops_fine_notice_files_authenticated_all
  on public.rc00_ops_fine_notice_files
  for all
  to authenticated
  using (true)
  with check (true);
