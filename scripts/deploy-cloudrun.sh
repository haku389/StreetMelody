#!/usr/bin/env bash
#
# deploy-cloudrun.sh — StreetMelody API を Google Cloud Run にデプロイする
#
# 前提（あなたの環境で一度だけ）:
#   1) gcloud CLI をインストール: brew install --cask google-cloud-sdk
#   2) ログイン:                  gcloud auth login
#   3) プロジェクト選択:          gcloud config set project <YOUR_GCP_PROJECT_ID>
#      （課金が有効な GCP プロジェクトが必要）
#
# 使い方（リポジトリ直下で）:
#   bash scripts/deploy-cloudrun.sh
#   # 任意で上書き: PROJECT_ID=xxx REGION=asia-northeast1 SERVICE=streetmelody-api bash scripts/deploy-cloudrun.sh
#
# ※ `--source .` で Cloud Build がリモートでコンテナをビルドするため、ローカル docker は不要。
#    ルートの Dockerfile が使われる。
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-asia-northeast1}"          # Supabase が東京なので近接リージョン
SERVICE="${SERVICE:-streetmelody-api}"

# Supabase 接続（公開 anon キー。秘密ではない）
# 2026-10-22 から StyleCare のプロジェクト（共通アカウント）の streetmelody スキーマを読む
SUPABASE_URL="${SUPABASE_URL:-https://oaurexinrtvzvtvotqaw.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_JuWP6MzIP_zeWDGsoQLwAA_flKbS71V}"
SUPABASE_SCHEMA="${SUPABASE_SCHEMA:-streetmelody}"
# カタログはログインした人だけが読める。サーバーが読むには Supabase の秘密の鍵（sb_secret_…）を
# Secret Manager の streetmelody-supabase-secret に入れておく（無ければ埋め込みの見本で動く）
SECRET_FLAG=""
if gcloud secrets describe streetmelody-supabase-secret --project "$PROJECT_ID" >/dev/null 2>&1; then
  SECRET_FLAG="--set-secrets=SUPABASE_SECRET_KEY=streetmelody-supabase-secret:latest"
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "ERROR: GCP プロジェクトが未設定です。 gcloud config set project <ID> を実行するか PROJECT_ID=... を指定してください。" >&2
  exit 1
fi

echo "▶ project=$PROJECT_ID region=$REGION service=$SERVICE"

# 必要な API を有効化（初回のみ時間がかかる）
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  --project "$PROJECT_ID"

# Cloud Build（ソースデプロイ）は Compute デフォルト SA を使う。
# 既定ではビルド/ソース読取の権限が無く PERMISSION_DENIED になるため、builder ロールを付与する。
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
echo "▶ grant roles/cloudbuild.builds.builder to ${COMPUTE_SA}"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/cloudbuild.builds.builder" \
  --condition=None >/dev/null
echo "  （IAM 反映に数十秒かかることがあります。失敗したら少し待って再実行してください）"

# デプロイ（ソースから。Cloud Build が Dockerfile をビルド）
# --quiet で Artifact Registry リポジトリ作成の確認プロンプトを自動承認
gcloud run deploy "$SERVICE" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --source . \
  --allow-unauthenticated \
  --port 8080 \
  --cpu 1 --memory 256Mi --min-instances 0 --max-instances 2 \
  --set-env-vars "SUPABASE_URL=${SUPABASE_URL},SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY},SUPABASE_SCHEMA=${SUPABASE_SCHEMA}" \
  ${SECRET_FLAG} \
  --quiet

echo ""
URL="$(gcloud run services describe "$SERVICE" --project "$PROJECT_ID" --region "$REGION" --format='value(status.url)')"
echo "✅ デプロイ完了: $URL"
echo "   動作確認: curl $URL/api/tracks"
echo ""
echo "次の手順: iOS のリリース用 baseURL（apps/ios/StreetMelody/Services/APIService.swift の #else 側）を"
echo "          \"$URL/api\" に更新するか、カスタムドメイン api.streetmelody.app を Cloud Run にマッピングしてください。"
