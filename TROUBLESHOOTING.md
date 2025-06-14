# Playwright MCP SSE サーバー トラブルシューティングガイド

## よくある問題と解決策

### 1. Google Cloud SDK 関連

#### 問題: `gcloud: command not found`
```bash
# 解決策: Google Cloud SDK をインストール
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# インストール後の初期設定
gcloud init
```

#### 問題: 認証エラー
```bash
# 解決策: 再認証
gcloud auth login
gcloud auth application-default login

# 認証状況確認
gcloud auth list
```

### 2. プロジェクト設定関連

#### 問題: プロジェクトが見つからない
```bash
# プロジェクト一覧確認
gcloud projects list

# プロジェクト作成
gcloud projects create YOUR-PROJECT-ID

# プロジェクト設定
gcloud config set project YOUR-PROJECT-ID
```

#### 問題: API が有効化されていない
```bash
# 必要な API を一括有効化
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  containerregistry.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com
```

### 3. ビルド・デプロイ関連

#### 問題: Docker ビルドエラー
```bash
# ログ確認
gcloud builds log [BUILD_ID]

# よくある原因と解決策:
# 1. メモリ不足 → Cloud Build のマシンタイプを変更
# 2. タイムアウト → cloudbuild.yaml の timeout を増加
# 3. 依存関係エラー → package.json を確認
```

#### 問題: Cloud Run デプロイエラー
```bash
# サービス状況確認
gcloud run services describe playwright-mcp-minimal \
  --region=us-central1

# ログ確認
gcloud logs read \
  "resource.type=cloud_run_revision" \
  --limit=50

# よくある解決策:
# 1. メモリ不足 → memory を 1Gi に増加
gcloud run services update playwright-mcp-minimal \
  --memory=1Gi --region=us-central1

# 2. タイムアウト → timeout を増加
gcloud run services update playwright-mcp-minimal \
  --timeout=600s --region=us-central1
```

### 4. SSE 接続関連

#### 問題: SSE 接続ができない
```bash
# サービス URL 確認
SERVICE_URL=$(gcloud run services describe playwright-mcp-minimal \
  --region=us-central1 --format='value(status.url)')

echo "Service URL: $SERVICE_URL"

# 接続テスト
curl -v "$SERVICE_URL/health"
curl -N "$SERVICE_URL/sse"

# よくある原因:
# 1. サービスが起動していない → ログ確認
# 2. ポート設定ミス → 8080 ポートを確認
# 3. ヘルスチェック失敗 → /health エンドポイント確認
```

#### 問題: n8n MCP 接続エラー "Could not connect to your MCP server"

**症状**: n8nでMCPサーバーへの接続時に500エラーが発生

**原因と解決策**:

1. **missing `/rest/dynamic-node-parameters/options` エンドポイント**
```bash
# 確認方法
curl -X POST "$SERVICE_URL/rest/dynamic-node-parameters/options" \
  -H "Content-Type: application/json" -d '{}'

# 正常な場合: ツールリストのJSONが返される
```

2. **SSE メッセージ処理の404エラー**
```bash
# ログ確認
gcloud run services logs read playwright-mcp-minimal \
  --region=us-central1 \
  --format="value(timestamp,textPayload)" \
  | grep -E "(POST.*messages|404)"

# よくあるエラー:
# POST 404 /messages?sessionId=xxx
```

**修正が必要なファイル**: `src/sseServer.ts`

**必要な修正内容**:
1. **動的パラメータエンドポイントの追加**:
```typescript
// Dynamic node parameters endpoint (for n8n)
this.app.post('/rest/dynamic-node-parameters/options', async (req, res) => {
  const tools = [
    { name: 'playwright_navigate', value: 'playwright_navigate', description: 'Navigate to a URL' },
    { name: 'playwright_screenshot', value: 'playwright_screenshot', description: 'Take a screenshot' },
    // ... 他のツール
  ];
  res.json({ options: tools });
});
```

2. **SSE メッセージ処理の修正**:
```typescript
// /messages エンドポイントでhandlePostMessageを使用
await transport.handlePostMessage(req, res);
```

3. **CORS設定の改善**:
```typescript
res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
res.header('Access-Control-Allow-Credentials', 'true');
```

4. **詳細ログの追加**:
```typescript
console.log(`Messages endpoint called with sessionId: ${sessionId}`);
console.log(`Active transports: ${Object.keys(this.transports).join(', ')}`);
```

**デプロイ手順**:
```bash
# ビルド
npm run build

# デプロイ
./deploy.sh

# 接続テスト
curl -X POST "$SERVICE_URL/test-connection" -H "Content-Type: application/json" -d '{}'
```

**n8n設定**:
- URL: `https://playwright-mcp-minimal-nzfsbenaoq-uc.a.run.app/sse`
- 認証: 無効化
- プロトコル: SSE

### 5. コスト関連

