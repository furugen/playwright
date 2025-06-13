#!/bin/bash

# Playwright MCP 超低コスト デプロイスクリプト

set -e

echo "🚀 Playwright MCP SSE サーバー デプロイ開始"
echo "=========================================="

# 環境変数読み込み
if [ ! -f .env ]; then
    echo "❌ .env ファイルが見つかりません"
    exit 1
fi

source .env

WORK_DIR="playwright-mcp-source"

if [ ! -d "$WORK_DIR" ]; then
    echo "❌ ソースディレクトリが見つかりません"
    exit 1
fi

echo "📋 デプロイ情報:"
echo "- プロジェクト: $GOOGLE_CLOUD_PROJECT"
echo "- リージョン: $GOOGLE_CLOUD_REGION"  
echo "- サービス名: $SERVICE_NAME"
echo "- リソース: CPU $CPU, メモリ $MEMORY"

cd "$WORK_DIR"

# Cloud Build でデプロイ実行
echo ""
echo "☁️  Cloud Build でデプロイ中..."
echo "（これには数分かかる場合があります）"

gcloud builds submit \
    --config=cloudbuild-minimal.yaml \
    --substitutions=COMMIT_SHA=$(git rev-parse --short HEAD) \
    .

# デプロイ状況確認
echo ""
echo "📊 デプロイ状況確認中..."

# サービス情報取得
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$GOOGLE_CLOUD_REGION \
    --format='value(status.url)')

echo ""
echo "🎉 デプロイ完了！"
echo "=================="
echo ""
echo "📡 サービス URL: $SERVICE_URL"
echo "🌍 リージョン: $GOOGLE_CLOUD_REGION"
echo "💰 設定: 超低コスト（月額 \$0-5 目標）"
echo ""
echo "接続テスト:"
echo "curl -N \"$SERVICE_URL/sse\""
echo ""
echo "管理コマンド:"
echo "gcloud run services describe $SERVICE_NAME --region=$GOOGLE_CLOUD_REGION"
echo "gcloud run services delete $SERVICE_NAME --region=$GOOGLE_CLOUD_REGION"
echo ""

cd ..
