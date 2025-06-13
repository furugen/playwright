# Playwright MCP SSE サーバー 超低コスト GCP デプロイ計画書

## 超低コスト構成の概要

### コスト目標
- **月額**: $0-5（無料枠最大活用）
- **基本方針**: 必要最小限のリソースで運用

## 最適化されたアーキテクチャ

### 超軽量構成
- **CPU**: 0.5 vCPU
- **メモリ**: 512MB
- **最小インスタンス**: 0（完全オンデマンド）
- **最大インスタンス**: 3
- **同時接続数**: 5

## デプロイメント設定（超低コスト版）

### 1. 最適化された Cloud Build 設定
```yaml
# cloudbuild-minimal.yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/playwright-mcp-minimal:$COMMIT_SHA', '-f', 'Dockerfile.minimal', '.']
  
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/playwright-mcp-minimal:$COMMIT_SHA']
  
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'playwright-mcp-minimal'
      - '--image=gcr.io/$PROJECT_ID/playwright-mcp-minimal:$COMMIT_SHA'
      - '--platform=managed'
      - '--region=us-central1'  # 最安リージョン
      - '--allow-unauthenticated'
      - '--port=8080'
      - '--memory=512Mi'
      - '--cpu=0.5'
      - '--timeout=300s'  # 5分に短縮
      - '--concurrency=5'
      - '--min-instances=0'  # 完全オンデマンド
      - '--max-instances=3'
      - '--set-env-vars=NODE_ENV=production,BROWSER=chromium'
```

### 2. 超軽量 Dockerfile
```dockerfile
# Dockerfile.minimal - 最小構成
FROM node:18-alpine AS base

# 必要最小限のシステム依存関係のみ
RUN apk add --no-cache \
    chromium \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Chromium パスを環境変数で指定
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/bin/chromium-browser

WORKDIR /app

# package.json のみ先にコピー（キャッシュ最適化）
COPY package*.json ./

# 本番依存関係のみインストール
RUN npm ci --only=production --silent

# ソースコードコピー
COPY . .

# TypeScript ビルド
RUN npm run build

# 不要ファイル削除（イメージサイズ削減）
RUN rm -rf src/ tests/ node_modules/@types/ *.md

# 非特権ユーザーで実行
USER node

EXPOSE 8080

# 軽量ヘルスチェック
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=2 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# 最小リソースでの起動
CMD ["node", "dist/index.js", "--transport=sse", "--port=8080", "--browser=chromium"]
```

### 3. 超低コスト Cloud Run 設定
```yaml
# service-minimal.yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: playwright-mcp-minimal
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/execution-environment: gen2
spec:
  template:
    metadata:
      annotations:
        # 超低リソース設定
        run.googleapis.com/memory: "512Mi"
        run.googleapis.com/cpu: "0.5"
        run.googleapis.com/timeout: "300s"
        run.googleapis.com/concurrency: "5"
        # 完全オンデマンド（コスト最小化）
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "3"
        # CPU アロケーション最適化
        run.googleapis.com/cpu-throttling: "true"
    spec:
      containerConcurrency: 5
      timeoutSeconds: 300
      containers:
      - image: gcr.io/PROJECT_ID/playwright-mcp-minimal:latest
        ports:
        - containerPort: 8080
        env:
        - name: NODE_ENV
          value: "production"
        - name: BROWSER
          value: "chromium"
        - name: HEADLESS
          value: "true"
        # リソース制限（超軽量）
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
          requests:
            memory: "256Mi"
            cpu: "250m"
```

## 無料枠活用戦略

### Google Cloud 無料枠
```
✅ Cloud Run 無料枠（月間）:
- 2,000,000 リクエスト
- 400,000 GB-秒のメモリ
- 200,000 vCPU-秒
- 1 GB のアウトバウンド ネットワーク

✅ Container Registry:
- 0.5 GB の無料ストレージ

✅ Cloud Build:
- 120 ビルド分/日（無料）
```

### 実際のコスト計算（超低使用）
```
月間想定使用量:
- リクエスト: 5,000回
- 平均処理時間: 3秒
- CPU: 0.5 vCPU × 3秒 × 5,000回 = 7,500 vCPU秒
- メモリ: 0.5 GB × 3秒 × 5,000回 = 7,500 GB秒

無料枠との比較:
- vCPU秒: 7,500 / 200,000 = 3.75%
- GB秒: 7,500 / 400,000 = 1.88%
- リクエスト: 5,000 / 2,000,000 = 0.25%

結果: 完全に無料枠内 = $0/月
```

## 超簡単デプロイ手順

### 1. 初期設定（1回のみ）
```bash
# Google Cloud プロジェクト作成（無料）
gcloud projects create playwright-mcp-minimal --name="Playwright MCP Minimal"
gcloud config set project playwright-mcp-minimal

# 必要な API 有効化
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com

# 認証設定
gcloud auth configure-docker
```

