#!/bin/bash

# Playwright MCP SSE サーバー GCP デプロイ環境設定スクリプト

set -e

echo "🚀 Playwright MCP SSE サーバー GCP デプロイ環境設定"
echo "=================================================="

# プロジェクトIDの入力
read -p "GCP プロジェクト ID を入力してください: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ プロジェクトIDが必要です"
    exit 1
fi

# リージョンの選択
echo ""
echo "リージョンを選択してください:"
echo "1) us-central1 (アイオワ - 最安)"
echo "2) asia-northeast1 (東京)"
echo "3) europe-west1 (ベルギー)"
read -p "選択 (1-3) [デフォルト: 1]: " REGION_CHOICE

case $REGION_CHOICE in
    2)
        REGION="asia-northeast1"
        ZONE="asia-northeast1-a"
        ;;
    3)
        REGION="europe-west1"
        ZONE="europe-west1-b"
        ;;
    *)
        REGION="us-central1"
        ZONE="us-central1-a"
        ;;
esac

# .env ファイル作成
cat > .env << EOF
# Playwright MCP SSE サーバー GCP 設定
GOOGLE_CLOUD_PROJECT=$PROJECT_ID
GOOGLE_CLOUD_REGION=$REGION
GOOGLE_CLOUD_ZONE=$ZONE
CONTAINER_REGISTRY=gcr.io/$PROJECT_ID
SERVICE_NAME=playwright-mcp-minimal

# アプリケーション設定
NODE_ENV=production
BROWSER=chromium
HEADLESS=true
PORT=8080
TIMEOUT=300000

# Cloud Run 超低コスト設定
MEMORY=512Mi
CPU=0.5
MIN_INSTANCES=0
MAX_INSTANCES=3
CONCURRENCY=5

# セキュリティ設定
SERVICE_ACCOUNT_EMAIL=playwright-mcp-minimal-sa@$PROJECT_ID.iam.gserviceaccount.com

# ログ設定
LOG_LEVEL=info
DEBUG=false
EOF

echo ""
echo "✅ 環境設定ファイル (.env) を作成しました"
echo "📁 ファイル場所: $(pwd)/.env"
echo ""
echo "設定内容:"
echo "- プロジェクトID: $PROJECT_ID"
echo "- リージョン: $REGION"
echo "- ゾーン: $ZONE"
echo ""

# Google Cloud SDK の確認
if ! command -v gcloud &> /dev/null; then
    echo "⚠️  Google Cloud SDK がインストールされていません"
    echo ""
    echo "インストール方法:"
    echo "macOS: brew install google-cloud-sdk"
    echo "Linux: curl https://sdk.cloud.google.com | bash"
    echo "Windows: https://cloud.google.com/sdk/docs/install"
    echo ""
    echo "インストール後、以下のコマンドを実行してください:"
    echo "gcloud auth login"
    echo "gcloud config set project $PROJECT_ID"
    echo ""
else
    echo "✅ Google Cloud SDK が見つかりました"
    
    # 認証確認
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
        echo "✅ GCP 認証済み"
    else
        echo "⚠️  GCP 認証が必要です"
        echo "実行: gcloud auth login"
    fi
    
    # プロジェクト設定
    echo "🔧 プロジェクト設定中..."
    gcloud config set project $PROJECT_ID
    gcloud config set compute/region $REGION
    gcloud config set compute/zone $ZONE
    
    echo "✅ GCP 設定完了"
fi

echo ""
echo "次のステップ:"
echo "1. ./deploy-setup.sh を実行してGCP APIを有効化"
echo "2. ./deploy.sh を実行してデプロイ開始"
echo ""