#!/bin/bash

# 超低コスト設定ファイル作成スクリプト

set -e

echo "⚙️  超低コスト GCP デプロイ設定ファイル作成"
echo "=========================================="

# .env ファイルの確認と読み込み
if [ ! -f .env ]; then
    echo "❌ .env ファイルが見つかりません"
    exit 1
fi

source .env

WORK_DIR="playwright-mcp-source"

if [ ! -d "$WORK_DIR" ]; then
    echo "❌ ソースディレクトリが見つかりません"
    echo "先に ./prepare-repo.sh を実行してください"
    exit 1
fi

echo "📁 作業ディレクトリ: $WORK_DIR"
echo "🎯 プロジェクト: $GOOGLE_CLOUD_PROJECT"

# 1. 超軽量 Dockerfile 作成
echo ""
echo "🐳 超軽量 Dockerfile.minimal 作成中..."

cat > "$WORK_DIR/Dockerfile.minimal" << 'EOF'
# Playwright MCP 超軽量 Dockerfile
FROM node:18-alpine AS base

# 必要最小限のシステム依存関係
RUN apk add --no-cache \
    chromium \
    ca-certificates \
    curl \
    && rm -rf /var/cache/apk/*

# Chromium の設定
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/bin/chromium-browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

WORKDIR /app

# package.json を先にコピー（レイヤーキャッシュ最適化）
COPY package*.json ./

# 本番依存関係のみインストール
RUN npm ci --only=production --silent

# ソースコードをコピー
COPY . .

# TypeScript ビルド
RUN npm run build

# 不要ファイルを削除（イメージサイズ削減）
RUN rm -rf src/ tests/ examples/ docs/ \
    node_modules/@types/ \
    *.md README* LICENSE* \
    .git* .vscode/ .github/

# 非特権ユーザーで実行
USER node

# ポート公開
EXPOSE 8080

# 軽量ヘルスチェック
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=2 \
    CMD curl -f http://localhost:8080/health || exit 1

# 最小リソースでサーバー起動
CMD ["node", "dist/index.js", "--transport=sse", "--port=8080", "--browser=chromium"]
EOF

# 2. Cloud Build 設定作成
echo ""
echo "☁️  cloudbuild-minimal.yaml 作成中..."

cat > "$WORK_DIR/cloudbuild-minimal.yaml" << EOF
# Playwright MCP 超低コスト Cloud Build 設定
steps:
  # Docker イメージをビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: 
      - 'build'
      - '-t'
      - '$CONTAINER_REGISTRY/$SERVICE_NAME:\$COMMIT_SHA'
      - '-t' 
      - '$CONTAINER_REGISTRY/$SERVICE_NAME:latest'
      - '-f'
      - 'Dockerfile.minimal'
      - '.'
    timeout: 1200s

  # Container Registry にプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '$CONTAINER_REGISTRY/$SERVICE_NAME:\$COMMIT_SHA']
    
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '$CONTAINER_REGISTRY/$SERVICE_NAME:latest']

  # Cloud Run にデプロイ
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - '$SERVICE_NAME'
      - '--image=$CONTAINER_REGISTRY/$SERVICE_NAME:\$COMMIT_SHA'
      - '--platform=managed'
      - '--region=$GOOGLE_CLOUD_REGION'
      - '--allow-unauthenticated'
      - '--port=8080'
      - '--memory=$MEMORY'
      - '--cpu=$CPU'
      - '--timeout=300s'
      - '--concurrency=$CONCURRENCY'
      - '--min-instances=$MIN_INSTANCES'
      - '--max-instances=$MAX_INSTANCES'
      - '--service-account=$SERVICE_ACCOUNT_EMAIL'
      - '--set-env-vars=NODE_ENV=$NODE_ENV,BROWSER=$BROWSER,HEADLESS=$HEADLESS,PORT=$PORT'
      - '--execution-environment=gen2'

# タイムアウト設定
timeout: 1800s

# リソース設定（最小限）
options:
  machineType: 'E2_HIGHCPU_8'
  
substitutions:
  _REGION: '$GOOGLE_CLOUD_REGION'
  _SERVICE_NAME: '$SERVICE_NAME'
EOF

# 3. Cloud Run サービス設定作成
echo ""
echo "🏃 service-minimal.yaml 作成中..."

cat > "$WORK_DIR/service-minimal.yaml" << EOF
# Playwright MCP 超低コスト Cloud Run サービス設定
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: $SERVICE_NAME
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/execution-environment: gen2
    run.googleapis.com/description: "Playwright MCP SSE Server - Ultra Low Cost"
spec:
  template:
    metadata:
      annotations:
        # 超低リソース設定
        run.googleapis.com/memory: "$MEMORY"
        run.googleapis.com/cpu: "$CPU"
        run.googleapis.com/timeout: "300s"
        run.googleapis.com/concurrency: "$CONCURRENCY"
        
        # 完全オンデマンド（コスト最小化）
        autoscaling.knative.dev/minScale: "$MIN_INSTANCES"
        autoscaling.knative.dev/maxScale: "$MAX_INSTANCES"
        
        # CPU アロケーション最適化
        run.googleapis.com/cpu-throttling: "true"
        
        # セキュリティ設定
        run.googleapis.com/network-interfaces: '[{"network":"default","subnetwork":"default"}]'
        
    spec:
      serviceAccountName: $SERVICE_ACCOUNT_EMAIL
      containerConcurrency: $CONCURRENCY
      timeoutSeconds: 300
      containers:
      - image: $CONTAINER_REGISTRY/$SERVICE_NAME:latest
        ports:
        - containerPort: 8080
          protocol: TCP
        env:
        - name: NODE_ENV
          value: "$NODE_ENV"
        - name: BROWSER  
          value: "$BROWSER"
        - name: HEADLESS
          value: "$HEADLESS"
        - name: PORT
          value: "$PORT"
        - name: LOG_LEVEL
          value: "$LOG_LEVEL"
        
        # リソース制限（超軽量）
        resources:
          limits:
            memory: "$MEMORY"
            cpu: "${CPU}000m"
          requests:
            memory: "256Mi"
            cpu: "250m"
            
        # ライブネスプローブ
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 60
          timeoutSeconds: 5
          
        # レディネスプローブ  
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
EOF

# 4. デプロイスクリプト作成
echo ""
echo "🚀 deploy.sh 作成中..."

cat > deploy.sh << 'EOF'
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
EOF

chmod +x deploy.sh

# 5. .dockerignore 作成
echo ""
echo "🚫 .dockerignore 作成中..."

cat > "$WORK_DIR/.dockerignore" << 'EOF'
# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# TypeScript
*.tsbuildinfo
dist/
build/

# Testing
coverage/
.nyc_output/
test/
tests/
__tests__/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Git
.git/
.gitignore

# Documentation
*.md
README*
LICENSE*
docs/
examples/

# Development
.env
.env.local
.env.*.local
.eslintrc*
.prettierrc*
tsconfig.json
jest.config.*

# Build artifacts
*.log
*.tmp
.cache/
EOF

echo ""
echo "✅ 超低コスト設定ファイル作成完了！"
echo ""
echo "作成されたファイル:"
echo "- $WORK_DIR/Dockerfile.minimal"
echo "- $WORK_DIR/cloudbuild-minimal.yaml"  
echo "- $WORK_DIR/service-minimal.yaml"
echo "- $WORK_DIR/.dockerignore"
echo "- deploy.sh"
echo ""
echo "次のステップ:"
echo "./deploy.sh でデプロイを実行"