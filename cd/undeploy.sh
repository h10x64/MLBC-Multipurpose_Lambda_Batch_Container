#!/bin/bash
# デプロイ済みリソースの削除（CloudFormation スタック削除 → ECR リポジトリ削除）
# 使い方: ./undeploy.sh
# 環境変数: deploy.sh と同様（AWS_REGION, STACK_NAME, ECR_REPO, EnvMode）。_env_/.env で設定可。
# UNDEPLOY_KEEP_ECR=true で実行すると ECR リポジトリは削除せず残す。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/_env_/.env" ]] && set -a && source "$SCRIPT_DIR/_env_/.env" && set +a

AWS_REGION="${AWS_REGION:-ap-northeast-1}"
STACK_NAME="${STACK_NAME:-mlbc-batch}"
ECR_REPO="${ECR_REPO:-mlbc-batch}"
UNDEPLOY_KEEP_ECR="${UNDEPLOY_KEEP_ECR:-false}"

export PYTHONIOENCODING=utf-8 2>/dev/null || true
export PYTHONUTF8=1 2>/dev/null || true

echo "削除対象: リージョン=$AWS_REGION, スタック=$STACK_NAME, ECR=$ECR_REPO（残す=$UNDEPLOY_KEEP_ECR）"

# 1. CloudFormation スタックを削除（Lambda と IAM ロールはスタックに含まれるためまとめて削除）
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" &>/dev/null; then
  echo "CloudFormation スタックを削除します: $STACK_NAME"
  sam delete --stack-name "$STACK_NAME" --region "$AWS_REGION" --no-prompts
  echo "スタックを削除しました."
else
  echo "スタックは存在しません: $STACK_NAME"
fi

# 2. ECR リポジトリを削除（テンプレートに含まれていないため手動削除。UNDEPLOY_KEEP_ECR=true のときはスキップ）
if [[ "$UNDEPLOY_KEEP_ECR" == "true" || "$UNDEPLOY_KEEP_ECR" == "1" ]]; then
  echo "ECR リポジトリは残します（UNDEPLOY_KEEP_ECR=true）. リポジトリ名: $ECR_REPO"
elif aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" &>/dev/null; then
  echo "ECR リポジトリを削除します: $ECR_REPO"
  aws ecr delete-repository --repository-name "$ECR_REPO" --region "$AWS_REGION" --force
  echo "ECR リポジトリを削除しました."
else
  echo "ECR リポジトリは存在しません: $ECR_REPO"
fi

echo "削除処理を完了しました."
