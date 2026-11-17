-- Existing projects receive the five-minute lifetime without recreating tables.
alter table public.mochi_student_invites
  add column if not exists expires_at timestamptz;

update public.mochi_student_invites
set expires_at = created_at + interval '5 minutes'
where expires_at is null;

alter table public.mochi_student_invites
  alter column expires_at set default (now() + interval '5 minutes'),
  alter column expires_at set not null;

create or replace function public.mochi_redeem_student_invite(viewer_email text, invite_code text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare invite_row public.mochi_student_invites%rowtype; session_token text;
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

  session_token := translate(encode(extensions.gen_random_bytes(32), 'base64'), E'+/=\n', '-_');
  update public.mochi_student_invites set redeemed_at = now() where id = invite_row.id;
  insert into public.mochi_student_viewers(student_id, viewer_email, viewer_role, session_hash)
  values (invite_row.student_id, invite_row.recipient_email, invite_row.viewer_role,
    encode(extensions.digest(convert_to(session_token, 'UTF8'), 'sha256'), 'hex'));
  return jsonb_build_object('session_token', session_token, 'role', invite_row.viewer_role);
end $$;

revoke all on function public.mochi_redeem_student_invite(text,text) from public;
grant execute on function public.mochi_redeem_student_invite(text,text) to anon, authenticated;
