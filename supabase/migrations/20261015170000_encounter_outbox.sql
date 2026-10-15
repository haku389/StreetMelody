-- ─────────────────────────────────────────────────────────────
--  すれちがいを「人生の記録」へ送る待ち行列（2026-10-15）
--
--  共通ハブ（life-os-api）の契約 docs/contract.md に合わせる:
--   §1  app は `streetmelody`（改名しても据え置く）
--   §4  鍵は streetmelody:encounter_days:<user_id>:<sha256(相手のuser_id)の先頭12文字>:<日付>
--       **相手の user_id を平文で残さない。** ここにも先頭12文字のハッシュだけ持つ
--   §8  すれちがいは**両方の端末から1件ずつ**積む。刻みは日単位（JST）。
--       同じ人と同じ日に何度会っても1件（「人日」）。BLE の重複防止はメモリ上に
--       しかなく再起動で消えるので、**一意の範囲（主キー）が全責任を負う**
--
--  流れ（Life_LevelUP・WakeFirst と同じ形）:
--   端末 → 中継 Worker（workers/。本人を確かめる）→ put_encounters（本人のトークン）
--   → この表に溜まる → 中継がハブへ流し、届いた印を付ける
--  ハブの鍵（APP_SECRETS の streetmelody）が入るまでは、溜まるだけで流れない。
--  **記録は後から作れない**ので、流れる前から溜めておく。
--
--  ── 表には誰も直接触れない
--  直接書けると、端末が sent_at を自分で打てる（＝送っていないのに送った印）。
--  口は下の4つの関数だけ。
-- ─────────────────────────────────────────────────────────────

create table if not exists streetmelody.encounter_days (
  user_id     uuid        not null references auth.users(id) on delete cascade,
  -- sha256(lower(相手のuser_id)) の hex 先頭12文字（契約 §4）
  other_hash  text        not null check (other_hash ~ '^[0-9a-f]{12}$'),
  -- JST の日付。occurred_at から DB が決める（端末に決めさせない）
  occurred_on date        not null,
  -- その日にその人と最初にすれ違った時刻
  occurred_at timestamptz not null,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz,
  attempts    integer     not null default 0,
  last_error  text,
  -- ハブが何と答えたか（accepted / unchanged など）。画面は後から作れるが、記録は後から作れない
  hub_result  jsonb,
  primary key (user_id, other_hash, occurred_on)
);

create index if not exists encounter_days_unsent
  on streetmelody.encounter_days (user_id, occurred_at)
  where sent_at is null;

alter table streetmelody.encounter_days enable row level security;
revoke all on streetmelody.encounter_days from public, anon, authenticated;


