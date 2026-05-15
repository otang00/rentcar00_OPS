alter table public.rc00_ops_external_reservation_links
  drop constraint if exists rc00_ops_external_reservation_links_status_check;

alter table public.rc00_ops_external_reservation_links
  add constraint rc00_ops_external_reservation_links_status_check
  check (external_status in ('linked', 'failed', 'deleted', 'unlinked'));
