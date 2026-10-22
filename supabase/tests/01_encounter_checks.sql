-- ─────────────────────────────────────────────────────────────
--  すれちがいの待ち行列（20261015170000_encounter_outbox.sql）の検査
--
--  **禁止を確かめたら許可も確かめる。** 「入らない」だけを見ると、
--  何も入らない壊れ方でも緑になる。
--  失敗は FAIL: で落ちる。最後まで流れれば全部通っている。
-- ─────────────────────────────────────────────────────────────
\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('aaaaaaaa-0000-4000-8000-000000000001'),   -- A（自分）
  ('bbbbbbbb-0000-4000-8000-000000000002'),   -- B
  ('cccccccc-0000-4000-8000-000000000003')    -- C
on conflict do nothing;

-- A としてふるまう
create or replace function pg_temp.as_user(u text, anon boolean default false) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', u, 'role', 'authenticated', 'is_anonymous', anon)::text, false);
  execute 'set role authenticated';
end $$;

create or replace function pg_temp.expect(cond boolean, label text) returns void
language plpgsql as $$
begin
  if not coalesce(cond, false) then raise exception 'FAIL: %', label; end if;
end $$;

\echo '--- (a) 入る・同じ人と同じ日は1件'
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
create temp table r1 as
  select * from streetmelody.put_encounters(jsonb_build_array(
    jsonb_build_object('other_user_id', 'BBBBBBBB-0000-4000-8000-000000000002', 'occurred_at', now() - interval '10 minutes'),
    jsonb_build_object('other_user_id', 'bbbbbbbb-0000-4000-8000-000000000002', 'occurred_at', now() - interval '5 minutes'),
    jsonb_build_object('other_user_id', 'cccccccc-0000-4000-8000-000000000003', 'occurred_at', now() - interval '1 minute')));
select pg_temp.expect((select array_agg(status order by ord) from (select status, row_number() over () as ord from r1) x)
                      = array['stored','kept','stored'], '同じ人の2回目が kept にならない / 別の人が stored にならない');
-- 届いた綴りのまま返す（端末が大文字で送っても突き合わせられる）
select pg_temp.expect((select other_user_id from r1 limit 1) = 'BBBBBBBB-0000-4000-8000-000000000002',
                      '返りの other_user_id が届いた綴りと違う');
reset role;

\echo '--- (b) 相手の user_id を平文で残さない。ハッシュは契約 §4 の形'
select pg_temp.expect(
  (select count(*) from streetmelody.encounter_days
    where user_id = 'aaaaaaaa-0000-4000-8000-000000000001'
      and other_hash = left(encode(sha256(convert_to('bbbbbbbb-0000-4000-8000-000000000002', 'UTF8')), 'hex'), 12)) = 1,
  'B の行が sha256(小文字の uuid) の先頭12文字で入っていない（大文字で送っても同じ鍵になるはず）');
select pg_temp.expect(
  not exists (select 1 from streetmelody.encounter_days d
               where d::text ilike '%bbbbbbbb-0000%'),
  '相手の user_id が平文で残っている');

\echo '--- (c) JST の日付で刻む。日付をまたげば別の人日'
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
do $$
declare m timestamptz := (date_trunc('day', now() at time zone 'Asia/Tokyo') at time zone 'Asia/Tokyo') - interval '1 day';
begin
  perform streetmelody.put_encounters(jsonb_build_array(
    jsonb_build_object('other_user_id', 'cccccccc-0000-4000-8000-000000000003', 'occurred_at', m - interval '30 minutes'),
    jsonb_build_object('other_user_id', 'cccccccc-0000-4000-8000-000000000003', 'occurred_at', m + interval '30 minutes')));
end $$;
reset role;
select pg_temp.expect(
  (select count(distinct occurred_on) from streetmelody.encounter_days
    where user_id = 'aaaaaaaa-0000-4000-8000-000000000001'
      and other_hash = left(encode(sha256(convert_to('cccccccc-0000-4000-8000-000000000003', 'UTF8')), 'hex'), 12)
      and occurred_on < (now() at time zone 'Asia/Tokyo')::date) = 2,
  'JST の0時をまたいだ2回が別の日にならない（UTC で刻んでいる？）');

\echo '--- (d) 断るもの（理由まで確かめる）'
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
create temp table r2 as
  select * from streetmelody.put_encounters(jsonb_build_array(
    jsonb_build_object('other_user_id', 'aaaaaaaa-0000-4000-8000-000000000001', 'occurred_at', now()),
    jsonb_build_object('other_user_id', '99999999-0000-4000-8000-000000000009', 'occurred_at', now()),
    jsonb_build_object('other_user_id', 'not-a-uuid', 'occurred_at', now()),
    jsonb_build_object('other_user_id', 'bbbbbbbb-0000-4000-8000-000000000002', 'occurred_at', now() + interval '1 hour'),
    jsonb_build_object('other_user_id', 'bbbbbbbb-0000-4000-8000-000000000002', 'occurred_at', now() - interval '31 days'),
    jsonb_build_object('other_user_id', 'bbbbbbbb-0000-4000-8000-000000000002', 'occurred_at', 'きのう')));