-- ── 端末から届いたすれちがいを入れる
--
--  p_items: [{ "other_user_id": "<uuid>", "occurred_at": "<ISO8601>" }, …]（200件まで）
--  返り:    1件ずつ { other_user_id（**届いた綴りのまま**）, status, reason }
--           status = stored（入った）/ kept（その日はもう入っていた）/ rejected（送り直しても通らない）
--
--  **1件が悪くても全体は断らない。** 端末は同じ束を送り直すので、
--  1件が後ろを永久に塞ぐ（WakeFirst で踏んだ）
create or replace function streetmelody.put_encounters(p_items jsonb)
returns table (other_user_id text, status text, reason text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid      uuid := auth.uid();
  item     jsonb;
  raw      text;
  other    uuid;
  seen_at  timestamptz;
  on_day   date;
  h        text;
  n        integer;
begin
  if uid is null then
    raise exception 'サインインしていない';
  end if;
  -- 匿名は人生の記録を積めない（名寄せができない。契約 §12⑬）
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception '匿名アカウントでは記録を積めない';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'p_items は配列で送ること';
  end if;
  if jsonb_array_length(p_items) > 200 then
    raise exception '1回に送れるのは200件まで';
  end if;

  for item in select * from jsonb_array_elements(p_items) loop
    raw := item ->> 'other_user_id';
    other_user_id := raw;

    begin
      other := raw::uuid;
    exception when others then
      status := 'rejected'; reason := 'other_user_id が uuid でない';
      return next; continue;
    end;
    begin
      seen_at := (item ->> 'occurred_at')::timestamptz;
    exception when others then
      status := 'rejected'; reason := 'occurred_at が時刻でない';
      return next; continue;
    end;

    if other is null or seen_at is null then
      status := 'rejected'; reason := 'other_user_id と occurred_at が要る';
      return next; continue;
    end if;
    if other = uid then
      status := 'rejected'; reason := '自分とはすれ違えない';
      return next; continue;
    end if;
    -- 端末の時計のずれぶんだけ許す
    if seen_at > now() + interval '5 minutes' then
      status := 'rejected'; reason := '未来の時刻';
      return next; continue;
    end if;
    -- 圏外で溜まっていたぶんは受ける。それより古いものは作り話と区別できない
    if seen_at < now() - interval '30 days' then
      status := 'rejected'; reason := '30日より前のすれちがい';
      return next; continue;
    end if;
    -- **実在する相手だけ。** 出まかせの uuid を送ると「人日」をいくらでも盛れる
    if not exists (select 1 from auth.users u where u.id = other) then
      status := 'rejected'; reason := '知らない相手';
      return next; continue;
    end if;

    on_day := (seen_at at time zone 'Asia/Tokyo')::date;
    -- 組み込みの sha256（pg_catalog）。拡張に頼らない
    h := left(encode(sha256(convert_to(lower(other::text), 'UTF8')), 'hex'), 12);

    -- 1日の上限。BLE の重複防止（10人/時）はメモリ上にしかないので、ここで抑える
    select count(*) into n from streetmelody.encounter_days d
     where d.user_id = uid and d.occurred_on = on_day;
    if n >= 200 then
      status := 'rejected'; reason := '1日に記録できるのは200人まで';
      return next; continue;
    end if;

    insert into streetmelody.encounter_days (user_id, other_hash, occurred_on, occurred_at)
    values (uid, h, on_day, seen_at)
    on conflict (user_id, other_hash, occurred_on) do nothing;

    if found then
      status := 'stored'; reason := null;
    else
      status := 'kept'; reason := null;
    end if;
    return next;
  end loop;
end;
$$;


-- ── まだハブへ届いていない、自分の行
--
--  5回失敗した行は返さない（後ろの行が通れなくなる）。古い順
create or replace function streetmelody.my_unsent_encounters(p_limit integer default 200)
returns table (other_hash text, occurred_on date, occurred_at timestamptz, attempts integer)
language sql
stable
security definer
set search_path = ''
as $$
  select d.other_hash, d.occurred_on, d.occurred_at, d.attempts
    from streetmelody.encounter_days d
   where d.user_id = auth.uid()
     and d.sent_at is null
     and d.attempts < 5
   order by d.occurred_at
   limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;


-- ── 届いた印。ハブの返りを一緒に残す
--
--  p_items: [{ "other_hash": "…", "occurred_on": "YYYY-MM-DD" }, …]
create or replace function streetmelody.mark_my_encounters_sent(p_items jsonb, p_result jsonb default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  update streetmelody.encounter_days d
     set sent_at = clock_timestamp(), last_error = null, hub_result = p_result
    from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as i(other_hash text, occurred_on date)
   where d.user_id = auth.uid()
     and d.other_hash = i.other_hash
     and d.occurred_on = i.occurred_on
     and d.sent_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;


-- ── 送れなかった。**行のせいのときだけ**中継が呼ぶ（5回で諦める）
create or replace function streetmelody.mark_my_encounters_failed(p_items jsonb, p_error text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  update streetmelody.encounter_days d
     set attempts = d.attempts + 1, last_error = left(p_error, 500)
    from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as i(other_hash text, occurred_on date)
   where d.user_id = auth.uid()
     and d.other_hash = i.other_hash
     and d.occurred_on = i.occurred_on
     and d.sent_at is null;
  get diagnostics n = row_count;
  return n;
end;
$$;


-- ── 実行権限は authenticated だけ
--
--  関数は作られた時点で PUBLIC に EXECUTE が付き、anon と authenticated は
--  そこから継承する。**3つとも外してから**配る（契約 §11）
revoke all on function streetmelody.put_encounters(jsonb)                  from public, anon, authenticated;
revoke all on function streetmelody.my_unsent_encounters(integer)          from public, anon, authenticated;
revoke all on function streetmelody.mark_my_encounters_sent(jsonb, jsonb)  from public, anon, authenticated;
revoke all on function streetmelody.mark_my_encounters_failed(jsonb, text) from public, anon, authenticated;

grant execute on function streetmelody.put_encounters(jsonb)                  to authenticated;
grant execute on function streetmelody.my_unsent_encounters(integer)          to authenticated;
grant execute on function streetmelody.mark_my_encounters_sent(jsonb, jsonb)  to authenticated;
grant execute on function streetmelody.mark_my_encounters_failed(jsonb, text) to authenticated;
