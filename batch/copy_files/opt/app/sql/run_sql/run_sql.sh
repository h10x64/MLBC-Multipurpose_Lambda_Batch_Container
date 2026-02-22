#!/bin/bash
# sql/ 内の .sql を順に psql で実行する（環境変数 DATABASE_URL で接続）

set -e

source /opt/batch/env/.env
source /opt/batch/logger.sh

# 環境変数にDATABASE_URLが設定されていない場合は実行しない
if [ -z "${DATABASE_URL}" ]; then
    log "DATABASE_URL is not set. Skipping."
    exit 0
fi

# SQLファイル配置フォルダのパスを取得
SQL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/sql" && pwd)"

# SQLファイルを実行
log "SQLファイルを実行します: ${SQL_DIR}/01_connection_check.sql"
psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/01_connection_check.sql" | log
log "SQLファイルを実行しました: ${SQL_DIR}/01_connection_check.sql"

log "SQLファイルを実行します: ${SQL_DIR}/02_current_timestamp.sql"
psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "${SQL_DIR}/02_current_timestamp.sql" | log
log "SQLファイルを実行しました: ${SQL_DIR}/02_current_timestamp.sql"

###
# for文でSQLファイルを実行する場合
###
# for f in "${SQL_DIR}"/*.sql; do
#     log "SQLファイルを実行します: ${f}"
#     psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "${f}" | log
#     log "SQLファイルを実行しました: ${f}"
# done