select pg_temp.expect((select array_agg(reason order by ord) from (select reason, row_number() over () as ord from r2) x)
  = array['自分とはすれ違えない','知らない相手','other_user_id が uuid でない','未来の時刻','30日より前のすれちがい','occurred_at が時刻でない'],
  '断る理由が違う: ' || (select string_agg(coalesce(reason, '(null)'), ' / ') from r2));
-- 1件が悪くても全体は断らない（同じ束に正しい1件を混ぜる）
create temp table r3 as
  select * from streetmelody.put_encounters(jsonb_build_array(
    jsonb_build_object('other_user_id', 'not-a-uuid', 'occurred_at', now()),
    jsonb_build_object('other_user_id', 'cccccccc-0000-4000-8000-000000000003', 'occurred_at', now() - interval '2 minutes')));
select pg_temp.expect((select count(*) from r3 where status in ('stored','kept')) = 1,
                      '悪い1件があると、同じ束の正しい1件まで入らない');
reset role;

\echo '--- (e) 束ごと断るもの'
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001', true);
do $$ begin
  perform streetmelody.put_encounters('[]'::jsonb);
  raise exception 'FAIL: 匿名で入れられた';
exception when others then
  if sqlerrm like 'FAIL%' then raise; end if;
  if sqlerrm not like '%匿名%' then raise exception 'FAIL: 匿名が別の理由で断られた: %', sqlerrm; end if;
end $$;
reset role;
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
do $$ begin
  perform streetmelody.put_encounters((select jsonb_agg(jsonb_build_object('other_user_id', 'x', 'occurred_at', now())) from generate_series(1, 201)));
  raise exception 'FAIL: 201件の束が入った';
exception when others then
  if sqlerrm like 'FAIL%' then raise; end if;
  if sqlerrm not like '%200件まで%' then raise exception 'FAIL: 別の理由で断られた: %', sqlerrm; end if;
end $$;
reset role;

\echo '--- (f) 表には直接触れない'
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
do $$ begin
  perform 1 from streetmelody.encounter_days;
  raise exception 'FAIL: authenticated が表を直接読めた';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  insert into streetmelody.encounter_days (user_id, other_hash, occurred_on, occurred_at, sent_at)
  values (auth.uid(), 'abcdefabcdef', current_date, now(), now());
  raise exception 'FAIL: authenticated が表へ直接書けた（sent_at を自分で打てる）';
exception when insufficient_privilege then null;
end $$;
reset role;
set role anon;
do $$ begin
  perform streetmelody.put_encounters('[]'::jsonb);
  raise exception 'FAIL: anon が put_encounters を呼べた';
exception when insufficient_privilege then null;
end $$;
reset role;

-- **権限そのものを数える。** 表は「GRANT を外す」と「RLS（ポリシー無し）」の2枚で、
-- 関数は「EXECUTE を外す」と「スキーマの USAGE が無い」の2枚で守っている
-- （PUBLIC の EXECUTE は 20261022120000 で外した。02_catalog_checks.sql でも数える）。
-- 上の「止まったか」だけを見ると、1枚外れても残りの1枚が止めて緑のまま気づけない
-- （変異検査で、GRANT を足しても緑だった）
select pg_temp.expect(
  not has_table_privilege('authenticated', 'streetmelody.encounter_days', 'SELECT,INSERT,UPDATE,DELETE'),
  'authenticated に表の権限が付いている（RLS の1枚だけで守っている）');
select pg_temp.expect(
  not has_table_privilege('anon', 'streetmelody.encounter_days', 'SELECT,INSERT,UPDATE,DELETE'),
  'anon に表の権限が付いている');
select pg_temp.expect(
  (select relrowsecurity from pg_class where oid = 'streetmelody.encounter_days'::regclass)
  and not exists (select 1 from pg_policies where schemaname = 'streetmelody' and tablename = 'encounter_days'
                   and permissive = 'PERMISSIVE'),
  'RLS が無効か、許可のポリシーが足されている');
-- 制限の no_anon は付いている（20261015180000。ほかの表と同じ流儀）
select pg_temp.expect(
  exists (select 1 from pg_policies where schemaname = 'streetmelody' and tablename = 'encounter_days'
           and policyname = 'no_anon' and permissive = 'RESTRICTIVE'),
  'encounter_days に制限の no_anon が無い');
do $$
declare f text;
begin
  foreach f in array array[
    'streetmelody.put_encounters(jsonb)',
    'streetmelody.my_unsent_encounters(integer)',
    'streetmelody.mark_my_encounters_sent(jsonb, jsonb)',
    'streetmelody.mark_my_encounters_failed(jsonb, text)'] loop
    if has_function_privilege('anon', f, 'execute') then
      raise exception 'FAIL: anon が % を実行できる', f;
    end if;
    -- （対）authenticated は呼べる。全部閉じると端末から1件も入らない
    if not has_function_privilege('authenticated', f, 'execute') then
      raise exception 'FAIL: authenticated が % を実行できない', f;
    end if;
  end loop;
