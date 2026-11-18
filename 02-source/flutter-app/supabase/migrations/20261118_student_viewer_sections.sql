-- Per-email section permissions for student viewers.
-- Existing grants default to every section so behaviour stays unchanged until
-- the student edits the checkboxes.

alter table public.mochi_student_viewers
  add column if not exists shared_sections text[];

update public.mochi_student_viewers
set shared_sections = array[
  'profile', 'xp', 'streak', 'studyMinutes',
  'goals', 'courses', 'progress', 'recentStudy'
]::text[]
where shared_sections is null;

alter table public.mochi_student_viewers
  alter column shared_sections
    set default array[
      'profile', 'xp', 'streak', 'studyMinutes',
      'goals', 'courses', 'progress', 'recentStudy'
    ]::text[],
  alter column shared_sections set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'mochi_student_viewers_sections_check'
      and conrelid = 'public.mochi_student_viewers'::regclass
  ) then
    alter table public.mochi_student_viewers
      add constraint mochi_student_viewers_sections_check
      check (
        shared_sections <@ array[
          'profile', 'xp', 'streak', 'studyMinutes',
          'goals', 'courses', 'progress', 'recentStudy'
        ]::text[]
      );
  end if;
end $$;

-- A newly redeemed code inherits the last saved section choices for this
-- email, so issuing a fresh code does not silently re-enable hidden data.
create or replace function public.mochi_redeem_student_invite(viewer_email text, invite_code text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  invite_row public.mochi_student_invites%rowtype;
  session_token text;
  inherited_sections text[];
begin
  if lower(trim(viewer_email)) = '' or position('@' in lower(trim(viewer_email))) < 2 then
    raise exception 'invalid_invite';
  end if;

  select * into invite_row
  from public.mochi_student_invites
  where recipient_email = lower(trim(viewer_email))
    and code_hash = encode(extensions.digest(convert_to(invite_code, 'UTF8'), 'sha256'), 'hex')
  for update;

  if not found then raise exception 'invalid_invite'; end if;
  if invite_row.redeemed_at is not null then raise exception 'invalid_invite'; end if;
  if invite_row.expires_at <= now() then
    raise exception using errcode = 'P0001', message = 'invite_expired';
  end if;

  select v.shared_sections into inherited_sections
  from public.mochi_student_viewers v
  where v.student_id = invite_row.student_id
    and v.viewer_email = invite_row.recipient_email
  order by v.created_at desc
  limit 1;

  session_token := translate(encode(extensions.gen_random_bytes(32), 'base64'), E'+/=\n', '-_');
  update public.mochi_student_invites set redeemed_at = now() where id = invite_row.id;
  insert into public.mochi_student_viewers(
    student_id, viewer_email, viewer_role, session_hash, shared_sections
  )
  values (
    invite_row.student_id,
    invite_row.recipient_email,
    invite_row.viewer_role,
    encode(extensions.digest(convert_to(session_token, 'UTF8'), 'sha256'), 'hex'),
    coalesce(inherited_sections, array[
      'profile', 'xp', 'streak', 'studyMinutes',
      'goals', 'courses', 'progress', 'recentStudy'
    ]::text[])
  );
  return jsonb_build_object('session_token', session_token, 'role', invite_row.viewer_role);
end $$;

-- Only return the blocks the student has allowed for this viewer.
create or replace function public.mochi_fetch_student_overview(viewer_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  state_json jsonb;
  student_name text;
  grade text;
  student_uuid uuid;
  viewer_uuid uuid;
  viewer_role_value text;
  viewer_sections text[];
begin
  select
    v.id,
    v.student_id,
    v.viewer_role,
    v.shared_sections
  into viewer_uuid, student_uuid, viewer_role_value, viewer_sections
  from public.mochi_student_viewers v
  where v.session_hash = encode(extensions.digest(convert_to(viewer_token, 'UTF8'), 'sha256'), 'hex')
    and v.revoked_at is null;

  if student_uuid is null then raise exception 'viewer_access_revoked'; end if;
  if viewer_sections is null then
    viewer_sections := array[
      'profile', 'xp', 'streak', 'studyMinutes',
      'goals', 'courses', 'progress', 'recentStudy'
    ]::text[];
  end if;

  select s.state into state_json
  from public.mochi_account_state s where s.user_id = student_uuid;
  if state_json is null then raise exception 'student_data_unavailable'; end if;

  update public.mochi_student_viewers
  set last_accessed_at = now()
  where id = viewer_uuid;

  student_name := case
    when 'profile' = any(viewer_sections)
      then coalesce(state_json #>> '{profile,name}', 'Học sinh')
    else null
  end;
  grade := case
    when 'profile' = any(viewer_sections)
      then coalesce(state_json #>> '{learning,gradeLevel}', state_json #>> '{profile,gradeBand}', '')
    else ''
  end;

  return jsonb_build_object(
    'studentName', student_name,
    'grade', grade,
    'viewerRole', viewer_role_value,
    'sharedSections', to_jsonb(viewer_sections),
    'xp', case
      when 'xp' = any(viewer_sections) then coalesce(state_json->'xp', '0'::jsonb)
      else null
    end,
    'currentStreak', case
      when 'streak' = any(viewer_sections) then coalesce(state_json->'currentStreak', '0'::jsonb)
      else null
    end,
    'totalStudyMinutes', case
      when 'studyMinutes' = any(viewer_sections) then coalesce(state_json->'totalStudyMinutes', '0'::jsonb)
      else null
    end,
    'goals', case
      when 'goals' = any(viewer_sections) then coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', g->>'title', 'subject', g->>'subject',
          'isDone', coalesce(g->'isDone', 'false'::jsonb),
          'targetDate', g->>'targetDate'
        )) from jsonb_array_elements(coalesce(state_json->'goals','[]'::jsonb)) g
      ), '[]'::jsonb)
      else '[]'::jsonb
    end,
    'courses', case
      when 'courses' = any(viewer_sections) then coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', c->>'id', 'subject', c->>'subject',
          'topics', coalesce((
            select jsonb_agg(jsonb_build_object('id', t->>'id', 'title', t->>'title'))
            from jsonb_array_elements(coalesce(c->'topics','[]'::jsonb)) t
          ), '[]'::jsonb)
        )) from jsonb_array_elements(coalesce(state_json #> '{learning,courses}','[]'::jsonb)) c
      ), '[]'::jsonb)
      else '[]'::jsonb
    end,
    'progress', case
      when 'progress' = any(viewer_sections) then coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p->>'id',
          'courseId', p->>'courseId',
          'topicId', p->>'topicId',
          'readiness', p->>'readiness',
          'updatedAt', p->>'updatedAt',
          'topicTitle', coalesce((
            select t->>'title'
            from jsonb_array_elements(coalesce(c.course->'topics','[]'::jsonb)) t
            where t->>'id' = p->>'topicId'
            limit 1
          ), 'Chủ đề'),
          'subject', coalesce(c.course->>'subject', 'Chung')
        ))
        from jsonb_array_elements(coalesce(state_json #> '{learning,progress}','[]'::jsonb)) p
        left join lateral (
          select course
          from jsonb_array_elements(coalesce(state_json #> '{learning,courses}','[]'::jsonb)) course
          where course->>'id' = p->>'courseId'
          limit 1
        ) c on true
      ), '[]'::jsonb)
      else '[]'::jsonb
    end,
    'recentStudy', case
      when 'recentStudy' = any(viewer_sections) then coalesce((
        select jsonb_agg(jsonb_build_object(
          'date', x->>'startedAt',
          'durationMinutes', coalesce(((x->>'activeSeconds')::numeric / 60)::int, 0)
        ) order by x->>'startedAt' desc)
        from (
          select value x from jsonb_array_elements(coalesce(state_json->'sessions','[]'::jsonb))
          order by value->>'startedAt' desc limit 14
        ) recent
      ), '[]'::jsonb)
      else '[]'::jsonb
    end
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
      'lastViewedAt', last_accessed_at,
      'sections', to_jsonb(shared_sections)
    ) order by created_at desc)
    from (
      select distinct on (viewer_email)
        id, viewer_email, viewer_role, created_at, last_accessed_at, shared_sections
      from public.mochi_student_viewers
      where student_id = auth.uid() and revoked_at is null
      order by viewer_email, last_accessed_at desc nulls last, created_at desc
    ) latest_viewer
  ), '[]'::jsonb);
