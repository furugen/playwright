#!/bin/bash

# Playwright MCP SSE サーバー 完全自動デプロイスクリプト

set -e

echo "🎯 Playwright MCP SSE サーバー 完全自動デプロイ"
echo "=============================================="
echo ""

# Google Cloud SDK の確認
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK がインストールされていません"
    echo ""
    echo "インストール方法:"
    echo "macOS: brew install google-cloud-sdk"
    echo "Linux: curl https://sdk.cloud.google.com | bash"
    echo "Windows: https://cloud.google.com/sdk/docs/install"
    echo ""
    exit 1
fi

# 認証確認
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
    echo "⚠️  GCP 認証が必要です"
    echo "実行中: gcloud auth login"
    gcloud auth login
fi

echo "✅ 必要な準備が完了しています"
echo ""

# ステップ1: 環境設定
echo "🔧 ステップ1: 環境設定"
echo "===================="
if [ ! -f .env ]; then
    echo "環境設定を開始します..."
    ./setup-env.sh
else
    echo "✅ 環境設定ファイル (.env) が既に存在します"
    source .env
    echo "プロジェクト: $GOOGLE_CLOUD_PROJECT"
fi

echo ""

# ステップ2: GCP セットアップ
echo "🔧 ステップ2: GCP セットアップ"
echo "=========================="
echo "GCP API とサービスアカウントを設定します..."
./deploy-setup.sh

echo ""

# ステップ3: リポジトリ準備
echo "📦 ステップ3: リポジトリ準備"
echo "========================="
echo "Playwright MCP リポジトリを準備します..."
./prepare-repo.sh

echo ""

# ステップ4: 設定ファイル作成
echo "⚙️  ステップ4: デプロイ設定作成"
echo "============================"
echo "超低コスト設定ファイルを作成します..."
./create-config-files.sh

echo ""

# ステップ5: デプロイ実行
echo "🚀 ステップ5: デプロイ実行"
echo "====================="
echo "いよいよデプロイを実行します！"
echo ""

read -p "デプロイを開始しますか？ (y/N): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
    ./deploy.sh
else
    echo "デプロイをキャンセルしました"
    echo "後で ./deploy.sh を実行してデプロイできます"
fi

echo ""
echo "🎉 完全自動デプロイ処理が完了しました！"
echo ""
echo "作成されたファイル:"
echo "- .env (環境設定)"
echo "- playwright-mcp-source/ (ソースコード)"
echo "- deploy.sh (デプロイスクリプト)"
echo ""
echo "管理コマンド:"
echo "- デプロイ状況確認: gcloud run services list"
echo "- ログ確認: gcloud logs read"
echo "- サービス削除: gcloud run services delete playwright-mcp-minimal"
echo ""