end $$;

\echo '--- (g) 未送信は本人のぶんだけ。届いた印も本人の行にだけ付く'
-- B も A とすれ違う（両方の端末から1件ずつ。契約 §8）
select pg_temp.as_user('bbbbbbbb-0000-4000-8000-000000000002');
select pg_temp.expect(
  (select status from streetmelody.put_encounters(jsonb_build_array(
     jsonb_build_object('other_user_id', 'aaaaaaaa-0000-4000-8000-000000000001', 'occurred_at', now() - interval '3 minutes')))) = 'stored',
  'B の視点の1件が入らない（両方の端末から積む）');
select pg_temp.expect((select count(*) from streetmelody.my_unsent_encounters()) = 1,
                      'B の未送信が自分の1件になっていない（A の行が見えている？）');
reset role;

-- A の行の手がかりを、表を読める立場で控えておく
select jsonb_agg(jsonb_build_object('other_hash', other_hash, 'occurred_on', occurred_on))::text as a_items,
       count(*) as a_count
  from streetmelody.encounter_days
 where user_id = 'aaaaaaaa-0000-4000-8000-000000000001' and sent_at is null \gset

-- B が A の行に印を付けようとしても付かない
select pg_temp.as_user('bbbbbbbb-0000-4000-8000-000000000002');
select pg_temp.expect(streetmelody.mark_my_encounters_sent(:'a_items'::jsonb, '{"accepted":9}') = 0,
                      'B が A の行に届いた印を付けられた');
select pg_temp.expect(streetmelody.mark_my_encounters_failed(:'a_items'::jsonb, 'x') = 0,
                      'B が A の行の失敗を数えられた');
reset role;

-- （対）A の未送信は表と同じ数だけ見える
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
select pg_temp.expect((select count(*) from streetmelody.my_unsent_encounters()) = :a_count,
                      'A の未送信の数が表と合わない');
reset role;

\echo '--- (h) 5回失敗した行は返さない。届いた印は返りと一緒に残る'
select pg_temp.as_user('aaaaaaaa-0000-4000-8000-000000000001');
do $$
declare first jsonb; rest jsonb; n_before integer; n_after integer;
begin
  select count(*) into n_before from streetmelody.my_unsent_encounters();
  select jsonb_build_array(jsonb_build_object('other_hash', other_hash, 'occurred_on', occurred_on))
    into first from streetmelody.my_unsent_encounters() limit 1;
  for i in 1..5 loop perform streetmelody.mark_my_encounters_failed(first, 'test'); end loop;
  select count(*) into n_after from streetmelody.my_unsent_encounters();
  if n_after <> n_before - 1 then
    raise exception 'FAIL: 5回失敗した1件だけが消えるはずが、% 件 → % 件', n_before, n_after;
  end if;
  select jsonb_agg(jsonb_build_object('other_hash', other_hash, 'occurred_on', occurred_on))
    into rest from streetmelody.my_unsent_encounters();
  if streetmelody.mark_my_encounters_sent(rest, '{"accepted":3}') <> n_after then
    raise exception 'FAIL: 届いた印が全部に付かない';
  end if;
  if exists (select 1 from streetmelody.my_unsent_encounters()) then
    raise exception 'FAIL: 届いた印を付けたのに、まだ未送信に出る';
  end if;
end $$;
reset role;
select pg_temp.expect(
  (select count(*) from streetmelody.encounter_days
    where user_id = 'aaaaaaaa-0000-4000-8000-000000000001' and sent_at is not null
      and hub_result = '{"accepted":3}') >= 1,
  'ハブの返りが残っていない');

\echo '--- (i) 1日200人まで'
insert into auth.users (id)
select ('dddddddd-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid from generate_series(1, 201) g
on conflict do nothing;
select pg_temp.as_user('cccccccc-0000-4000-8000-000000000003');
create temp table r4 as
  select * from streetmelody.put_encounters(
    (select jsonb_agg(jsonb_build_object('other_user_id', 'dddddddd-0000-4000-8000-' || lpad(g::text, 12, '0'),
                                         'occurred_at', now() - interval '1 minute'))
       from generate_series(1, 200) g));
select pg_temp.expect((select count(*) from r4 where status = 'stored') = 200, '200人目までが入らない');
select pg_temp.expect(
  (select reason from streetmelody.put_encounters(jsonb_build_array(
     jsonb_build_object('other_user_id', 'dddddddd-0000-4000-8000-000000000201', 'occurred_at', now() - interval '1 minute')))) like '%200人まで%',
  '201人目が断られない');
reset role;

\echo ''
\echo '=== すべて通過 ==='
