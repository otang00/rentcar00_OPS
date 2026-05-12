alter table public.rc00_ops_reservations
  add column if not exists customer_birth_date text,
  add column if not exists referral_source text,
  add column if not exists payment_amount text;
