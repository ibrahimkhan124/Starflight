-- Run once in the project's SQL Editor. Only public identifiers go in the app.
begin;
create table if not exists public.player_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision uuid not null,
  object_path text not null,
  updated_at timestamptz not null default now()
);
alter table public.player_saves enable row level security;
revoke all on public.player_saves from anon;
grant select,insert,update on public.player_saves to authenticated;
drop policy if exists "own_save_read" on public.player_saves;
create policy "own_save_read" on public.player_saves for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "own_save_insert" on public.player_saves;
create policy "own_save_insert" on public.player_saves for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "own_save_update" on public.player_saves;
create policy "own_save_update" on public.player_saves for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('starflight-saves','starflight-saves',false,50331648,array['application/json'])
on conflict(id) do update set public=false,file_size_limit=50331648,allowed_mime_types=array['application/json'];
drop policy if exists "own_starflight_blob_read" on storage.objects;
create policy "own_starflight_blob_read" on storage.objects for select to authenticated
using (bucket_id='starflight-saves' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists "own_starflight_blob_insert" on storage.objects;
create policy "own_starflight_blob_insert" on storage.objects for insert to authenticated
with check (bucket_id='starflight-saves' and name ~ ('^' || (select auth.uid())::text || '/[0-9a-f-]{36}\.json$'));
-- Files are immutable. Updates/deletions require the server-side account cleanup function.
create or replace function public.commit_player_save(p_expected uuid,p_revision uuid,p_path text)
returns setof public.player_saves language plpgsql security invoker set search_path = '' as $$
begin
  if auth.uid() is null or p_path !~ ('^' || auth.uid()::text || '/[0-9a-f-]{36}\.json$') then
    raise exception 'Invalid save owner';
  end if;
  if not exists(select 1 from storage.objects where bucket_id='starflight-saves' and name=p_path) then
    raise exception 'Save upload not found';
  end if;
  if p_expected is null then
    return query insert into public.player_saves(user_id,revision,object_path,updated_at)
      values(auth.uid(),p_revision,p_path,now()) on conflict(user_id) do nothing returning *;
  else
    return query update public.player_saves set revision=p_revision,object_path=p_path,updated_at=now()
      where user_id=auth.uid() and revision=p_expected returning *;
  end if;
end;
$$;
revoke all on function public.commit_player_save(uuid,uuid,text) from public,anon;
grant execute on function public.commit_player_save(uuid,uuid,text) to authenticated;
commit;
