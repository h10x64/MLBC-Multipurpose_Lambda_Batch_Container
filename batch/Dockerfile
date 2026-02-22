# ベースイメージ: Amazon Linux (ECR Public Gallery)
# https://gallery.ecr.aws/amazonlinux/amazonlinux
FROM public.ecr.aws/amazonlinux/amazonlinux:2023

# ビルド先の環境設定
# --build-argでENV_MODEをご指定ください。
# デフォルトの環境はlocalです。(01_local:ローカル環境, 02_staging:ステージング環境, 03_production:本番環境)
ARG ENV_MODE=01_local  

# 環境変数の設定
ENV ENV_MODE=${ENV_MODE}

# Python3, psql, gcc (C), Java (JDK), Rust, Node.js, jq, awscli, screen をインストール
RUN dnf install -y python3 python3-pip postgresql15 gcc java-17-amazon-corretto-devel rust cargo nodejs npm jq awscli screen \
    && dnf clean all

# 作業ディレクトリ
WORKDIR /opt/batch

# 各種バッチ用スクリプト・サンプルをコピー（各言語のトップディレクトリ単位）
COPY copy_files/opt/app/sh /opt/app/sh
COPY copy_files/opt/app/sql /opt/app/sql
COPY copy_files/opt/app/py /opt/app/py
COPY copy_files/opt/app/c /opt/app/c
COPY copy_files/opt/app/java /opt/app/java
COPY copy_files/opt/app/rust /opt/app/rust
COPY copy_files/opt/app/js /opt/app/js
COPY copy_files/opt/app/ts /opt/app/ts
COPY copy_files/opt/batch/init.sh copy_files/opt/batch/logger.sh copy_files/opt/batch/main.sh copy_files/opt/batch/call.sh /opt/batch/

# 環境変数のコピー
COPY copy_files/_env_/${ENV_MODE}.env /opt/batch/env/.env

# C (gcc) helloworld をビルド
RUN mkdir -p /opt/app/c/helloworld \
    && gcc -o /opt/app/c/helloworld/helloworld /opt/app/c/helloworld/main.c

# Java helloworld をビルド
RUN mkdir -p /opt/app/java/helloworld \
    && javac -d /opt/app/java/helloworld /opt/app/java/helloworld/HelloWorld.java

# Rust helloworld をビルド
RUN cd /opt/app/rust/helloworld && cargo build --release \
    && cp /opt/app/rust/helloworld/target/release/helloworld /opt/app/rust/helloworld/helloworld

# TypeScript helloworld をビルド
RUN cd /opt/app/ts/helloworld && npm install && npx tsc

# 実行権限を付与（各言語のトップディレクトリ単位で一括設定、およびバッチ用シェル）
RUN chmod -R +x /opt/app/sh \
    && chmod -R +x /opt/app/sql \
    && chmod -R +x /opt/app/py \
    && chmod -R +x /opt/app/c \
    && chmod -R +x /opt/app/java \
    && chmod -R +x /opt/app/rust \
    && chmod -R +x /opt/app/js \
    && chmod -R +x /opt/app/ts \
    && chmod +x /opt/batch/init.sh \
    && chmod +x /opt/batch/logger.sh \
    && chmod +x /opt/batch/call.sh \
    && chmod +x /opt/batch/main.sh

# ---------------------------------------------------------------------------
# Lambda / API Gateway 実行時の注意点
# - Lambda 実行時: API Gateway からのイベント JSON が標準入力で渡されます。
#   イベント内の pathParameters / body / queryStringParameters が
#   環境変数 LAMBDA_PATH_PARAMETERS / LAMBDA_BODY_JSON / LAMBDA_QUERY_STRING_PARAMETERS に展開されます。
# - ローカルテスト例:
#   echo '{"pathParameters":{"id":"123"},"body":"{\"key\":\"value\"}"}' | docker run -i --rm <image>
#   または
#   docker run --rm -e LAMBDA_EVENT_JSON='{"pathParameters":{"id":"123"},"body":"{\"key\":\"value\"}"}' <image>
# ---------------------------------------------------------------------------

# エントリポイント
ENTRYPOINT ["/opt/batch/init.sh"]
