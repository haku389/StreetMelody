-- ─────────────────────────────────────────────────────────────
--  StreetMelody を StyleCare のプロジェクト（共通アカウント）へ（2026-10-15）
--
--  これまでの MelodyLien プロジェクト（wngtvdgzzlkajtbwsurc）は無料プランの上限で
--  止まっていた。DailyBasket（shopping）・Life_LevelUP（lifelevelup）と同じく、
--  StyleCare のプロジェクトに自分のスキーマを持って同居する。
--
--  ── 共通アカウントで決まっていること
--   ・名前・ユーザーID・ひとこと・アイコンの正は public.profiles（id = auth.uid）。
--     ID の変更は public.change_handle、検索は public.find_user_by_handle、
--     名前のまとめ取得は public.get_display_names を使う。ここには持たない。
--   ・匿名ログインは使わない（このプロジェクトでは止めてある）。念のため各表に
--     「匿名は書けない」を RESTRICTIVE で重ねる（DailyBasket と同じ）。
--   ・アカウント削除は共通アカウントごと。user の外部キーは on delete cascade。
--   ・auth.users にトリガーは足さない（全アプリの登録に効いてしまう）。
--     streetmelody.profiles の行はアプリが初回に作る。
--
--  ── 引き継がないもの
--   古いプロジェクトのユーザーは別の auth.users なので、行を移しても持ち主がいない。
--   端末に残っている進行（ピース・解放・ヒント）は、ログイン後の同期で上がる。
--   曲カタログ（artists / tracks）は後で移す（Go サーバーのデプロイと一緒に）。
--
--  ※ Settings → API → Exposed schemas に `streetmelody` を足すこと（アプリから読むため）。
-- ─────────────────────────────────────────────────────────────

create schema if not exists streetmelody;
grant usage on schema streetmelody to authenticated, service_role;

-- ── アプリ固有のプロフィール（名前・ID・ひとことは public.profiles）
create table if not exists streetmelody.profiles (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  favorite_artist_ids text[]      not null default '{}',
  favorite_track_ids  text[]      not null default '{}',
  birthday            date,
  gender              text check (gender in ('male', 'female', 'other', 'na')),
  profile_visibility  jsonb       not null default '{}'::jsonb,
  coins               integer     not null default 240 check (coins >= 0),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ── パズルの進行
create table if not exists streetmelody.collected_pieces (
  user_id      uuid        not null references auth.users(id) on delete cascade,
  track_id     text        not null,
  piece_number integer     not null check (piece_number between 1 and 48),
  collected_at timestamptz not null default now(),
  primary key (user_id, track_id, piece_number)
);

create table if not exists streetmelody.unlocked_tracks (
  user_id     uuid        not null references auth.users(id) on delete cascade,
  track_id    text        not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, track_id)
);

create table if not exists streetmelody.hint_levels (
  user_id      uuid        not null references auth.users(id) on delete cascade,
  track_id     text        not null,
  level        integer     not null default 0 check (level between 0 and 3),
  answer_ready boolean     not null default false,
  updated_at   timestamptz not null default now(),
  primary key (user_id, track_id)
);

-- ── すれ違った相手との交換履歴（旧 friendships。フレンドとは別物なので名前を変えた）
create table if not exists streetmelody.exchange_history (
  user_id        uuid        not null references auth.users(id) on delete cascade,
  friend_name    text        not null,
  location_label text,
  exchange_count integer     not null default 1 check (exchange_count >= 0),
  updated_at     timestamptz not null default now(),
  primary key (user_id, friend_name)
);

-- ── 今聴いている曲（1人1行）
create table if not exists streetmelody.now_playing (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  service      text        not null,
  track_title  text        not null,
  artist       text,
  artwork_url  text,
  started_at   timestamptz,
  updated_at   timestamptz not null default now(),
  visibility   text        not null default 'public'
               check (visibility in ('public', 'friends', 'bestfriends'))
);
create index if not exists now_playing_updated on streetmelody.now_playing (updated_at desc);

-- ── フレンド：申請 → 相手が承認（StyleCare の public.friendships と同じ仕組み）
create table if not exists streetmelody.friend_links (
  id          uuid primary key default gen_random_uuid(),
  requester   uuid not null references auth.users(id) on delete cascade,
  addressee   uuid not null references auth.users(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  accepted_at timestamptz,
  constraint friend_links_no_self check (requester <> addressee)
);
-- 向きが逆でも同じ2人の行は1つだけ（2つあると一覧に同じ人が2回並ぶ）
create unique index if not exists friend_links_pair
  on streetmelody.friend_links (least(requester, addressee), greatest(requester, addressee));
create index if not exists friend_links_addressee on streetmelody.friend_links (addressee, status);

-- ベスト指定は自分→相手の片方向。フレンドのあいだだけ意味を持つ
create table if not exists streetmelody.friend_bests (
  user_id    uuid not null references auth.users(id) on delete cascade,
  friend_id  uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);
create index if not exists friend_bests_friend on streetmelody.friend_bests (friend_id);

-- ── フレンドか（RLS から呼ぶ。friend_links の RLS を再帰させないよう definer）
create or replace function streetmelody.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from streetmelody.friend_links l
     where l.status = 'accepted'
       and least(l.requester, l.addressee) = least(a, b)
       and greatest(l.requester, l.addressee) = greatest(a, b)
  )
$$;
revoke all on function streetmelody.are_friends(uuid, uuid) from public, anon;
grant execute on function streetmelody.are_friends(uuid, uuid) to authenticated;

