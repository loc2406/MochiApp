-- Account-owned durable state; auth metadata is not the learning database.
create table if not exists public.mochi_account_state (
 user_id uuid primary key references auth.users(id) on delete cascade,
 revision bigint not null default 1,
 state jsonb not null check (jsonb_typeof(state) = 'object'),
 updated_at timestamptz not null default now()
);
alter table public.mochi_account_state enable row level security;
create policy account_read on public.mochi_account_state for select to authenticated using (auth.uid() = user_id);
grant select on public.mochi_account_state to authenticated;
-- Writes use optimistic concurrency; stale clients cannot overwrite a newer revision.
create or replace function public.mochi_save_state(expected_revision bigint, new_state jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare next_revision bigint;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 if expected_revision = 0 then
   insert into mochi_account_state(user_id, state) values(auth.uid(), new_state)
   on conflict do nothing returning revision into next_revision;
 else
   update mochi_account_state set state=new_state, revision=revision+1, updated_at=now()
   where user_id=auth.uid() and revision=expected_revision returning revision into next_revision;
 end if;
 if next_revision is null then raise exception 'sync_conflict'; end if;
 return next_revision;
end $$;
revoke all on function public.mochi_save_state(bigint,jsonb) from public;
grant execute on function public.mochi_save_state(bigint,jsonb) to authenticated;
