alter table public.rc00_ops_staff_accounts
  add column if not exists phone_number text,
  add column if not exists last_activity_at timestamptz,
  add column if not exists last_location_text text,
  add column if not exists last_lat double precision,
  add column if not exists last_lng double precision;

create table if not exists public.rc00_ops_staff_passwords (
  staff_account_id uuid primary key references public.rc00_ops_staff_accounts(id) on delete cascade,
  password_text text not null,
  updated_at timestamptz not null default now()
);

alter table public.rc00_ops_staff_passwords enable row level security;

create or replace function public.rc00_ops_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rc00_ops_staff_accounts
    where auth_user_id = auth.uid()
      and role = 'admin'
      and is_active = true
  );
$$;

create or replace function public.rc00_ops_mark_current_staff_activity()
returns void
language sql
security definer
set search_path = public
as $$
  update public.rc00_ops_staff_accounts
  set last_activity_at = now(),
      last_login_at = now(),
      updated_at = now()
  where auth_user_id = auth.uid();
$$;

drop policy if exists rc00_ops_staff_accounts_select_admin on public.rc00_ops_staff_accounts;
create policy rc00_ops_staff_accounts_select_admin
  on public.rc00_ops_staff_accounts
  for select
  to authenticated
  using (public.rc00_ops_is_admin());

drop policy if exists rc00_ops_staff_accounts_update_admin on public.rc00_ops_staff_accounts;
create policy rc00_ops_staff_accounts_update_admin
  on public.rc00_ops_staff_accounts
  for update
  to authenticated
  using (public.rc00_ops_is_admin())
  with check (public.rc00_ops_is_admin());

drop policy if exists rc00_ops_staff_passwords_select_admin on public.rc00_ops_staff_passwords;
create policy rc00_ops_staff_passwords_select_admin
  on public.rc00_ops_staff_passwords
  for select
  to authenticated
  using (public.rc00_ops_is_admin());

drop policy if exists rc00_ops_staff_passwords_all_admin on public.rc00_ops_staff_passwords;
create policy rc00_ops_staff_passwords_all_admin
  on public.rc00_ops_staff_passwords
  for all
  to authenticated
  using (public.rc00_ops_is_admin())
  with check (public.rc00_ops_is_admin());

update public.rc00_ops_staff_accounts
set role = case when login_id = 'rentcar00' then 'admin' else 'staff' end,
    updated_at = now();
