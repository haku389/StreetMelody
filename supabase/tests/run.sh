#!/bin/bash
# すれちがいの待ち行列の検査を、手元の Postgres で最初から流す
#
#   supabase/tests/run.sh
#
# Life_LevelUP の infra/database/test/run.sh と同じ形（Homebrew の PostgreSQL 17 を
# ポート 55433 で一時的に立てる）。前提: brew install postgresql@17
#
# 本番には当てない。migrations のうち、この検査が見る移行だけを流す
# （20261015130000 は public.profiles など共通プロジェクトの表に依るので、
#  冒頭のスキーマだけを 00_stub.sql に写してある）
set -euo pipefail

PGBIN="/opt/homebrew/opt/postgresql@17/bin"
PGDATA="/opt/homebrew/var/postgresql@17"
PORT=55433
DB="${DB:-streetmelody_verify}"

export PATH="$PGBIN:$PATH"
export LC_ALL="en_US.UTF-8"
cd "$(dirname "$0")/.."

started=0
if ! pg_isready -p "$PORT" >/dev/null 2>&1; then
  pg_ctl -D "$PGDATA" -o "-p $PORT" -l /tmp/pg17.log start >/dev/null
  started=1
  sleep 2
fi
cleanup() { if [ "$started" = "1" ]; then pg_ctl -D "$PGDATA" stop >/dev/null 2>&1 || true; fi; }
trap cleanup EXIT

run_all() {
  dropdb -p "$PORT" --if-exists "$DB" >/dev/null
  createdb -p "$PORT" "$DB"
  psql -p "$PORT" -d "$DB" -v ON_ERROR_STOP=1 -q -f tests/00_stub.sql >/dev/null
  psql -p "$PORT" -d "$DB" -v ON_ERROR_STOP=1 -q -f migrations/20261015170000_encounter_outbox.sql >/dev/null
  psql -p "$PORT" -d "$DB" -v ON_ERROR_STOP=1 -q -f migrations/20261015180000_encounter_days_no_anon.sql >/dev/null
  if [ -n "${MUTATION:-}" ]; then
    psql -p "$PORT" -d "$DB" -v ON_ERROR_STOP=1 -q -c "$MUTATION" >/dev/null
  fi
  psql -p "$PORT" -d "$DB" -v ON_ERROR_STOP=1 -q -f tests/01_encounter_checks.sql
}

if [ "${1:-}" != "--mutations" ]; then
  run_all
  exit 0
fi