end $$;

-- Update every active grant for the same email: permissions are per email,
-- matching how revocation already works.
create or replace function public.mochi_set_student_viewer_sections(viewer_id uuid, sections text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  target_email text;
  cleaned text[];
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if sections is null then sections := '{}'::text[]; end if;

  if exists (
    select 1 from unnest(sections) s
    where s is null or s not in (
      'profile', 'xp', 'streak', 'studyMinutes',
      'goals', 'courses', 'progress', 'recentStudy'
    )
  ) then
    raise exception 'invalid_sections';
  end if;

  select v.viewer_email into target_email
  from public.mochi_student_viewers v
  where v.id = viewer_id and v.student_id = auth.uid();

  if target_email is null then raise exception 'viewer_not_found'; end if;

  select coalesce(array_agg(distinct s), '{}'::text[])
  into cleaned
  from unnest(sections) s;

  update public.mochi_student_viewers
  set shared_sections = cleaned
  where student_id = auth.uid()
    and viewer_email = target_email
    and revoked_at is null;

  return jsonb_build_object('email', target_email, 'sections', to_jsonb(cleaned));
end $$;

revoke all on function public.mochi_redeem_student_invite(text,text), public.mochi_fetch_student_overview(text), public.mochi_list_student_viewers(), public.mochi_set_student_viewer_sections(uuid,text[]) from public;
grant execute on function public.mochi_redeem_student_invite(text,text), public.mochi_fetch_student_overview(text) to anon, authenticated;
grant execute on function public.mochi_list_student_viewers(), public.mochi_set_student_viewer_sections(uuid,text[]) to authenticated;
