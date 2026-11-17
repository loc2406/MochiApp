-- Record the most recent overview fetch and group active grants by email.
alter table public.mochi_student_viewers
  add column if not exists last_accessed_at timestamptz;

create or replace function public.mochi_fetch_student_overview(viewer_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  state_json jsonb;
  student_name text;
  grade text;
  student_uuid uuid;
  viewer_uuid uuid;
  viewer_role_value text;
begin
  select v.id, v.student_id, v.viewer_role
  into viewer_uuid, student_uuid, viewer_role_value
  from public.mochi_student_viewers v
  where v.session_hash = encode(extensions.digest(convert_to(viewer_token, 'UTF8'), 'sha256'), 'hex')
    and v.revoked_at is null;

  if student_uuid is null then raise exception 'viewer_access_revoked'; end if;

  select s.state into state_json
  from public.mochi_account_state s where s.user_id = student_uuid;
  if state_json is null then raise exception 'student_data_unavailable'; end if;

  update public.mochi_student_viewers
  set last_accessed_at = now()
  where id = viewer_uuid;

  student_name := coalesce(state_json #>> '{profile,name}', 'Học sinh');
  grade := coalesce(state_json #>> '{learning,gradeLevel}', state_json #>> '{profile,gradeBand}', '');
  return jsonb_build_object(
    'studentName', student_name,
    'grade', grade,
    'viewerRole', viewer_role_value,
    'xp', coalesce(state_json->'xp', '0'::jsonb),
    'currentStreak', coalesce(state_json->'currentStreak', '0'::jsonb),
    'totalStudyMinutes', coalesce(state_json->'totalStudyMinutes', '0'::jsonb),
    'goals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'title', g->>'title', 'subject', g->>'subject',
        'isDone', coalesce(g->'isDone', 'false'::jsonb),
        'targetDate', g->>'targetDate'
      )) from jsonb_array_elements(coalesce(state_json->'goals','[]'::jsonb)) g
    ), '[]'::jsonb),
    'courses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c->>'id', 'subject', c->>'subject',
        'topics', coalesce((
          select jsonb_agg(jsonb_build_object('id', t->>'id', 'title', t->>'title'))
          from jsonb_array_elements(coalesce(c->'topics','[]'::jsonb)) t
        ), '[]'::jsonb)
      )) from jsonb_array_elements(coalesce(state_json #> '{learning,courses}','[]'::jsonb)) c
    ), '[]'::jsonb),
    'progress', coalesce(state_json #> '{learning,progress}', '[]'::jsonb),
    'recentStudy', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', x->>'startedAt',
        'durationMinutes', coalesce(((x->>'activeSeconds')::numeric / 60)::int, 0)
      ) order by x->>'startedAt' desc)
      from (
        select value x from jsonb_array_elements(coalesce(state_json->'sessions','[]'::jsonb))
        order by value->>'startedAt' desc limit 14
      ) recent
    ), '[]'::jsonb)
  );
end $$;

create or replace function public.mochi_list_student_viewers()
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', id,
      'email', viewer_email,
      'role', viewer_role,
      'createdAt', created_at,
      'lastViewedAt', last_accessed_at
    ) order by created_at desc)
    from (
      select distinct on (viewer_email)
        id, viewer_email, viewer_role, created_at, last_accessed_at
      from public.mochi_student_viewers
      where student_id = auth.uid() and revoked_at is null
      order by viewer_email, last_accessed_at desc nulls last, created_at desc
    ) latest_viewer
  ), '[]'::jsonb);
end $$;

create or replace function public.mochi_revoke_student_viewer(viewer_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update public.mochi_student_viewers set revoked_at = now()
  where student_id = auth.uid() and revoked_at is null
    and viewer_email = (
      select target.viewer_email from public.mochi_student_viewers target
      where target.id = viewer_id and target.student_id = auth.uid()
    );
end $$;

revoke all on function public.mochi_fetch_student_overview(text), public.mochi_list_student_viewers(), public.mochi_revoke_student_viewer(uuid) from public;
grant execute on function public.mochi_fetch_student_overview(text) to anon, authenticated;
grant execute on function public.mochi_list_student_viewers(), public.mochi_revoke_student_viewer(uuid) to authenticated;
