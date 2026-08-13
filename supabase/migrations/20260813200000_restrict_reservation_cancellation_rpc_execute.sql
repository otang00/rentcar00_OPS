revoke execute on function public.resolve_rc00_ops_reservation_cancellation_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text
) from public;

revoke execute on function public.resolve_rc00_ops_reservation_cancellation_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text
) from anon;

grant execute on function public.resolve_rc00_ops_reservation_cancellation_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;
