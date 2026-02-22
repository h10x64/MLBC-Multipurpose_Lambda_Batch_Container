#!/bin/bash
# ビルド用スクリプト
# ローカルでのテスト実行時や、イメージのビルドのみ行いたい場合に使用してください。
# (deploy.sh が内部で build.sh を実行するため、デプロイ時の事前ビルドは不要です)
# 使い方: ./build.sh [ENV_MODE]
#   ENV_MODE: 01_local | 02_staging | 03_product（省略時は 01_local）

set -e

ENV_MODE="${1:-01_local}"
VALID_MODES="01_local 02_staging 03_product"

if [[ ! " $VALID_MODES " =~ " $ENV_MODE " ]]; then
  echo "Usage: $0 [ENV_MODE]"
  echo "  ENV_MODE: 01_local | 02_staging | 03_product (default: 01_local)"
  exit 1
fi

case "$ENV_MODE" in
  01_local)   TAG="mlbc:local" ;;
  02_staging) TAG="mlbc:staging" ;;
  03_product) TAG="mlbc:product" ;;
esac

# スクリプト配置ディレクトリ（cd/）からプロジェクトルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# batch はプロジェクトルート直下の batch または src/batch を参照
for _batch in "$PROJECT_ROOT/batch" "$PROJECT_ROOT/src/batch"; do
  if [[ -d "$_batch" ]]; then
    BATCH_DIR="$_batch"
    break
  fi
done
if [[ ! -d "${BATCH_DIR:-}" ]]; then
  echo "Error: batch directory not found (tried batch/ and src/batch/)"
  exit 1
fi

echo "Building with ENV_MODE=$ENV_MODE -> $TAG (platform: linux/amd64 for Lambda)"
docker build --platform linux/amd64 --provenance=false --build-arg ENV_MODE="$ENV_MODE" -t "$TAG" "$BATCH_DIR"
echo "Done: $TAG"