### 2. ワンコマンドデプロイ
```bash
# リポジトリクローン
git clone https://github.com/microsoft/playwright-mcp.git
cd playwright-mcp

# 超低コスト設定ファイル作成
cat > cloudbuild-minimal.yaml << 'EOF'
[上記の cloudbuild-minimal.yaml の内容]
EOF

cat > Dockerfile.minimal << 'EOF'
[上記の Dockerfile.minimal の内容]
EOF

# デプロイ実行
gcloud builds submit --config=cloudbuild-minimal.yaml

# デプロイ完了確認
gcloud run services list
```

### 3. 接続確認
```bash
# サービス URL 取得
SERVICE_URL=$(gcloud run services describe playwright-mcp-minimal \
    --region=us-central1 --format='value(status.url)')

# SSE 接続テスト
curl -N "$SERVICE_URL/sse"
```

## 運用コスト削減テクニック

### 1. インスタンス起動時間短縮
```javascript
// 高速起動のための最適化
process.env.CHROME_BIN = '/usr/bin/chromium-browser';
process.env.PUPPETEER_SKIP_CHROMIUM_DOWNLOAD = 'true';

// 軽量ブラウザ設定
const browserArgs = [
  '--no-sandbox',
  '--disable-dev-shm-usage',
  '--disable-gpu',
  '--disable-software-rasterizer',
  '--disable-background-timer-throttling',
  '--disable-backgrounding-occluded-windows',
  '--disable-renderer-backgrounding'
];
```

### 2. キャッシュ戦略
```javascript
// ブラウザインスタンス再利用
let browserInstance = null;

async function getBrowser() {
  if (!browserInstance) {
    browserInstance = await playwright.chromium.launch({
      args: browserArgs,
      headless: true
    });
  }
  return browserInstance;
}
```

### 3. リソース使用量監視
```bash
# 簡単なモニタリングスクリプト
#!/bin/bash
# monitor-usage.sh

gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=playwright-mcp-minimal" \
  --limit=10 \
  --format="table(timestamp,severity,textPayload)"
```

## トラブルシューティング（超低コスト版）

### よくある問題と解決策
1. **メモリ不足エラー**
   ```bash
   # メモリ使用量確認
   gcloud run services describe playwright-mcp-minimal \
     --region=us-central1 --format="value(spec.template.spec.containers[0].resources.limits.memory)"
   
   # 必要に応じて 1GB に増量（月額+$2程度）
   gcloud run services update playwright-mcp-minimal \
     --memory=1Gi --region=us-central1
   ```

2. **コールドスタートが遅い**
   ```bash
   # 最小インスタンス数を1に（月額+$3程度）
   gcloud run services update playwright-mcp-minimal \
     --min-instances=1 --region=us-central1
   ```

3. **同時接続制限**
   ```bash
   # 同時接続数増加（リソース内で）
   gcloud run services update playwright-mcp-minimal \
     --concurrency=10 --region=us-central1
   ```

## 期待される月額コスト

### 超軽量使用（月5,000リクエスト以下）
- **Cloud Run**: $0（無料枠内）
- **Container Registry**: $0（無料枠内）
- **Network**: $0（無料枠内）
- **合計**: **$0/月**

### 軽量使用（月50,000リクエスト）
- **Cloud Run**: $1-2
- **Container Registry**: $0
- **Network**: $0
- **合計**: **$1-2/月**

### 中程度使用（月200,000リクエスト）
- **Cloud Run**: $3-5
- **Container Registry**: $0
- **Network**: $0-1
- **合計**: **$3-6/月**

この超低コスト構成により、月額数百円以下でPlaywright MCP SSEサーバーを運用できます！

## 追加の最適化オプション

### セキュリティ設定（最小限）
```bash
# IAM 設定（基本的なセキュリティ）
gcloud iam service-accounts create playwright-mcp-sa \
    --display-name="Playwright MCP Service Account"

# 最小権限の付与
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:playwright-mcp-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/logging.logWriter"
```

### 高度な設定（オプション）
```yaml
# 地域レプリケーション（トラフィック増加時）
# us-central1（メイン）+ asia-northeast1（サブ）

# カスタムドメイン設定（オプション）
# カスタム SSL 証明書（Let's Encrypt 無料）
```

### 監視とアラート（無料枠内）
```yaml
# Cloud Monitoring アラートポリシー
alertPolicy:
  displayName: "高負荷アラート"
  conditions:
    - displayName: "CPU 使用率 80% 超過"
      conditionThreshold:
        filter: 'resource.type="cloud_run_revision"'
        comparison: COMPARISON_GREATER_THAN
        thresholdValue: 0.8
```

---

**注意**: このプランは Microsoft の playwright-mcp リポジトリをベースにしており、実際のデプロイ前に最新のソースコードとの互換性を確認してください。