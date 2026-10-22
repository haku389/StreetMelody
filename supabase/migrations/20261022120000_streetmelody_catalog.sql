-- ─────────────────────────────────────────────────────────────
--  曲カタログ（artists / tracks）を StyleCare のプロジェクトへ（2026-10-22）
--
--  古い MelodyLien プロジェクト（wngtvdgzzlkajtbwsurc）は止まっている。無料プランで
--  同時に動かせるのは2つまでで、いまは StyleCare ともう1つで埋まっているため起こせない。
--  そこで、当時 Supabase MCP で入れた記録（8組・10曲 → 架空の2曲を 2026-06 に消して8曲）
--  から入れ直す。曲の並び・YouTube の動画・サビの秒・色は、iOS の seed とも一致する。
--
--  ── 読む人・書く人（2026-10-22 はく: アプリはログイン必須）
--   **読めるのはログインした人だけ**（authenticated に SELECT）。ログインしていない人（anon）は
--   これまでどおりスキーマごと入れない。iPhone は本人の鍵で直接読む。
--   Go サーバー（Cloud Run）は本人の鍵を持たないので、読むにはサーバー用の秘密の鍵が要る
--   （SUPABASE_SECRET_KEY。入れるまでは埋め込みの見本で動く）。
--   **書けるのは管理者だけ。** GRANT は SELECT だけ。
--
--  ── ついでに締める
--   関数から PUBLIC の EXECUTE を外し、これから作る関数も既定で外す（定義者の関数は
--   authenticated にだけ渡してある。引き金の関数は EXECUTE が無くても動く）。
-- ─────────────────────────────────────────────────────────────

revoke execute on all functions in schema streetmelody from public;
alter default privileges in schema streetmelody revoke execute on functions from public;

create table if not exists streetmelody.artists (
  id         text primary key,
  name       text not null,
  image_url  text,
  created_at timestamptz not null default now()
);

create table if not exists streetmelody.tracks (
  id               text primary key,
  artist_id        text not null references streetmelody.artists(id),
  title            text not null,
  youtube_video_id text,
  thumbnail_url    text,
  piece_count      integer not null default 24 check (piece_count > 0),
  grid_rows        integer not null default 4,
  grid_cols        integer not null default 6,
  chorus_start     integer not null default 0 check (chorus_start >= 0),
  color            text,
  reward_coins     integer not null default 100,
  reward_exp       integer not null default 50,
  created_at       timestamptz not null default now()
);
create index if not exists tracks_artist_idx on streetmelody.tracks (artist_id);

-- YouTube の動画があれば、サムネは maxresdefault（当時と同じ。明示した URL は上書きしない）
create or replace function streetmelody.tracks_thumbnail_from_youtube()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.thumbnail_url is null and new.youtube_video_id is not null then
    new.thumbnail_url := 'https://i.ytimg.com/vi/' || new.youtube_video_id || '/maxresdefault.jpg';
  end if;
  return new;
end $$;
revoke execute on function streetmelody.tracks_thumbnail_from_youtube() from public;
drop trigger if exists tracks_thumbnail on streetmelody.tracks;
create trigger tracks_thumbnail before insert or update on streetmelody.tracks
  for each row execute function streetmelody.tracks_thumbnail_from_youtube();

-- ログインした人が読むだけ（GRANT は SELECT だけ。RLS も読むポリシーだけ。2枚で守る）
alter table streetmelody.artists enable row level security;
alter table streetmelody.tracks  enable row level security;
revoke all on streetmelody.artists, streetmelody.tracks from anon, authenticated;
grant select on streetmelody.artists, streetmelody.tracks to authenticated;
drop policy if exists catalog_read on streetmelody.artists;
create policy catalog_read on streetmelody.artists for select to authenticated using (true);
drop policy if exists catalog_read on streetmelody.tracks;
create policy catalog_read on streetmelody.tracks for select to authenticated using (true);

-- ── 中身（古いプロジェクトの最後の状態）
insert into streetmelody.artists (id, name) values
  ('artist_higedan',  'Official髭男dism'),
  ('artist_niziu',    'NiziU'),
  ('artist_yonezu',   '米津玄師'),
  ('artist_yoasobi',  'YOASOBI'),
  ('artist_ado',      'Ado'),
  ('artist_vaundy',   'Vaundy'),
  ('artist_milet',    'milet'),
  ('artist_macaroni', 'マカロニえんぴつ')
on conflict (id) do update set name = excluded.name;

insert into streetmelody.tracks
  (id, artist_id, title, youtube_video_id, piece_count, chorus_start, color, reward_coins, reward_exp) values
  ('track_pretender', 'artist_higedan',  'Pretender',          'TQ8WlA2GXbk', 24, 57, 'magic',  100, 50),
  ('track_lemon',     'artist_yonezu',   'Lemon',              'SX_ViT4Ra7k', 24, 68, 'violet', 100, 50),
  ('track_yoru',      'artist_yoasobi',  '夜に駆ける',          'x8VYWazR5mE', 24, 52, 'berry',  100, 50),
  ('track_show',      'artist_ado',      '唱',                 'pgXpM4l_MwI', 24, 44, 'magic',  100, 50),
  ('track_kaiju',     'artist_vaundy',   '怪獣の花唄',          'UM9XNpgrqVk', 24, 38, 'sunset', 100, 50),
  ('track_anytime',   'artist_milet',    'Anytime Anywhere',   'r105CzDvoo0', 24, 58, 'violet', 100, 50),
  ('track_blueberry', 'artist_macaroni', 'ブルーベリー・ナイツ', 'Euf1-3WRino', 24, 55, 'berry',  100, 50),
  ('track_halzion',   'artist_yoasobi',  'ハルジオン',          'kzdJkT4kp-A', 24, 62, 'violet', 100, 50)
on conflict (id) do update set
  artist_id = excluded.artist_id, title = excluded.title, youtube_video_id = excluded.youtube_video_id,
  piece_count = excluded.piece_count, chorus_start = excluded.chorus_start, color = excluded.color,
  reward_coins = excluded.reward_coins, reward_exp = excluded.reward_exp;
