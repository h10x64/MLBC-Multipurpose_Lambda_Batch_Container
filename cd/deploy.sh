#!/bin/bash
# デプロイ用スクリプト: build.sh → ECR プッシュ → sam deploy
# 使い方: ./deploy.sh
# 環境変数: AWS_REGION, EnvMode, DurableExecution, ECR_REPO など（_env_/.env で設定可）
#
# sam/template.yaml は通常の CloudFormation（AWS::Lambda::Function、DurableConfig 対応）です。
# SAM の sam deploy は CloudFormation テンプレートにも対応しているため、sam deploy でデプロイします。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/_env_/.env" ]] && set -a && source "$SCRIPT_DIR/_env_/.env" && set +a

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
EnvMode="${EnvMode:-03_product}"
DurableExecution="${DurableExecution:-true}"
DurableExecutionTimeout="${DurableExecutionTimeout:-3600}"
DurableRetentionDays="${DurableRetentionDays:-14}"
ECR_REPO="${ECR_REPO:-mlbc-batch}"
STACK_NAME="${STACK_NAME:-mlbc-batch}"

cd "$SCRIPT_DIR"

# AWS アカウント ID
if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
  AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" || true
  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "Error: AWS_ACCOUNT_ID が取得できません。AWS CLI を設定してください。"
    exit 1
  fi
fi

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest"

echo "リージョン: $AWS_REGION, EnvMode: $EnvMode, スタック: $STACK_NAME"
echo "永続実行: $DurableExecution (Timeout=${DurableExecutionTimeout}s, Retention=${DurableRetentionDays}日)"
echo "ECR: $ECR_URI"

# 1) ビルド（build.sh で ENV_MODE に対応したイメージをビルド）
echo "イメージをビルドします..."
"$SCRIPT_DIR/build.sh" "$EnvMode"
case "$EnvMode" in
  01_local)   LOCAL_TAG="mlbc:local" ;;
  02_staging) LOCAL_TAG="mlbc:staging" ;;
  03_product) LOCAL_TAG="mlbc:product" ;;
  *)          LOCAL_TAG="mlbc:product" ;;
esac

# 2) ECR リポジトリがなければ作成
if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" &>/dev/null; then
  echo "ECR リポジトリを作成します: $ECR_REPO"
  aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"
fi

# 3) ECR にログイン・タグ付け・プッシュ
echo "ECR にプッシュします..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
docker tag "$LOCAL_TAG" "$ECR_URI"
docker push "$ECR_URI"
echo "プッシュ完了: $ECR_URI"

# プッシュ直後のイメージ digest を取得（ImageUri に digest を渡すことで毎回 CFn が Lambda を更新する）
IMAGE_DIGEST="$( \
  aws ecr describe-images \
    --repository-name "$ECR_REPO" \
    --image-ids imageTag=latest \
    --query 'imageDetails[0].imageDigest' \
    --output text \
    --region "$AWS_REGION" \
  )"
IMAGE_URI_FOR_DEPLOY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}@${IMAGE_DIGEST}"
echo "デプロイ用 ImageUri: $IMAGE_URI_FOR_DEPLOY"

# 4) デプロイ（SAM コマンドで CloudFormation テンプレートをデプロイ）
export PYTHONIOENCODING=utf-8 2>/dev/null || true
export PYTHONUTF8=1 2>/dev/null || true
echo "sam deploy を実行します..."
sam deploy \
  --template-file "$SCRIPT_DIR/sam/template.yaml" \
  --config-file "$SCRIPT_DIR/sam/samconfig.toml" \
  --stack-name "$STACK_NAME" \
  --parameter-overrides "ImageUri=$IMAGE_URI_FOR_DEPLOY" "EnvMode=$EnvMode" "DurableExecution=$DurableExecution" "DurableExecutionTimeout=$DurableExecutionTimeout" "DurableRetentionDays=$DurableRetentionDays" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$AWS_REGION" \
  --no-confirm-changeset \
  --resolve-s3 \
  --resolve-image-repos

echo "完了: Lambda 関数名 mlbc-batch-$EnvMode（永続実行: $DurableExecution）"
