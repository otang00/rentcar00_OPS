alter table public.rc00_ops_fine_notices
  drop constraint if exists rc00_ops_fine_notices_status_check;

alter table public.rc00_ops_fine_notices
  add constraint rc00_ops_fine_notices_status_check
  check (status in (
    'draft',
    'review_needed',
    'ready_for_contract_search',
    'contract_candidates_ready',
    'contract_confirmed',
    'document_ready',
    'submission_ready',
    'submitted',
    'on_hold',
    'not_our_vehicle'
  ));
