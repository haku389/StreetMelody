-- ─────────────────────────────────────────────────────────────
--  フレンドは「申請 → 相手が承認」で成立する（2026-10-15）
--
--  StyleCare の仲間（public.friendships）と同じ仕組みに揃える。
--  それまでの StreetMelody は follows（一方向のフォロー。相互でフレンド）だった。
--  フォローは承認が要らないので、知らない人に一方的に関係を作られてしまう。
--
--  表の名前は friend_links。StreetMelody では friendships が
--  「すれ違った相手の交換履歴」の名前で既に使われているため。
--
--  follows は消さない。相互フォローだった人は、ここでフレンドとして引き継ぐ。
-- ─────────────────────────────────────────────────────────────

create table if not exists public.friend_links (
  id          uuid primary key default gen_random_uuid(),
  requester   uuid not null references auth.users(id) on delete cascade,
  addressee   uuid not null references auth.users(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  accepted_at timestamptz,
  constraint friend_links_no_self check (requester <> addressee)
);

-- 向きが逆でも同じ2人の行は1つだけ（行が2つあると、一覧に同じ人が2回並ぶ）
create unique index if not exists friend_links_pair
  on public.friend_links (least(requester, addressee), greatest(requester, addressee));
create index if not exists friend_links_addressee on public.friend_links (addressee, status);

-- ベスト指定は自分→相手の片方向。フレンドのあいだだけ意味を持つ
create table if not exists public.friend_bests (
  user_id    uuid not null references auth.users(id) on delete cascade,
  friend_id  uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

alter table public.friend_links enable row level security;
alter table public.friend_bests enable row level security;

-- ── 読む：自分が関わる行だけ
drop policy if exists friend_links_select on public.friend_links;
create policy friend_links_select on public.friend_links
  for select to authenticated using (auth.uid() in (requester, addressee));

-- ── 申請する：自分が申請者で、待ちの状態でしか入れられない
--    （StyleCare 20260924：status を見ていなかったため、承認なしで仲間になれた穴があった）
drop policy if exists friend_links_insert on public.friend_links;
create policy friend_links_insert on public.friend_links
  for insert to authenticated
  with check (auth.uid() = requester and status = 'pending' and accepted_at is null);

-- ── 承認する：受けた側だけが、待ち → 承認済み にできる
drop policy if exists friend_links_update on public.friend_links;
create policy friend_links_update on public.friend_links
  for update to authenticated
  using (auth.uid() = addressee and status = 'pending')
  with check (auth.uid() = addressee and status = 'accepted');

-- ── 取り消す・断る・解除する：どちらからでも
drop policy if exists friend_links_delete on public.friend_links;
create policy friend_links_delete on public.friend_links
  for delete to authenticated using (auth.uid() in (requester, addressee));

-- ── ベスト：自分の行だけ。入れられるのはフレンドの相手だけ
drop policy if exists friend_bests_rw on public.friend_bests;
create policy friend_bests_rw on public.friend_bests
  for all to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id and exists (
      select 1 from public.friend_links l
      where l.status = 'accepted'
        and ((l.requester = auth.uid() and l.addressee = friend_id)
          or (l.addressee = auth.uid() and l.requester = friend_id))
    )
  );

-- ── 双方が申請したら、待たずにフレンドにする（StyleCare 20260916 と同じ）
--    近くの人どうしで送り合うと、2人とも「申請」を押すことが起きる。
--    反対向きの待ち行があればそれを承認済みにして、新しい行は入れない。
create or replace function public.friend_links_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  open_count int;
begin
  update public.friend_links
     set status = 'accepted', accepted_at = now()
   where requester = new.addressee and addressee = new.requester and status = 'pending';
  if found then
    return null;
  end if;

  -- 送りっぱなしの申請の上限（いたずらで大量に送れないように）
  select count(*) into open_count from public.friend_links
   where requester = new.requester and status = 'pending';
  if open_count >= 50 then
    raise exception 'too many pending friend requests' using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists friend_links_before_insert on public.friend_links;
create trigger friend_links_before_insert
  before insert on public.friend_links
  for each row execute function public.friend_links_before_insert();

-- 承認した時刻はサーバーが入れる（端末の時計を信用しない）
create or replace function public.friend_links_before_update()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status = 'accepted' and old.status = 'pending' then
    new.accepted_at := now();
  end if;
  return new;
end $$;

drop trigger if exists friend_links_before_update on public.friend_links;
create trigger friend_links_before_update
  before update on public.friend_links
  for each row execute function public.friend_links_before_update();

-- 解除したらベスト指定も消す（フレンドでない人のベストが残らないように）
create or replace function public.friend_links_after_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.friend_bests
   where (user_id = old.requester and friend_id = old.addressee)
      or (user_id = old.addressee and friend_id = old.requester);
  return old;
end $$;

drop trigger if exists friend_links_after_delete on public.friend_links;
create trigger friend_links_after_delete
  after delete on public.friend_links
  for each row execute function public.friend_links_after_delete();

-- ── ユーザーIDで探す。返すのは表示名とIDだけ（関係を問わず見せてよいもの）
create or replace function public.find_user_by_handle(p_handle text)
returns table (user_id uuid, handle text, display_name text)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.handle, p.display_name
    from public.profiles p
   where p.handle is not null
     and lower(p.handle) = lower(ltrim(trim(p_handle), '@'))
   limit 1
$$;

-- ── 表示名とIDをまとめて引く（フレンド一覧・申請・近くの人）
create or replace function public.get_display_names(p_ids uuid[])
returns table (user_id uuid, handle text, display_name text)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.handle, p.display_name
    from public.profiles p
   where p.user_id = any (p_ids[1:100])
$$;

revoke all on function public.find_user_by_handle(text) from public, anon;
revoke all on function public.get_display_names(uuid[]) from public, anon;
grant execute on function public.find_user_by_handle(text) to authenticated;
grant execute on function public.get_display_names(uuid[]) to authenticated;

-- ── 引き継ぎ：相互フォローだった人をフレンドに、ベスト指定もそのまま
insert into public.friend_links (requester, addressee, status, accepted_at)
select a.follower_id::uuid, a.followee_id::uuid, 'accepted', now()
  from public.follows a
  join public.follows b
    on b.follower_id = a.followee_id and b.followee_id = a.follower_id
 where a.follower_id::text < a.followee_id::text
on conflict do nothing;

insert into public.friend_bests (user_id, friend_id)
select f.follower_id::uuid, f.followee_id::uuid
  from public.follows f
 where f.is_best
   and exists (
     select 1 from public.friend_links l
      where l.status = 'accepted'
        and least(l.requester, l.addressee) = least(f.follower_id::uuid, f.followee_id::uuid)
        and greatest(l.requester, l.addressee) = greatest(f.follower_id::uuid, f.followee_id::uuid))
on conflict do nothing;
