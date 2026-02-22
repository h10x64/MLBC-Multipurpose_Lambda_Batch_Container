# ログ出力先（BATCH_LOG_DIR）

バッチのログファイルは **`${BATCH_LOG_DIR}/batch.log`** に出力されます。

## デフォルト

- **logger.sh の未設定時**: `/tmp/batch/log`
- 環境ごとに上書きする場合は **env ファイル**（`copy_files/_env_/` の 01_local.env / 02_staging.env / 03_product.env）で `BATCH_LOG_DIR` を設定します。

## 設定

環境変数 **`BATCH_LOG_DIR`** で出力先ディレクトリを変更できます。

- **env ファイル**: `copy_files/_env_/` 内の各環境用 `.env` に `BATCH_LOG_DIR` を記載すると、init.sh 読み込み時に適用されます。
- **環境変数**: 実行前に `export BATCH_LOG_DIR=/path/to/log` のように指定することもできます。

ログファイル名は常に `batch.log` です（フルパスは `${BATCH_LOG_DIR}/batch.log`）。
