#!/bin/bash

# メイン関数の定義

function main() {
    log "メイン関数を実行します"
    # Shell Hello World
    log "Running sh/helloworld"
    /opt/app/sh/helloworld/helloworld.sh

    # Python Hello World
    log "Running py/helloworld"
    python3 /opt/app/py/helloworld/helloworld.py | log

    # C Hello World
    log "Running c/helloworld"
    /opt/app/c/helloworld/helloworld | log

    # Java Hello World
    log "Running java/helloworld"
    java -cp /opt/app/java/helloworld HelloWorld | log

    # Rust Hello World
    log "Running rust/helloworld"
    /opt/app/rust/helloworld/helloworld | log

    # JavaScript Hello World
    log "Running js/helloworld"
    node /opt/app/js/helloworld/helloworld.js | log

    # TypeScript Hello World
    log "Running ts/helloworld"
    node /opt/app/ts/helloworld/dist/helloworld.js | log

    # SQL ファイル実行サンプル（DATABASE_URL が設定されている場合のみ実行）
    log "Running sql sample"
    /opt/app/sql/run_sql/run_sql.sh

    # SSM リモート実行サンプル（SSM_TARGET_INSTANCE_ID が設定されている場合のみ実行）
    if [ -n "${SSM_TARGET_INSTANCE_ID:-}" ]; then
        log "Running sh/remote_call"
        /opt/app/sh/remote_call/remote_call.sh "$SSM_TARGET_INSTANCE_ID"
    else
        log "SSM_TARGET_INSTANCE_ID が未設定のため remote_call をスキップします"
    fi
}
