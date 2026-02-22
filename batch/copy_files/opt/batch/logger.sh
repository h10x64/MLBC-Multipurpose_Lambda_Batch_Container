# ログ関数の定義
#
# Lambda 上では /opt は読み取り専用のため、ログは BATCH_LOG_DIR で /tmp/batch/log など書き込み可能なパスを指定してください。
# ログは ${BATCH_LOG_DIR}/batch_${BATCH_RUN_START_TIME}_${BATCH_EXECUTION_ID}.log に出力（実行ごとにファイルを分け、ファイル名で実行時刻が分かる）。
# BATCH_RUN_START_TIME は init.sh で設定した年月日時分秒（%Y%m%d_%H%M%S）。BATCH_EXECUTION_ID は UUID。
# BATCH_LOG_DIR は env ファイル（copy_files/_env_/）で環境ごとに設定（未設定時は /tmp/batch/log）。
#
# tee で標準出力とファイル出力の両方に行い、ログファイルに追記します。
# S3 のバケット名は ${S3_LOG_BUCKET}、保存パスは YYYY/mm/dd/batch_${BATCH_RUN_START_TIME}_${BATCH_EXECUTION_ID}.log 形式です。
# Athena でログをクエリする事を考え、JSON 形式での出力にも対応しています。

BATCH_LOG_DIR="${BATCH_LOG_DIR:-/tmp/batch/log}"
BATCH_LOG_FILE="${BATCH_LOG_DIR}/batch_${BATCH_RUN_START_TIME:-unknown}_${BATCH_EXECUTION_ID:-unknown}.log"

function check_and_create_log_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
    return 0
}

# ログファイルにのみ出力するログ関数
function log_f() {
    check_and_create_log_dir "$BATCH_LOG_DIR"
    printf '%s\n' "$1" >> "$BATCH_LOG_FILE"
    return 0
}

# ログ出力関数
function log() {
    # 出力先ディレクトリの確認
    check_and_create_log_dir "$BATCH_LOG_DIR"

    # 現在時刻の取得
    current_time=$(date +'%Y-%m-%d %H:%M:%S')

    # 標準入力をログに書きつつ標準出力にそのまま流す
    if [ $# -eq 0 ]; then
        # 引数なし、かつ、パイプで渡された場合: 標準入力をログに書きつつ標準出力にそのまま流す
        input=$(cat)
        message="$current_time: $input"
    else
        # 引数あり: 引数をメッセージとしてログ出力
        message="$current_time: $1"
    fi

    printf '%s\n' "$message" | tee -a "$BATCH_LOG_FILE"

    return 0
}

# JSON形式でログ出力関数
function logj() {
    # 現在時刻の取得
    current_time=$(date +'%Y-%m-%d %H:%M:%S')
    # メッセージ
    message=$1

    jq -n \
        --arg ts "$current_time" \
        --arg msg "$message" \
        '{
            "timestamp": $ts,
            "message": $msg
        }'\
        | tee -a "$BATCH_LOG_FILE"
    return 0
}

# エラー出力関数（ログファイルに追記しつつ標準エラー出力にも出す）
function error() {
    check_and_create_log_dir "$BATCH_LOG_DIR"
    # 現在時刻の取得
    current_time=$(date +'%Y-%m-%d %H:%M:%S')
    # メッセージ
    message="$current_time: $1"
    if [ $# -eq 0 ]; then
        input=$(cat)
        message="$input"
    else
        message="$1"
    fi
    printf '%s\n' "$message" | tee -a "$BATCH_LOG_FILE"
    return 0
}

# JSON形式でエラー出力関数（level: "error" を含む）。logj と同様に current_time と message を使い、error を内部で呼び出す
function errorj() {
    # 現在時刻の取得
    current_time=$(date +'%Y-%m-%d %H:%M:%S')
    # メッセージ
    message="$1"

    jq -n \
        --arg ts "$current_time" \
        --arg msg "$message" \
        '{
            "level": "error",
            "timestamp": $ts,
            "message": $msg
        }'\
        | tee -a "$BATCH_LOG_FILE"
    return 0
}

# ログファイルのS3へのアップロード関数
function upload_log_to_s3() {
    # 環境変数 S3_LOG_BUCKET の確認 (存在しない場合はS3へのアップロードをスキップ)
    if [ -z "${S3_LOG_BUCKET}" ]; then
        echo "S3_LOG_BUCKET is not set. Skipping log upload to S3."
        return 0
    fi
    # ログファイルが存在する場合のみアップロード（Lambda で書き込み失敗時はスキップ）
    if [ ! -f "$BATCH_LOG_FILE" ]; then
        echo "Log file not found. Skipping log upload to S3."
        return 0
    fi
    aws s3 cp "$BATCH_LOG_FILE" "s3://${S3_LOG_BUCKET}/$(date +'%Y/%m/%d')/batch_${BATCH_RUN_START_TIME:-unknown}_${BATCH_EXECUTION_ID:-unknown}.log"
    return 0
}
