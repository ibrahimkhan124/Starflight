-- Disposable transaction only: all fixtures are rolled back, including users.
begin;
insert into auth.users(id,email,aud,role) values
('10000000-0000-4000-8000-000000000001','starflight-isolation-a@example.invalid','authenticated','authenticated'),
('10000000-0000-4000-8000-000000000002','starflight-isolation-b@example.invalid','authenticated','authenticated');
insert into storage.objects(bucket_id,name) values
('starflight-saves','10000000-0000-4000-8000-000000000001/20000000-0000-4000-8000-000000000001.json'),
('starflight-saves','10000000-0000-4000-8000-000000000002/20000000-0000-4000-8000-000000000002.json');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
do $$
declare n integer;
begin
 select count(*) into n from public.commit_player_save(null,'30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001/20000000-0000-4000-8000-000000000001.json');
 if n<>1 then raise exception 'Initial save failed'; end if;
 select count(*) into n from public.commit_player_save('30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001/20000000-0000-4000-8000-000000000001.json');
 if n<>1 then raise exception 'Matching revision failed'; end if;
 select count(*) into n from public.commit_player_save('30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001/20000000-0000-4000-8000-000000000001.json');
 if n<>0 then raise exception 'Stale save accepted'; end if;
 select count(*) into n from storage.objects where bucket_id='starflight-saves' and name like '10000000-0000-4000-8000-000000000002/%';
 if n<>0 then raise exception 'Another user blob exposed'; end if;
 begin
  insert into storage.objects(bucket_id,name) values('starflight-saves','10000000-0000-4000-8000-000000000002/20000000-0000-4000-8000-000000000003.json');
  raise exception 'Another user upload allowed';
 exception when insufficient_privilege then null;
 end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
do $$
declare n integer;
begin
 select count(*) into n from public.player_saves;
 if n<>0 then raise exception 'Another user save row exposed'; end if;
 update public.player_saves set revision='30000000-0000-4000-8000-000000000003' where user_id='10000000-0000-4000-8000-000000000001';
 get diagnostics n = row_count;
 if n<>0 then raise exception 'Another user save changed'; end if;
 begin
  insert into public.player_saves(user_id,revision,object_path) values('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','forbidden');
  raise exception 'Another user save insert allowed';
 exception when insufficient_privilege then null;
 end;
 select count(*) into n from public.commit_player_save(null,'30000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002/20000000-0000-4000-8000-000000000002.json');
 if n<>1 then raise exception 'Second owner save failed'; end if;
end $$;
reset role;
do $$ begin
 if has_table_privilege('anon','public.player_saves','SELECT') then raise exception 'Anonymous save access'; end if;
 if (select public from storage.buckets where id='starflight-saves') then raise exception 'Public save bucket'; end if;
end $$;
select 'PASS: owner save, stale revision rejection, user isolation, private bucket' as result;
rollback;