-- ── 双方が申請したら待たずに成立（StyleCare 20260916）。送りっぱなしの上限も見る
create or replace function streetmelody.friend_links_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  open_count int;
begin
  update streetmelody.friend_links
     set status = 'accepted', accepted_at = now()
   where requester = new.addressee and addressee = new.requester and status = 'pending';
  if found then
    return null;
  end if;
  select count(*) into open_count from streetmelody.friend_links
   where requester = new.requester and status = 'pending';
  if open_count >= 50 then
    raise exception 'too many pending friend requests' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists friend_links_before_insert on streetmelody.friend_links;
create trigger friend_links_before_insert before insert on streetmelody.friend_links
  for each row execute function streetmelody.friend_links_before_insert();

-- 承認した時刻はサーバーが入れる
create or replace function streetmelody.friend_links_before_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    new.accepted_at := now();
  end if;
  return new;
end $$;
drop trigger if exists friend_links_before_update on streetmelody.friend_links;
create trigger friend_links_before_update before update on streetmelody.friend_links
  for each row execute function streetmelody.friend_links_before_update();

-- 解除したらベスト指定も消す
create or replace function streetmelody.friend_links_after_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from streetmelody.friend_bests
   where (user_id = old.requester and friend_id = old.addressee)
      or (user_id = old.addressee and friend_id = old.requester);
  return old;
end $$;
drop trigger if exists friend_links_after_delete on streetmelody.friend_links;
create trigger friend_links_after_delete after delete on streetmelody.friend_links
  for each row execute function streetmelody.friend_links_after_delete();

-- 更新時刻
create or replace function streetmelody.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists profiles_touch on streetmelody.profiles;
create trigger profiles_touch before update on streetmelody.profiles
  for each row execute function streetmelody.touch_updated_at();

-- トリガー用の関数は直接呼ばせない
revoke all on function streetmelody.friend_links_before_insert() from public, anon, authenticated;
revoke all on function streetmelody.friend_links_after_delete()  from public, anon, authenticated;

-- ── 権限
grant select, insert, update, delete on all tables in schema streetmelody to authenticated;
revoke all on all tables in schema streetmelody from anon;

alter table streetmelody.profiles         enable row level security;
alter table streetmelody.collected_pieces enable row level security;
alter table streetmelody.unlocked_tracks  enable row level security;
alter table streetmelody.hint_levels      enable row level security;
alter table streetmelody.exchange_history enable row level security;
alter table streetmelody.now_playing      enable row level security;
alter table streetmelody.friend_links     enable row level security;
alter table streetmelody.friend_bests     enable row level security;

-- 自分の行だけ（進行・プロフィール・交換履歴）
do $$
declare t text;
begin
  foreach t in array array['profiles', 'collected_pieces', 'unlocked_tracks', 'hint_levels', 'exchange_history']
  loop
    execute format('drop policy if exists own_rows on streetmelody.%I', t);
    execute format('create policy own_rows on streetmelody.%I for all to authenticated
                      using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

-- 今聴いている曲：書くのは本人だけ。読めるのは 公開／フレンド限定（フレンドなら）／
-- ベスト限定（相手が自分をベストに指定していれば）
drop policy if exists now_playing_insert on streetmelody.now_playing;
create policy now_playing_insert on streetmelody.now_playing for insert to authenticated
  with check ((select auth.uid()) = user_id);
drop policy if exists now_playing_update on streetmelody.now_playing;
create policy now_playing_update on streetmelody.now_playing for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists now_playing_delete on streetmelody.now_playing;
create policy now_playing_delete on streetmelody.now_playing for delete to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists now_playing_read on streetmelody.now_playing;
create policy now_playing_read on streetmelody.now_playing for select to authenticated
  using (
    (select auth.uid()) = user_id
    or visibility = 'public'
    or (visibility = 'friends' and streetmelody.are_friends(user_id, (select auth.uid())))
    or (visibility = 'bestfriends' and streetmelody.are_friends(user_id, (select auth.uid()))
        and exists (select 1 from streetmelody.friend_bests b
                     where b.user_id = now_playing.user_id and b.friend_id = (select auth.uid())))
  );

-- フレンド：読むのは関わる2人。申請は自分から待ちでだけ。承認は受けた側だけ。消すのはどちらでも
-- （StyleCare 20260924：status を見ていなかったため承認なしで仲間になれた穴があった）
drop policy if exists friend_links_select on streetmelody.friend_links;
create policy friend_links_select on streetmelody.friend_links for select to authenticated
  using ((select auth.uid()) in (requester, addressee));
drop policy if exists friend_links_insert on streetmelody.friend_links;
create policy friend_links_insert on streetmelody.friend_links for insert to authenticated
  with check ((select auth.uid()) = requester and status = 'pending' and accepted_at is null);
drop policy if exists friend_links_update on streetmelody.friend_links;
create policy friend_links_update on streetmelody.friend_links for update to authenticated
  using ((select auth.uid()) = addressee and status = 'pending')
  with check ((select auth.uid()) = addressee and status = 'accepted');
drop policy if exists friend_links_delete on streetmelody.friend_links;
create policy friend_links_delete on streetmelody.friend_links for delete to authenticated
  using ((select auth.uid()) in (requester, addressee));

drop policy if exists friend_bests_rw on streetmelody.friend_bests;
create policy friend_bests_rw on streetmelody.friend_bests for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and streetmelody.are_friends((select auth.uid()), friend_id));

-- 匿名は書けない（匿名ログインは止めてあるが、念のため仕組みで止める）
do $$
declare t text;
begin
  foreach t in array array['profiles', 'collected_pieces', 'unlocked_tracks', 'hint_levels',
                           'exchange_history', 'now_playing', 'friend_links', 'friend_bests']
  loop
    execute format('drop policy if exists no_anon on streetmelody.%I', t);
    execute format('create policy no_anon on streetmelody.%I as restrictive for all to authenticated
                      using (not public.is_anon()) with check (not public.is_anon())', t);
  end loop;
end $$;
