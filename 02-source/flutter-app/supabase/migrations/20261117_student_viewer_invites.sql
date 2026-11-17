-- Single-use, email-bound invitation codes and revocable viewer sessions.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.mochi_student_invites (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users(id) on delete cascade,
  recipient_email text not null,
  viewer_role text not null check (viewer_role in ('parent', 'teacher')),
  code_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  redeemed_at timestamptz
);
create table if not exists public.mochi_student_viewers (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users(id) on delete cascade,
  viewer_email text not null,
  viewer_role text not null check (viewer_role in ('parent', 'teacher')),
  session_hash text not null unique,
  created_at timestamptz not null default now(),
  last_accessed_at timestamptz,
  revoked_at timestamptz
);
alter table public.mochi_student_invites enable row level security;
alter table public.mochi_student_viewers enable row level security;
revoke all on public.mochi_student_invites, public.mochi_student_viewers from anon, authenticated, public;

create or replace function public.mochi_create_student_invite(recipient_email text, viewer_role text, invite_code text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare normalized_email text := lower(trim(recipient_email));
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if normalized_email = '' or position('@' in normalized_email) < 2 then raise exception 'invalid_email'; end if;
  if viewer_role not in ('parent', 'teacher') then raise exception 'invalid_role'; end if;
  if length(invite_code) < 32 then raise exception 'invalid_code'; end if;
  insert into public.mochi_student_invites(student_id, recipient_email, viewer_role, code_hash)
  values (auth.uid(), normalized_email, viewer_role, encode(extensions.digest(convert_to(invite_code, 'UTF8'), 'sha256'), 'hex'));
  return invite_code;
end $$;

create or replace function public.mochi_redeem_student_invite(viewer_email text, invite_code text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare invite_row public.mochi_student_invites%rowtype; session_token text;
begin
  if lower(trim(viewer_email)) = '' or position('@' in lower(trim(viewer_email))) < 2 then raise exception 'invalid_invite'; end if;
  select * into invite_row from public.mochi_student_invites
    where recipient_email = lower(trim(viewer_email))
      and code_hash = encode(extensions.digest(convert_to(invite_code, 'UTF8'), 'sha256'), 'hex')
    for update;
  if not found then raise exception 'invalid_invite'; end if;
  if invite_row.redeemed_at is not null then raise exception 'invalid_invite'; end if;
  if invite_row.expires_at <= now() then
    raise exception using errcode = 'P0001', message = 'invite_expired';
  end if;
  session_token := translate(encode(extensions.gen_random_bytes(32), 'base64'), E'+/=\n', '-_');
  update public.mochi_student_invites set redeemed_at = now() where id = invite_row.id;
  insert into public.mochi_student_viewers(student_id, viewer_email, viewer_role, session_hash)
  values (invite_row.student_id, invite_row.recipient_email, invite_row.viewer_role,
    encode(extensions.digest(convert_to(session_token, 'UTF8'), 'sha256'), 'hex'));
  return jsonb_build_object('session_token', session_token, 'role', invite_row.viewer_role);
end $$;

create or replace function public.mochi_fetch_student_overview(viewer_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare state_json jsonb; student_name text; grade text; student_uuid uuid; viewer_uuid uuid; viewer_role_value text;
begin
  select v.id, v.student_id, v.viewer_role into viewer_uuid, student_uuid, viewer_role_value from public.mochi_student_viewers v
  where v.session_hash = encode(extensions.digest(convert_to(viewer_token, 'UTF8'), 'sha256'), 'hex') and v.revoked_at is null;
  if student_uuid is null then raise exception 'viewer_access_revoked'; end if;
  select s.state into state_json from public.mochi_account_state s where s.user_id = student_uuid;
  if state_json is null then raise exception 'student_data_unavailable'; end if;
  update public.mochi_student_viewers set last_accessed_at = now() where id = viewer_uuid;
  student_name := coalesce(state_json #>> '{profile,name}', 'Học sinh');
  grade := coalesce(state_json #>> '{learning,gradeLevel}', state_json #>> '{profile,gradeBand}', '');
  return jsonb_build_object(
    'studentName', student_name, 'grade', grade, 'viewerRole', viewer_role_value,
    'xp', coalesce(state_json->'xp', '0'::jsonb),
    'currentStreak', coalesce(state_json->'currentStreak', '0'::jsonb),
    'totalStudyMinutes', coalesce(state_json->'totalStudyMinutes', '0'::jsonb),
    'goals', coalesce((select jsonb_agg(jsonb_build_object('title', g->>'title', 'subject', g->>'subject', 'isDone', coalesce(g->'isDone', 'false'::jsonb), 'targetDate', g->>'targetDate')) from jsonb_array_elements(coalesce(state_json->'goals','[]'::jsonb)) g), '[]'::jsonb),
    'courses', coalesce((select jsonb_agg(jsonb_build_object(
      'id', c->>'id', 'subject', c->>'subject', 'topics',
      coalesce((select jsonb_agg(jsonb_build_object('id', t->>'id', 'title', t->>'title')) from jsonb_array_elements(coalesce(c->'topics','[]'::jsonb)) t), '[]'::jsonb)
    )) from jsonb_array_elements(coalesce(state_json #> '{learning,courses}','[]'::jsonb)) c), '[]'::jsonb),
    'progress', coalesce(state_json #> '{learning,progress}', '[]'::jsonb),
    'recentStudy', coalesce((select jsonb_agg(jsonb_build_object('date', x->>'startedAt', 'durationMinutes', coalesce(((x->>'activeSeconds')::numeric / 60)::int, 0)) order by x->>'startedAt' desc)
      from (select value x from jsonb_array_elements(coalesce(state_json->'sessions','[]'::jsonb)) order by value->>'startedAt' desc limit 14) recent), '[]'::jsonb)
  );
end $$;

create or replace function public.mochi_list_student_viewers()
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'email', viewer_email, 'role', viewer_role, 'createdAt', created_at, 'lastViewedAt', last_accessed_at) order by created_at desc)
    from (select distinct on (viewer_email) id, viewer_email, viewer_role, created_at, last_accessed_at
      from public.mochi_student_viewers where student_id = auth.uid() and revoked_at is null
      order by viewer_email, last_accessed_at desc nulls last, created_at desc) latest_viewer), '[]'::jsonb);
end $$;

create or replace function public.mochi_revoke_student_viewer(viewer_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  update public.mochi_student_viewers set revoked_at = now()
    where student_id = auth.uid() and revoked_at is null
      and viewer_email = (select target.viewer_email from public.mochi_student_viewers target
        where target.id = viewer_id and target.student_id = auth.uid());
end $$;

revoke all on function public.mochi_create_student_invite(text,text,text), public.mochi_redeem_student_invite(text,text), public.mochi_fetch_student_overview(text), public.mochi_list_student_viewers(), public.mochi_revoke_student_viewer(uuid) from public;
grant execute on function public.mochi_create_student_invite(text,text,text), public.mochi_list_student_viewers(), public.mochi_revoke_student_viewer(uuid) to authenticated;
grant execute on function public.mochi_redeem_student_invite(text,text), public.mochi_fetch_student_overview(text) to anon, authenticated;
