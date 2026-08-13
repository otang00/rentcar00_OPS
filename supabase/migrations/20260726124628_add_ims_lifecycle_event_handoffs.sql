create table if not exists public.rc00_ops_ims_lifecycle_event_handoffs (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  event_type text not null,
  source_type text not null,
  external_id text not null,
  reservation_id text not null,
  schedule_id text,
  schedule_type text,
  car_number text,
  send_status text not null default 'pending',
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  next_attempt_at timestamptz,
  payload_json jsonb not null default '{}'::jsonb,
  response_json jsonb not null default '{}'::jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rc00_ops_ims_lifecycle_event_handoffs_event_id_unique
    unique (event_id),
  constraint rc00_ops_ims_lifecycle_event_handoffs_event_type_check
    check (
      event_type in (
        'ims.lifecycle.dispatch_detected',
        'ims.lifecycle.return_detected'
      )
    ),
  constraint rc00_ops_ims_lifecycle_event_handoffs_source_type_check
    check (source_type in ('normal_schedule', 'insurance_claim')),
  constraint rc00_ops_ims_lifecycle_event_handoffs_send_status_check
    check (
      send_status in (
        'pending',
        'sent',
        'applied',
        'already_applied',
        'manual_review',
        'failed',
        'failed_final'
      )
    ),
  constraint rc00_ops_ims_lifecycle_event_handoffs_attempt_count_check
    check (attempt_count >= 0)
);

create index if not exists idx_rc00_ops_ims_lifecycle_event_handoffs_external
  on public.rc00_ops_ims_lifecycle_event_handoffs (
    source_type,
    external_id,
    event_type
  );

create index if not exists idx_rc00_ops_ims_lifecycle_event_handoffs_reservation
  on public.rc00_ops_ims_lifecycle_event_handoffs (
    reservation_id,
    schedule_type
  );

create index if not exists idx_rc00_ops_ims_lifecycle_event_handoffs_status
  on public.rc00_ops_ims_lifecycle_event_handoffs (
    send_status,
    next_attempt_at,
    created_at
  );

alter table public.rc00_ops_ims_lifecycle_event_handoffs
  enable row level security;

comment on table public.rc00_ops_ims_lifecycle_event_handoffs
  is 'Sender-side lifecycle event handoff state for IMS using-car snapshot diff signals. Terminal statuses stop repeated sends.';
