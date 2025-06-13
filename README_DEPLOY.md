# Playwright MCP SSE サーバー GCP デプロイ 実行手順

## 🎯 概要
Microsoft の Playwright MCP サーバーを Server-Sent Events（SSE）サーバーとして Google Cloud Platform に超低コスト（月額 $0-5）でデプロイする完全ガイドです。

## 📋 前提条件
- Google Cloud アカウント（無料枠有効）
- Git がインストール済み
- Node.js 18+ がインストール済み
- ターミナル/コマンドプロンプトへのアクセス

## 🚀 クイックスタート（推奨）

### ワンクリックデプロイ
```bash
# 完全自動デプロイ（推奨）
./full-deploy.sh
```

このスクリプトが全ての作業を自動化します：
1. 環境設定
2. GCP セットアップ
3. リポジトリ準備
4. 設定ファイル作成
5. デプロイ実行

## 📝 手動実行（ステップバイステップ）

### ステップ 1: 環境設定
```bash
# 環境変数を設定
./setup-env.sh
```

この段階で以下の情報を入力します：
- GCP プロジェクト ID
- デプロイリージョン（us-central1 推奨）

### ステップ 2: GCP セットアップ
```bash
# GCP API とサービスアカウントを設定
./deploy-setup.sh
```

自動で以下が実行されます：
- 必要な API の有効化
- サービスアカウントの作成
- IAM 権限の設定
- Docker 認証の設定

### ステップ 3: リポジトリ準備
```bash
# Playwright MCP リポジトリをクローン・準備
./prepare-repo.sh
```

### ステップ 4: 設定ファイル作成
```bash
# 超低コスト設定ファイルを作成
./create-config-files.sh
```

### ステップ 5: デプロイ実行
```bash
# 実際にデプロイを実行
./deploy.sh
```

## 🔧 作成されるファイル

### 環境設定
- `.env` - 環境変数設定
- `.env.example` - 環境変数テンプレート

### デプロイ設定
- `playwright-mcp-source/Dockerfile.minimal` - 超軽量 Docker 設定
- `playwright-mcp-source/cloudbuild-minimal.yaml` - Cloud Build 設定
- `playwright-mcp-source/service-minimal.yaml` - Cloud Run サービス設定
- `playwright-mcp-source/.dockerignore` - Docker ビルド除外設定

### 実行スクリプト
- `setup-env.sh` - 環境設定
- `deploy-setup.sh` - GCP セットアップ
- `prepare-repo.sh` - リポジトリ準備
- `create-config-files.sh` - 設定ファイル作成
- `deploy.sh` - デプロイ実行
- `full-deploy.sh` - 完全自動デプロイ

### ドキュメント
- `DEPLOY_PLAN.md` - 詳細なデプロイ計画
- `TROUBLESHOOTING.md` - トラブルシューティングガイド

## 💰 超低コスト設定の詳細

### リソース設定
- **CPU**: 0.5 vCPU
- **メモリ**: 512MB
- **最小インスタンス**: 0（完全オンデマンド）
- **最大インスタンス**: 3
- **同時接続数**: 5

### 想定コスト
- **超軽量使用**（月5,000リクエスト）: $0（無料枠内）
- **軽量使用**（月50,000リクエスト）: $1-2
- **中程度使用**（月200,000リクエスト）: $3-6

## 🌐 デプロイ後の操作

### サービス URL 確認
```bash
# デプロイ後に表示される URL、または以下で確認
gcloud run services describe playwright-mcp-minimal \
  --region=us-central1 --format='value(status.url)'
```

### SSE 接続テスト
```bash
# サービス URL を取得
SERVICE_URL=$(gcloud run services describe playwright-mcp-minimal \
  --region=us-central1 --format='value(status.url)')

# SSE 接続テスト
curl -N "$SERVICE_URL/sse"

# ヘルスチェック
curl "$SERVICE_URL/health"
```

### ログ確認
```bash
# リアルタイムログ
gcloud logs tail \
  "resource.type=cloud_run_revision AND resource.labels.service_name=playwright-mcp-minimal"

# 過去のログ
gcloud logs read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=playwright-mcp-minimal" \
  --limit=50
```

## 🛠️ 管理コマンド

### サービス管理
```bash
# サービス一覧
gcloud run services list

# サービス詳細
gcloud run services describe playwright-mcp-minimal --region=us-central1

# サービス更新（メモリ増加例）
gcloud run services update playwright-mcp-minimal \
  --memory=1Gi --region=us-central1

# サービス削除
gcloud run services delete playwright-mcp-minimal --region=us-central1
```

### リソース監視
```bash
# CPU/メモリ使用量確認
gcloud monitoring metrics list --filter="resource.type=cloud_run_revision"

# アクセス統計
gcloud logs read \
  "resource.type=cloud_run_revision AND httpRequest.status>=200" \
  --format="table(timestamp,httpRequest.requestMethod,httpRequest.status)" \
  --limit=20
```

## 🔍 トラブルシューティング

問題が発生した場合は、`TROUBLESHOOTING.md` を参照してください。

### よくある問題
1. **Google Cloud SDK 未インストール** → インストールガイド参照
2. **認証エラー** → `gcloud auth login` 実行
3. **メモリ不足** → メモリを 1GB に増加
4. **コールドスタート遅延** → 最小インスタンスを 1 に設定

### 診断コマンド
```bash
# 全体状況確認
gcloud run services list
gcloud logs read "resource.type=cloud_run_revision" --limit=5

# リソース使用量確認
gcloud run services describe playwright-mcp-minimal \
  --region=us-central1 \
  --format="value(spec.template.metadata.annotations)"
```

## 🔐 セキュリティ

### 最小権限設定
作成されるサービスアカウントには必要最小限の権限のみ付与：
- `roles/logging.logWriter` - ログ書き込み
- `roles/monitoring.metricWriter` - メトリクス書き込み
- `roles/cloudtrace.agent` - トレース

### ネットワークセキュリティ
- デフォルトで全てのトラフィックを許可
- 必要に応じて VPC やファイアウォールルールで制限可能

## 📞 サポート

### 公式ドキュメント
- [Playwright MCP GitHub](https://github.com/microsoft/playwright-mcp)
- [Google Cloud Run](https://cloud.google.com/run/docs)
- [Google Cloud Build](https://cloud.google.com/build/docs)

### コミュニティ
- [Playwright Discord](https://discord.gg/playwright)
- [Google Cloud Community](https://cloud.google.com/community)

---

**注意**: この設定は超低コスト運用に最適化されています。高負荷環境では適切にスケールアップしてください。