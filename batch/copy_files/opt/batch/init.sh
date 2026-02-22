#!/bin/bash

# バッチ実行用のスクリプト
# Lambdaで実行する際は、このファイルをエントリポイントとして実行します。
# このファイルはあくまで後続の処理が簡便に実装できるように諸々の準備をする用のシェルスクリプトですので、
# 主処理となるバッチの内容は main.sh にご記載ください。

# ログ関数の定義

# 環境変数の読み込み
source /opt/batch/env/.env

# 実行ID（UUID）と実行開始時刻を採番し、ログファイル名に利用する（年月日時分秒_EXECUTION_ID）
BATCH_RUN_START_TIME=$(date +'%Y%m%d_%H%M%S')
BATCH_EXECUTION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "run_$(date +%s)_$$")
export BATCH_RUN_START_TIME BATCH_EXECUTION_ID

# ログ関数の読み込み
source /opt/batch/logger.sh

# メイン関数の読込み
source /opt/batch/main.sh

# ログのS3へのアップロードをinit.sh終了時に行うように設定
trap upload_log_to_s3 EXIT
trap upload_log_to_s3 ERR

# ============================================
# Lambda / API Gateway 起動オプションの取り込み
# - Lambda 実行時: イベント JSON が標準入力で渡されます
# - 手動テスト時: 環境変数 LAMBDA_EVENT_JSON に JSON を設定するか、
#   パスパラメータ・ボディを個別に LAMBDA_PATH_PARAMETERS / LAMBDA_BODY_JSON で渡せます
# ============================================
if [ ! -t 0 ]; then
    # 標準入力がパイプ/リダイレクトの場合（Lambda 起動時）は stdin からイベントを読み取り
    LAMBDA_EVENT_JSON=$(cat 2>/dev/null || true)
fi
if [ -n "${LAMBDA_EVENT_JSON}" ]; then
    # pathParameters（API Gateway のパスパラメータ）を JSON 文字列でエクスポート
    LAMBDA_PATH_PARAMETERS=$(echo "${LAMBDA_EVENT_JSON}" | jq -c '.pathParameters // {}' 2>/dev/null || echo '{}')
    # body（API Gateway のリクエストボディ、JSON 文字列のことが多い）をそのままエクスポート
    LAMBDA_BODY_JSON=$(echo "${LAMBDA_EVENT_JSON}" | jq -r '.body // empty' 2>/dev/null || true)
    # 必要に応じて queryStringParameters も利用可能
    LAMBDA_QUERY_STRING_PARAMETERS=$(echo "${LAMBDA_EVENT_JSON}" | jq -c '.queryStringParameters // {}' 2>/dev/null || echo '{}')
    # 環境変数として使えるようにexportする
    export LAMBDA_PATH_PARAMETERS LAMBDA_BODY_JSON LAMBDA_QUERY_STRING_PARAMETERS
fi

# ============================================
# バッチ処理の定義
# 以下に Lambda で実行したい処理を記載してください
# パスパラメータ: ${LAMBDA_PATH_PARAMETERS} (JSON)、ボディ: ${LAMBDA_BODY_JSON}
# ============================================
function init() {
    log "Batch started at $(date -Iseconds)"

    # 環境変数の確認
    log "■ 環境情報"
    log "ENV_MODE: ${ENV_MODE}"
    log "S3_LOG_BUCKET: ${S3_LOG_BUCKET}"
    log "DATABASE_URL: ${DATABASE_URL}"
    log "SSM_TARGET_INSTANCE_ID: ${SSM_TARGET_INSTANCE_ID}"

    log "■ API Gateway経由で受け取ったパラメータ"
    log "LAMBDA_PATH_PARAMETERS: ${LAMBDA_PATH_PARAMETERS}"
    log "LAMBDA_BODY_JSON: ${LAMBDA_BODY_JSON}"
    log "LAMBDA_QUERY_STRING_PARAMETERS: ${LAMBDA_QUERY_STRING_PARAMETERS}"

    # メイン関数の実行
    main

    log "Batch finished at $(date -Iseconds)"
}

# 実行（明示的に exit 0 で終了し、Lambda の Runtime.ExitError を防ぐ）
init
exit 0
