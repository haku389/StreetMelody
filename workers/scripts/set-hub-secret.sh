#!/bin/bash
# set-hub-secret.sh — ハブへの署名鍵を作り、中継とハブの2か所に同じ値で入れる
#
#   workers/scripts/set-hub-secret.sh
#
# **鍵は画面に出さない。** 変数の中だけで受け渡し、最後に消す。
#
# 1. 鍵を作る（openssl の乱数 32 バイト = hex 64 文字。カンマも = も入らない）
# 2. 中継（streetmelody-relay）の LIFE_OS_APP_SECRET に入れる
# 3. ハブ（Cloud Run の life-os-api）の APP_SECRETS に `streetmelody=<鍵>` を足す
#    **いまの名前（lifelevelup・dailybasket・stylecare など）は残したまま**足す。
#    APP_SECRETS は1つの環境変数に全部並んでいるので、丸ごと置き換えると
#    ほかのアプリが全部 401 になる
# 4. 入ったかを、名前と長さだけで確かめる
#
# 前提: gcloud にログイン済みで、lifelevelup プロジェクトの Cloud Run を更新できること。
#       wrangler にログイン済みであること。
set -euo pipefail

PROJECT=lifelevelup
REGION=asia-northeast1
SERVICE=life-os-api
APP=streetmelody
cd "$(dirname "$0")/.."

read_secrets() {
  gcloud run services describe "$SERVICE" --project "$PROJECT" --region "$REGION" --format=json |
    python3 -c "
import json, sys
d = json.load(sys.stdin)
for e in d['spec']['template']['spec']['containers'][0].get('env', []):
    if e['name'] == 'APP_SECRETS':
        if 'valueFrom' in e:
            sys.exit('APP_SECRETS が Secret Manager から来ている。このスクリプトでは書き換えられない')
        print(e.get('value', ''))
        break
"
}

names() { tr ',' '\n' | sed -n 's/=.*//p' | tr '\n' ' '; }

CUR=$(read_secrets)
echo "いまハブに入っている名前: $(printf '%s' "$CUR" | names)"

if printf '%s' "$CUR" | tr ',' '\n' | grep -q "^${APP}="; then
  echo "ハブにはもう ${APP} がある。作り直すなら、ハブと中継の両方を手で入れ替えること（片方だけ変えると 401）"
  exit 1
fi

# gcloud へ渡すときの区切りに「|」を使うので、いまの値に「|」があれば止める
if printf '%s' "$CUR" | grep -q '|'; then
  echo "いまの APP_SECRETS に「|」が入っていて、区切りと取り違える。手で入れること"
  exit 1
fi

NEW_KEY=$(openssl rand -hex 32)
trap 'unset NEW_KEY CUR' EXIT

echo "── 中継に入れる"
printf '%s' "$NEW_KEY" | npx wrangler secret put LIFE_OS_APP_SECRET >/dev/null
echo "  入れた"

echo "── ハブに足す（新しいリビジョンが出るまで1〜2分）"
# 値にカンマがあるので、gcloud の区切りを「|」に変える（^|^ の書き方）
gcloud run services update "$SERVICE" --project "$PROJECT" --region "$REGION" \
  --update-env-vars "^|^APP_SECRETS=${CUR},${APP}=${NEW_KEY}" --quiet >/dev/null
echo "  足した"

echo "── 確かめる（名前と長さだけ）"
# 鍵の値は出さない。名前と長さだけ（2026-10-15 に bash の書き方の誤りで
# ここが止まった。長さは python で数える）
read_secrets | python3 -c "
import sys
for p in sys.stdin.read().strip().split(','):
    n, _, k = p.partition('=')
    if n: print(f'  {n}（鍵 {len(k)} 文字）')
"
# 中継の配信と、ハブとの鍵が合っているか（何も積まない）
node scripts/check-deployed.mjs
