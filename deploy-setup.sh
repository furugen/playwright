#!/bin/bash

# GCP API 有効化とサービスアカウント設定スクリプト

set -e

# .env ファイルの読み込み
if [ -f .env ]; then
    source .env
else
    echo "❌ .env ファイルが見つかりません"
    echo "先に ./setup-env.sh を実行してください"
    exit 1
fi

echo "🔧 GCP セットアップ開始"
echo "プロジェクト: $GOOGLE_CLOUD_PROJECT"
echo "リージョン: $GOOGLE_CLOUD_REGION"
echo "========================="

# 必要な API を有効化
echo "📡 必要な API を有効化中..."

APIS=(
    "cloudbuild.googleapis.com"
    "run.googleapis.com" 
    "containerregistry.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "iam.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo "  ✓ $api を有効化中..."
    gcloud services enable $api --quiet
done

echo "✅ API 有効化完了"

# サービスアカウント作成
echo ""
echo "👤 サービスアカウント設定中..."

SA_NAME="playwright-mcp-minimal-sa"
SA_EMAIL="$SA_NAME@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com"

# サービスアカウントが存在するかチェック
if gcloud iam service-accounts describe $SA_EMAIL >/dev/null 2>&1; then
    echo "✅ サービスアカウント $SA_NAME は既に存在します"
else
    echo "  ✓ サービスアカウント $SA_NAME を作成中..."
    gcloud iam service-accounts create $SA_NAME \
        --display-name="Playwright MCP Minimal Service Account" \
        --description="Service account for Playwright MCP minimal deployment"
fi

# 必要最小限の権限を付与
echo "  ✓ IAM 権限を設定中..."

ROLES=(
    "roles/logging.logWriter"
    "roles/monitoring.metricWriter"
    "roles/cloudtrace.agent"
)

for role in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$role" \
        --quiet
done

echo "✅ サービスアカウント設定完了"

# Docker 認証設定
echo ""
echo "🐳 Docker 認証設定中..."
gcloud auth configure-docker --quiet
echo "✅ Docker 認証設定完了"

# ビルド用ディレクトリ作成
echo ""
echo "📁 ビルド環境準備中..."
mkdir -p build/
echo "✅ ビルド環境準備完了"

echo ""
echo "🎉 GCP セットアップが完了しました！"
echo ""
echo "設定内容:"
echo "- プロジェクト: $GOOGLE_CLOUD_PROJECT"
echo "- リージョン: $GOOGLE_CLOUD_REGION"
echo "- サービスアカウント: $SA_EMAIL"
echo "- コンテナレジストリ: $CONTAINER_REGISTRY"
echo ""
echo "次のステップ:"
echo "1. playwright-mcp リポジトリを準備"
echo "2. ./create-config-files.sh でデプロイ設定ファイル作成"
echo "3. ./deploy.sh でデプロイ実行"
echo ""