#### 問題: 想定より高いコスト
```bash
# リソース使用量確認
gcloud run services describe playwright-mcp-minimal \
  --region=us-central1 \
  --format="table(metadata.name,spec.template.metadata.annotations)"

# コスト削減設定
# 1. 最小インスタンス数を 0 に
gcloud run services update playwright-mcp-minimal \
  --min-instances=0 --region=us-central1

# 2. CPU とメモリを最小に
gcloud run services update playwright-mcp-minimal \
  --memory=512Mi --cpu=0.5 --region=us-central1

# 3. 同時実行数を制限
gcloud run services update playwright-mcp-minimal \
  --concurrency=5 --region=us-central1
```

### 6. パフォーマンス関連

#### 問題: 起動が遅い（コールドスタート）
```bash
# 解決策1: 最小インスタンス数を1に（コスト増加）
gcloud run services update playwright-mcp-minimal \
  --min-instances=1 --region=us-central1

# 解決策2: より軽量な設定に最適化
# → Dockerfile.minimal を再確認
```

#### 問題: メモリ不足エラー
```bash
# ログでメモリ使用量確認
gcloud logs read \
  "resource.type=cloud_run_revision AND textPayload:memory" \
  --limit=10

# メモリ増加（段階的に）
gcloud run services update playwright-mcp-minimal \
  --memory=1Gi --region=us-central1
```

### 7. セキュリティ関連

#### 問題: 認証エラー
```bash
# サービスアカウント確認
gcloud iam service-accounts list

# 権限確認
gcloud projects get-iam-policy YOUR-PROJECT-ID

# 権限追加（必要最小限）
gcloud projects add-iam-policy-binding YOUR-PROJECT-ID \
  --member="serviceAccount:playwright-mcp-minimal-sa@YOUR-PROJECT-ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
```

## 診断コマンド集

### 全体状況確認
```bash
# 環境確認スクリプト
cat > check-status.sh << 'EOF'
#!/bin/bash
echo "=== 環境確認 ==="
echo "GCP Project: $(gcloud config get-value project)"
echo "Region: $(gcloud config get-value compute/region)"
echo "Account: $(gcloud config get-value account)"

echo ""
echo "=== サービス状況 ==="
gcloud run services list

echo ""
echo "=== 最新のログ ==="
gcloud logs read "resource.type=cloud_run_revision" --limit=5

echo ""
echo "=== API 有効化状況 ==="
gcloud services list --enabled --filter="name:(cloudbuild OR run OR containerregistry)"
EOF

chmod +x check-status.sh
./check-status.sh
```

### リソース使用量監視
```bash
# 使用量監視スクリプト
cat > monitor-usage.sh << 'EOF'
#!/bin/bash
SERVICE_NAME="playwright-mcp-minimal"
REGION="us-central1"

echo "=== リソース使用量 ==="
gcloud run services describe $SERVICE_NAME \
  --region=$REGION \
  --format="table(
    metadata.name,
    spec.template.metadata.annotations['run.googleapis.com/cpu'],
    spec.template.metadata.annotations['run.googleapis.com/memory'],
    spec.template.metadata.annotations['autoscaling.knative.dev/minScale'],
    spec.template.metadata.annotations['autoscaling.knative.dev/maxScale']
  )"

echo ""
echo "=== アクセス統計 ==="
gcloud logging read \
  "resource.type=cloud_run_revision AND httpRequest.status>=200" \
  --format="table(timestamp,httpRequest.requestMethod,httpRequest.status)" \
  --limit=10
EOF

chmod +x monitor-usage.sh
```

### 完全クリーンアップ
```bash
# 全削除スクリプト（注意：全て削除されます）
cat > cleanup.sh << 'EOF'
#!/bin/bash
echo "⚠️  警告: 全てのリソースを削除します"
read -p "続行しますか？ (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
  # Cloud Run サービス削除
  gcloud run services delete playwright-mcp-minimal \
    --region=us-central1 --quiet

  # コンテナイメージ削除
  gcloud container images delete gcr.io/$(gcloud config get-value project)/playwright-mcp-minimal \
    --force-delete-tags --quiet

  # サービスアカウント削除
  gcloud iam service-accounts delete \
    playwright-mcp-minimal-sa@$(gcloud config get-value project).iam.gserviceaccount.com \
    --quiet

  echo "✅ クリーンアップ完了"
else
  echo "❌ クリーンアップをキャンセルしました"
fi
EOF

chmod +x cleanup.sh
```

## サポート情報

### 有用なリンク
- [Cloud Run ドキュメント](https://cloud.google.com/run/docs)
- [Cloud Build ドキュメント](https://cloud.google.com/build/docs)
- [Playwright MCP GitHub](https://github.com/microsoft/playwright-mcp)

### ログレベル調整
環境変数 `LOG_LEVEL` を調整してデバッグ情報を取得:
```bash
gcloud run services update playwright-mcp-minimal \
  --set-env-vars=LOG_LEVEL=debug \
  --region=us-central1
```

### 緊急時の対応
1. **サービス停止**: `gcloud run services delete`
2. **ロールバック**: 以前のリビジョンに戻す
3. **リソース制限**: CPU/メモリを最小値に設定