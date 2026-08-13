create or replace function public.resolve_rc00_ops_reservation_cancellation_event(
  p_event_id text,
  p_resolution_status text,
  p_actor_id text default null,
  p_actor_name text default null,
  p_message_text text default null,
  p_candidate_reservation_id text default null,
  p_candidate_reservation_number text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.rc00_ops_reservation_events%rowtype;
  v_event_id text := btrim(coalesce(p_event_id, ''));
  v_resolution_status text := btrim(coalesce(p_resolution_status, ''));
  v_actor_id text := nullif(btrim(coalesce(p_actor_id, '')), '');
  v_actor_name text := nullif(btrim(coalesce(p_actor_name, '')), '');
  v_message text := nullif(btrim(coalesce(p_message_text, '')), '');
begin
  if auth.uid() is null then
    raise exception 'authenticated user required'
      using errcode = '42501';
  end if;

  if v_event_id = '' then
    raise exception 'event id is required'
      using errcode = '22023';
  end if;

  if v_resolution_status not in (
    'resolved_orphan_confirmed',
    'resolved_reservation_cancelled',
    'resolved_not_actionable'
  ) then
    raise exception 'unsupported reservation cancellation resolution status: %', v_resolution_status
      using errcode = '22023';
  end if;

  update public.rc00_ops_reservation_events
     set status = v_resolution_status,
         processed_at = now(),
         error_message = null,
         updated_at = now()
   where event_id = v_event_id
     and event_type = 'reservation.cancelled'
     and status in ('pending_review', 'received')
   returning *
    into v_event;

  if not found then
    raise exception 'pending reservation cancellation event not found: %', v_event_id
      using errcode = 'P0002';
  end if;

  insert into public.rc00_ops_action_logs (
    target_type,
    target_ref,
    action_key,
    action_label,
    actor_id,
    actor_name,
    message_text,
    result_status,
    meta_json
  )
  values (
    'reservation_event',
    v_event.event_id,
    'reservation_cancellation_notice.resolve',
    case v_resolution_status
      when 'resolved_orphan_confirmed' then '취소 이벤트 연결 예약 없음 확인'
      when 'resolved_reservation_cancelled' then '취소 이벤트 예약 취소 처리 확인'
      else '취소 이벤트 조치 불필요 확인'
    end,
    coalesce(v_actor_id, auth.uid()::text),
    coalesce(v_actor_name, v_actor_id, auth.uid()::text),
    coalesce(v_message, ''),
    'success',
    jsonb_strip_nulls(jsonb_build_object(
      'eventId', v_event.event_id,
      'eventType', v_event.event_type,
      'provider', coalesce(
        v_event.payload_json #>> '{provider}',
        v_event.payload_json #>> '{booking,sourceProvider}',
        v_event.payload_json #>> '{reservationInput,sourceProvider}'
      ),
      'sourceReservationId', coalesce(
        v_event.payload_json #>> '{booking,sourceReservationId}',
        v_event.payload_json #>> '{booking,externalReservationId}',
        v_event.payload_json #>> '{booking,external_reservation_id}',
        v_event.payload_json #>> '{reservationInput,sourceReservationId}',
        v_event.payload_json #>> '{reservationInput,externalReservationId}',
        v_event.payload_json #>> '{reservationInput,external_reservation_id}'
      ),
      'resolutionStatus', v_resolution_status,
      'candidateReservationId', nullif(btrim(coalesce(p_candidate_reservation_id, '')), ''),
      'candidateReservationNumber', nullif(btrim(coalesce(p_candidate_reservation_number, '')), '')
    ))
  );

  return jsonb_build_object(
    'eventId', v_event.event_id,
    'eventType', v_event.event_type,
    'status', v_event.status,
    'processedAt', v_event.processed_at,
    'updatedAt', v_event.updated_at
  );
end;
$$;

revoke all on function public.resolve_rc00_ops_reservation_cancellation_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text
) from public;

grant execute on function public.resolve_rc00_ops_reservation_cancellation_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;
