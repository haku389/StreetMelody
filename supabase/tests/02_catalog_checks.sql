-- ─────────────────────────────────────────────────────────────
--  曲カタログ（20261022120000_streetmelody_catalog.sql）の検査
--
--  アプリはログイン必須。カタログを読めるのはログインした人（authenticated）だけで、
--  ログインしていない人（anon）はスキーマごと入れない。書けるのは管理者だけ。
--  禁止を確かめたら許可も確かめる（読めることも見る）。
-- ─────────────────────────────────────────────────────────────
\set ON_ERROR_STOP on

create or replace function pg_temp.expect(cond boolean, label text) returns void
language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if;
end $$;

\echo '--- (a) 中身と、サムネが YouTube の maxres になっていること'
select pg_temp.expect((select count(*) from streetmelody.artists) = 8, 'アーティストが8組でない');
select pg_temp.expect((select count(*) from streetmelody.tracks) = 8, '曲が8曲でない');
select pg_temp.expect(
  not exists (select 1 from streetmelody.tracks
               where thumbnail_url is distinct from 'https://i.ytimg.com/vi/' || youtube_video_id || '/maxresdefault.jpg'),
  'サムネが YouTube の maxresdefault になっていない曲がある');

\echo '--- (b) ログインした人は読める（許可）'
set role authenticated;
select pg_temp.expect((select count(*) from streetmelody.tracks) = 8, 'authenticated が曲を読めない');
select pg_temp.expect((select count(*) from streetmelody.artists) = 8, 'authenticated がアーティストを読めない');
reset role;

\echo '--- (b2) サーバー（秘密の鍵＝service_role）も読める。書けるのは管理者だけ'
select pg_temp.expect(has_table_privilege('service_role', 'streetmelody.tracks', 'SELECT'), 'service_role が曲を読めない（Go サーバーが 403 になる）');
select pg_temp.expect(has_table_privilege('service_role', 'streetmelody.artists', 'SELECT'), 'service_role がアーティストを読めない');
select pg_temp.expect(not has_table_privilege('service_role', 'streetmelody.tracks', 'INSERT,UPDATE,DELETE,TRUNCATE'), 'service_role が曲を書ける権限を持っている');

\echo '--- (c) ログインしていない人は読めない（スキーマごと入れない）'
select pg_temp.expect(not has_schema_privilege('anon', 'streetmelody', 'USAGE'), 'anon にスキーマの USAGE がある');
select pg_temp.expect(not has_table_privilege('anon', 'streetmelody.tracks', 'SELECT'), 'anon が曲を読める権限を持っている');
select pg_temp.expect(not has_table_privilege('anon', 'streetmelody.artists', 'SELECT'), 'anon がアーティストを読める権限を持っている');
set role anon;
do $$ begin
  perform 1 from streetmelody.tracks limit 1;
  raise exception 'FAIL: anon が曲を読めた';
exception when insufficient_privilege then null;
end $$;
reset role;
select pg_temp.expect(
  not exists (select 1 from pg_policies where schemaname = 'streetmelody' and tablename in ('artists', 'tracks')
               and ('anon' = any(roles) or 'public' = any(roles))),
  'カタログに anon / public 向けのポリシーがある');

\echo '--- (d) 誰も書けない（GRANT と RLS の2枚を、それぞれ数える）'
do $$
declare r text; t text;
begin
  foreach r in array array['anon', 'authenticated'] loop
    foreach t in array array['streetmelody.artists', 'streetmelody.tracks'] loop
      if has_table_privilege(r, t, 'INSERT,UPDATE,DELETE,TRUNCATE') then
        raise exception 'FAIL: % が % に書ける権限を持っている', r, t;
      end if;
    end loop;
  end loop;
end $$;
select pg_temp.expect(
  (select bool_and(relrowsecurity) from pg_class where oid in ('streetmelody.artists'::regclass, 'streetmelody.tracks'::regclass)),
  'カタログの RLS が無効');
select pg_temp.expect(
  not exists (select 1 from pg_policies where schemaname = 'streetmelody' and tablename in ('artists', 'tracks')
               and permissive = 'PERMISSIVE' and cmd <> 'SELECT'),
  'カタログに書き込みを許すポリシーがある');

\echo '--- (e) 関数は PUBLIC に開いていない（anon は1つも実行できない）'
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as fn from pg_proc p where p.pronamespace = 'streetmelody'::regnamespace loop
    if has_function_privilege('anon', f.fn, 'execute') then
      raise exception 'FAIL: anon が % を実行できる', f.fn;
    end if;
  end loop;
end $$;

\echo ''
\echo '=== カタログもすべて通過 ==='
