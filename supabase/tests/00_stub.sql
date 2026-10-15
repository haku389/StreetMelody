-- 手元の Postgres で Supabase の最小限を作る（検査用。本番には当てない）
--
-- **本番の写しとして書く。** auth.uid() / auth.jwt() は Supabase と同じく
-- request.jwt.claims から読む。食い違うと、検査は本番に無い理由で赤くなるか、
-- 本番にある穴の前で緑になる（Life_LevelUP で何度も踏んだ）
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;
create table if not exists auth.users (
  id uuid primary key,
  email text,
  created_at timestamptz default now()
);

create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid
$$;
grant execute on function auth.jwt(), auth.uid() to anon, authenticated, service_role;

-- 20261015130000_streetmelody_schema.sql の冒頭と同じ
create schema if not exists streetmelody;
grant usage on schema streetmelody to authenticated, service_role;
