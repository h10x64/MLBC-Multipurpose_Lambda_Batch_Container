#!/usr/bin/env bash

source /opt/batch/env/.env
source /opt/batch/call.sh

# -e: コマンド失敗で即終了 / -u: 未定義変数でエラー / -o pipefail: パイプのいずれかが失敗したら失敗とする
set -euo pipefail

# 打鍵先EC2のインスタンスID（第1引数のみ。呼び出し元で SSM_TARGET_INSTANCE_ID などを渡す）
TARGET_ID="${1:?第1引数で打鍵先EC2のインスタンスIDを指定してください}"

# SSMでリモートEC2に echo HelloWorld を打鍵
# 正常系
RES1=$(call "$TARGET_ID" "echo HelloWorld")  # TARGET_IDを指定するとそのインスタンス上でコマンドを実行
RES2=$(call "echo HelloWorld")  # TARGET_IDを指定しない場合、環境変数のSSM_TARGET_INSTANCE_IDからインスタンスIDを取得してコマンドを実行
# エラー系
ERR_RES=$(call "hogehoge")  # コマンドが見つからないなどの呼び出し先でのエラーの例
ERR_INPUT_RES=$(call "$TARGET_ID" "echo HelloWorld" "TOO_MANY_ARGUMENTS")  # 引数が多すぎるなどの呼び出し元でのエラーの例

log "RES1: $RES1"
log "RES2: $RES2"
log "ERR_RES: $ERR_RES"
log "ERR_INPUT_RES: $ERR_INPUT_RES"

# 実行結果はJSON形式で返されるので、jqコマンドで各要素を取得できます
RESPONSE_CODE_RES1=$(echo "$RES1" | jq -r '.response_code')  # レスポンスコード（SSM ResponseCode）
STANDARD_OUTPUT_CONTENT_RES1=$(echo "$RES1" | jq -r '.standard_output_content')  # 標準出力
ERROR_OUTPUT_CONTENT_RES1=$(echo "$RES1" | jq -r '.error_output_content')  # エラー出力

log "RESPONSE_CODE(RES1): $RESPONSE_CODE_RES1"
log "STANDARD_OUTPUT_CONTENT(RES1): $STANDARD_OUTPUT_CONTENT_RES1"
log "ERROR_OUTPUT_CONTENT(RES1): $ERROR_OUTPUT_CONTENT_RES1"

# 実行結果から各要素を取得する関数もあります
RESPONSE_CODE_RES2=$(get_response_code "$RES2")
STANDARD_OUTPUT_CONTENT_RES2=$(get_standard_output_content "$RES2")
ERROR_OUTPUT_CONTENT_RES2=$(get_error_output_content "$RES2")

log "RESPONSE_CODE(RES2): $RESPONSE_CODE_RES2"
log "STANDARD_OUTPUT_CONTENT(RES2): $STANDARD_OUTPUT_CONTENT_RES2"
log "ERROR_OUTPUT_CONTENT(RES2): $ERROR_OUTPUT_CONTENT_RES2"

# 複数行にわたる長いコマンド (for文でlsコマンドを末端の子ノードまで再帰的に実行)
RES3=$( \
    call "$TARGET_ID" '
        for i in $(ls -R); do
            echo $i;
        done
    '
)

log "RES3: $RES3"

# 実行結果から各要素を取得する関数もあります
RESPONSE_CODE_RES3=$(get_response_code "$RES3")
STANDARD_OUTPUT_CONTENT_RES3=$(get_standard_output_content "$RES3")
ERROR_OUTPUT_CONTENT_RES3=$(get_error_output_content "$RES3")

log "RESPONSE_CODE(RES3): $RESPONSE_CODE_RES3"
log "STANDARD_OUTPUT_CONTENT(RES3): $STANDARD_OUTPUT_CONTENT_RES3"
log "ERROR_OUTPUT_CONTENT(RES3): $ERROR_OUTPUT_CONTENT_RES3"

exit 0