# ── 守りを1つずつ壊して、検査が赤くなるかを見る
#
# **赤くならない守りは、検査が一度も触れていない。** 壊し方は「名前|SQL」
F="streetmelody.put_encounters(jsonb)"
MUTATIONS=(
  "表を authenticated に読ませる|grant select on streetmelody.encounter_days to authenticated;"
  "表へ直接書かせる|grant insert on streetmelody.encounter_days to authenticated;"
  "匿名の制限ポリシーを外す|drop policy no_anon on streetmelody.encounter_days;"
  "許可のポリシーを足す|create policy leak on streetmelody.encounter_days for select to authenticated using (true);"
  "anon に呼ばせる|grant execute on function $F to anon;"
  "未送信で他人の行も返す|create or replace function streetmelody.my_unsent_encounters(p_limit integer default 200) returns table (other_hash text, occurred_on date, occurred_at timestamptz, attempts integer) language sql stable security definer set search_path = '' as \$f\$ select d.other_hash, d.occurred_on, d.occurred_at, d.attempts from streetmelody.encounter_days d where d.sent_at is null and d.attempts < 5 order by d.occurred_at limit 500 \$f\$;"
  "他人の行に印を付けられる|create or replace function streetmelody.mark_my_encounters_sent(p_items jsonb, p_result jsonb default null) returns integer language plpgsql security definer set search_path = '' as \$f\$ declare n integer; begin update streetmelody.encounter_days d set sent_at = clock_timestamp(), hub_result = p_result from jsonb_to_recordset(coalesce(p_items, '[]'::jsonb)) as i(other_hash text, occurred_on date) where d.other_hash = i.other_hash and d.occurred_on = i.occurred_on and d.sent_at is null; get diagnostics n = row_count; return n; end; \$f\$;"
  "5回で諦めない|create or replace function streetmelody.my_unsent_encounters(p_limit integer default 200) returns table (other_hash text, occurred_on date, occurred_at timestamptz, attempts integer) language sql stable security definer set search_path = '' as \$f\$ select d.other_hash, d.occurred_on, d.occurred_at, d.attempts from streetmelody.encounter_days d where d.user_id = auth.uid() and d.sent_at is null order by d.occurred_at limit 500 \$f\$;"
)
# 関数の本文を変える壊し方は、関数の中の1行を置き換える形で作る
FN_MUTATIONS=(
  "自分とのすれちがいを許す|if other = uid then|if false then"
  "知らない相手を許す|if not exists (select 1 from auth.users u where u.id = other) then|if false then"
  "未来の時刻を許す|if seen_at > now() + interval '5 minutes' then|if false then"
  "古すぎる時刻を許す|if seen_at < now() - interval '30 days' then|if false then"
  "匿名を許す|if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then|if false then"
  "1日の上限を外す|if n >= 200 then|if false then"
  "UTC で刻む|on_day := (seen_at at time zone 'Asia/Tokyo')::date;|on_day := (seen_at at time zone 'UTC')::date;"
  # 一意の範囲を「日」から「時刻」へ（主キーと on conflict の両方を変える。§ で区切る）
  "同じ人と同じ日を何件でも積める|primary key (user_id, other_hash, occurred_on)§on conflict (user_id, other_hash, occurred_on) do nothing|primary key (user_id, other_hash, occurred_at)§on conflict (user_id, other_hash, occurred_at) do nothing"
  "大文字の uuid で別の鍵になる|sha256(convert_to(lower(other::text), 'UTF8'))|sha256(convert_to(upper(other::text), 'UTF8'))"
)

fail=0
check() {
  local name="$1"
  printf '%-30s ' "$name"
  if run_all >/tmp/sm-mutate.log 2>&1; then
    echo "緑のまま ← この守りは検査されていない"; fail=1
  elif grep -q "FAIL:" /tmp/sm-mutate.log; then
    echo "赤くなった"
  else
    echo "別の理由で落ちた ← 壊し方を見直す"; sed -n '1,3p' /tmp/sm-mutate.log | sed 's/^/    /'; fail=1
  fi
}

for m in "${MUTATIONS[@]}"; do
  MUTATION="${m#*|}" check "${m%%|*}"
done

MIG=migrations/20261015170000_encounter_outbox.sql
cp "$MIG" /tmp/sm-mig.orig
restore() { cp /tmp/sm-mig.orig "$MIG"; }
trap 'restore; cleanup' EXIT
for m in "${FN_MUTATIONS[@]}"; do
  IFS='|' read -r name from to <<<"$m"
  restore
  # from / to は「§」で区切って複数の置き換えを並べられる（同じ数だけ）
  if ! python3 -c "
import sys
p, frm, to = sys.argv[1], sys.argv[2].split('§'), sys.argv[3].split('§')
assert len(frm) == len(to)
s = open(p).read()
for a, b in zip(frm, to):
    assert s.count(a) == 1, a
    s = s.replace(a, b)
open(p, 'w').write(s)
" "$MIG" "$from" "$to" 2>/dev/null; then
    printf '%-30s 壊せなかった ← 文字列が1か所に定まらない\n' "$name"; fail=1; continue
  fi
  MUTATION="" check "$name"
done
restore

echo
if [ "$fail" = "0" ]; then echo "=== すべての守りが検査されている ==="; else echo "=== 検査されていない守りがある ==="; exit 1; fi
