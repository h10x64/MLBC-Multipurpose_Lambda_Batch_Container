# リモートコマンド実行用シェルスクリプト
# ログは log_f（ファイルのみ）で記録し、レスポンスは echo で標準出力に出す（呼び出し元で RES=$(call ...) で取得可能）
# remote_call.sh から source されるため、log_f 利用のために logger.sh を読み込む
source /opt/batch/logger.sh

function call() {
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): リモートコマンド実行を開始します"

    if [ $# -eq 2 ]; then
        # 引数2個: 第1引数=インスタンスID, 第2引数=COMMAND
        TARGET_ID="$1"
        COMMAND="$2"
    elif [ $# -eq 1 ]; then
        # 引数1個: COMMAND のみ。TARGET_ID は環境変数 SSM_TARGET_INSTANCE_ID から取得
        TARGET_ID="${SSM_TARGET_INSTANCE_ID:?環境変数 SSM_TARGET_INSTANCE_ID を設定するか、引数2個（インスタンスID, COMMAND）で指定してください}"
        COMMAND="$1"
    fi
    # 引数がその他の場合はTARGET_IDとCOMMANDが未設定となるので次のif文でエラーとなるからOK

    log_f "$(date +'%Y-%m-%d %H:%M:%S'): TARGET_ID: $TARGET_ID"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): COMMAND: $COMMAND"

    if [ -z "$TARGET_ID" ]; then
        log_f "$(date +'%Y-%m-%d %H:%M:%S'): TARGET_ID が未設定です"
        echo '{"response_code":"-1","standard_output_content":"","error_output_content":"TARGET_ID unset"}'
        return 1
    fi
    if [ -z "$COMMAND" ]; then
        log_f "$(date +'%Y-%m-%d %H:%M:%S'): COMMAND が未設定です"
        echo '{"response_code":"-1","standard_output_content":"","error_output_content":"COMMAND unset"}'
        return 1
    fi

    # SSMでリモートのEC2を打鍵し、実行コマンドIDを取得
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): SSMでリモートのEC2を打鍵し、実行コマンドIDを取得します"
    SSM_ERR=$(mktemp)
    COMMAND_ID=$( \
        aws ssm send-command \
            --instance-ids "$TARGET_ID" \
            --document-name "AWS-RunShellScript" \
            --parameters "commands=[\"$COMMAND\"]" \
            --query 'Command.CommandId' \
            --output text \
        2>"$SSM_ERR"
    )
    SSM_EXIT=$?
    if [ $SSM_EXIT -ne 0 ] || [ -z "$COMMAND_ID" ]; then
        log_f "$(date +'%Y-%m-%d %H:%M:%S'): SSM send-command が失敗しました (exit=$SSM_EXIT)"
        [ -s "$SSM_ERR" ] && log_f "$(date +'%Y-%m-%d %H:%M:%S'): エラー内容: $(cat "$SSM_ERR")"
        rm -f "$SSM_ERR"
        echo '{"response_code":"-1","standard_output_content":"","error_output_content":"SSM send-command failed (check instance, IAM, region)"}'
        return 1
    fi
    rm -f "$SSM_ERR"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): SSMでリモートのEC2を打鍵し、実行コマンドIDを取得しました"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): COMMAND_ID: $COMMAND_ID"

    # 実行完了を待機
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): 実行完了を待機します"
    if aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$TARGET_ID"; then
        log_f "$(date +'%Y-%m-%d %H:%M:%S'): 実行完了しました"
    else
        log_f "$(date +'%Y-%m-%d %H:%M:%S'): 実行完了に失敗しました"
    fi

    # 実行結果を取得してログに保存
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): 実行結果を取得します"
    RESPONSE_CODE=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$TARGET_ID" --query 'ResponseCode' --output text)
    STANDARD_OUTPUT_CONTENT=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$TARGET_ID" --query 'StandardOutputContent' --output text)
    ERROR_OUTPUT_CONTENT=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$TARGET_ID" --query 'StandardErrorContent' --output text)
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): 実行結果"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): RESPONSE_CODE: $RESPONSE_CODE"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): STANDARD_OUTPUT_CONTENT: $STANDARD_OUTPUT_CONTENT"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): ERROR_OUTPUT_CONTENT: $ERROR_OUTPUT_CONTENT"

    # 実行結果をJSON形式で標準出力に返す（呼び出し元で RES=$(call ...) で取得）
    RESPONSE=$(jq -n \
        --arg response_code "$RESPONSE_CODE" \
        --arg standard_output_content "$STANDARD_OUTPUT_CONTENT" \
        --arg error_output_content "$ERROR_OUTPUT_CONTENT" \
        '{
            "response_code": $response_code,
            "standard_output_content": $standard_output_content,
            "error_output_content": $error_output_content
        }'
    )
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): RESPONSE: $RESPONSE"
    log_f "$(date +'%Y-%m-%d %H:%M:%S'): リモートコマンド実行を完了しました"

    echo "$RESPONSE"
    return 0
}

function get_response_code() {
    echo "$1" | jq -r '.response_code'
    return 0
}

function get_standard_output_content() {
    echo "$1" | jq -r '.standard_output_content'
    return 0
}

function get_error_output_content() {
    echo "$1" | jq -r '.error_output_content'
    return 0
}

