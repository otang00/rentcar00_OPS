create table if not exists public.rc00_ops_external_reservation_links (
  id uuid primary key default gen_random_uuid(),
  reservation_id text not null,
  reservation_ref_id uuid references public.rc00_ops_reservations(id) on delete cascade,
  provider text not null default 'ims',
  external_reservation_id text,
  external_detail_id text,
  external_status text not null default 'linked',
  link_key text not null,
  last_payload_json jsonb not null default '{}'::jsonb,
  last_result_json jsonb not null default '{}'::jsonb,
  linked_at timestamptz,
  last_checked_at timestamptz,
  deleted_at timestamptz,
  error_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rc00_ops_external_reservation_links_provider_check
    check (provider in ('ims')),
  constraint rc00_ops_external_reservation_links_status_check
    check (external_status in ('linked', 'failed', 'deleted')),
  constraint rc00_ops_external_reservation_links_link_key_check
    check (length(trim(link_key)) > 0),
  constraint rc00_ops_external_reservation_links_provider_reservation_unique
    unique (provider, reservation_id)
);

create index if not exists idx_rc00_ops_external_links_reservation_id
  on public.rc00_ops_external_reservation_links (reservation_id);

create index if not exists idx_rc00_ops_external_links_reservation_ref_id
  on public.rc00_ops_external_reservation_links (reservation_ref_id);

create index if not exists idx_rc00_ops_external_links_provider_external_id
  on public.rc00_ops_external_reservation_links (provider, external_reservation_id);

create index if not exists idx_rc00_ops_external_links_link_key
  on public.rc00_ops_external_reservation_links (link_key);

create index if not exists idx_rc00_ops_external_links_status
  on public.rc00_ops_external_reservation_links (provider, external_status);

alter table public.rc00_ops_external_reservation_links enable row level security;

drop policy if exists rc00_ops_external_reservation_links_authenticated_all
  on public.rc00_ops_external_reservation_links;
create policy rc00_ops_external_reservation_links_authenticated_all
  on public.rc00_ops_external_reservation_links
  for all
  to authenticated
  using (true)
  with check (true);
