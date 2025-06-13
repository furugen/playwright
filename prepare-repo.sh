#!/bin/bash

# Playwright MCP リポジトリ準備スクリプト

set -e

echo "📦 Playwright MCP リポジトリ準備"
echo "================================"

# .env ファイルの確認
if [ ! -f .env ]; then
    echo "❌ .env ファイルが見つかりません"
    echo "先に ./setup-env.sh を実行してください"
    exit 1
fi

source .env

# 作業ディレクトリの準備
WORK_DIR="playwright-mcp-source"

if [ -d "$WORK_DIR" ]; then
    echo "📁 既存のソースディレクトリを削除中..."
    rm -rf "$WORK_DIR"
fi

echo "📥 playwright-mcp リポジトリをクローン中..."
git clone https://github.com/microsoft/playwright-mcp.git "$WORK_DIR"

cd "$WORK_DIR"

echo "📋 リポジトリ情報:"
echo "- リポジトリ: $(git remote get-url origin)"
echo "- ブランチ: $(git branch --show-current)"
echo "- 最新コミット: $(git log -1 --pretty=format:'%h %s')"

# package.json の確認
if [ -f package.json ]; then
    echo ""
    echo "📦 package.json 情報:"
    echo "- 名前: $(jq -r '.name' package.json)"
    echo "- バージョン: $(jq -r '.version' package.json)"
    echo "- Node.js要件: $(jq -r '.engines.node // "未指定"' package.json)"
else
    echo "⚠️  package.json が見つかりません"
fi

# 依存関係のインストール
echo ""
echo "📦 依存関係をインストール中..."
npm install

# TypeScript ビルドのテスト
echo ""
echo "🔨 TypeScript ビルドテスト中..."
if npm run build; then
    echo "✅ ビルド成功"
else
    echo "❌ ビルドエラー - package.json を確認してください"
    exit 1
fi

# 元のディレクトリに戻る
cd ..

echo ""
echo "✅ Playwright MCP リポジトリ準備完了"
echo "📁 ソースディレクトリ: $WORK_DIR"
echo ""
echo "次のステップ:"
echo "./create-config-files.sh でデプロイ設定を作成"