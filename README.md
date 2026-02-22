# MLBC - Lambdaバッチ処理用の汎用コンテナイメージ

Lambdaで永続実行ができるようになったらしいので、長めのバッチ処理もできるかなと思ってやりました。  
何かしら、あなたにとってのヒントやアイデアや手間の削減になるようであれば幸いです。

## フォルダ構成

```
RAG-TEST/
├── README.md                 # 本ファイル
├── batch/                    # Lambda 用コンテナイメージ
│   ├── Dockerfile            # イメージビルド定義
│   └── copy_files/           # イメージにコピーするファイル
│       ├── _env_/            # 環境別設定（01_local.env, 02_staging.env, 03_product.env）
│       ├── opt/
│       │   ├── batch/        # エントリポイント・ログ（init.sh, main.sh, logger.sh など）
│       │   └── app/          # バッチ処理用サンプル（sh, py, java, rust, js, ts, sql など）
│       └── ...
└── cd/                       # ビルド・デプロイ用
    ├── build.sh              # Docker イメージビルド
    ├── deploy.sh             # ECR プッシュ → sam deploy
    ├── undeploy.sh           # スタック・ECR 削除
    ├── _env_/.env            # デプロイ用環境変数
    └── sam/                  # CloudFormation / SAM
        ├── template.yaml     # Lambda 定義（DurableConfig 対応）
        └── samconfig.toml    # sam deploy のデフォルト設定
```

- batch/ … Lambda で動かすコンテナのソース。`./cd/build.sh` でビルドし、`./cd/deploy.sh` で ECR へプッシュして Lambda にデプロイします。
- cd/ … ビルド・デプロイ用スクリプトと SAM/CloudFormation の設定。

※詳細は各フォルダに配置されたREADMEを参照してください

## 各ファイルの改行コードについて

改行コードはLFで統一する方が安全です。

## デプロイの仕方

1. `cd` ディレクトリに移動し、`./deploy.sh` を実行します。
2. ビルド → ECR プッシュ → `sam deploy` の順で実行され、完了すると Lambda 関数名（例: `mlbc-batch-03_product`）が表示されます。

```bash
# cdフォルダに移動
cd cd
# デプロイスクリプトを実行
./deploy.sh
```

## デプロイされた関数の実行方法(AWS cliを利用した方法)

永続実行（Durable）でデプロイしている場合は、**非同期呼び出し**を使ってください（同期実行は 15 分を超える時間を設定すると不可となります）。

```bash
aws lambda invoke \
  --function-name mlbc-batch-03_product \
  --qualifier '$LATEST' \
  --invocation-type Event \
  --region ap-northeast-1 \
  /tmp/out.json
```

※ 変更しない場合、関数名は `mlbc-batch-${EnvMode}`（例: `mlbc-batch-03_product`）です。`EnvMode` に合わせて変更してください。  
※ 同リージョン以外の場合は `--region` をデプロイ先に合わせて指定してください。

### S3上のログの確認

バッチ内でログファイルが S3 にアップロードされます。  
バケット・プレフィックスは `batch/copy_files/_env_/` の各環境用 `.env` の `S3_LOG_BUCKET` および `logger.sh` の仕様に従い、`YYYY/mm/dd/batch_${BATCH_RUN_START_TIME}_${BATCH_EXECUTION_ID}.log` 形式です。

```sh
# ファイル一覧を取得 (tailを使うと便利です)
aws s3 ls s3://<S3_LOG_BUCKET>/2026/02/22/ --region ap-northeast-1
# ログファイルを取得
aws s3 cp s3://<S3_LOG_BUCKET>/2026/02/22/batch_xxxxxxxx_xxxxxxxx.log - --region ap-northeast-1
```

`<S3_LOG_BUCKET>` はデフォルト例では `your-bucket-name` です。  
環境に合わせて読み替えてください。

## Lambdaの初回起動時間について

デプロイ完了後、Lambdaを起動させる際、おおむね30秒～1分程度の時間がかかります。(コールドスタートと呼ばれます)  
その後、しばらくの間(具体的な時間は非公開)は環境が維持され、呼び出しに対して即時実行が可能な状態になります。(ウォームスタートと呼ばれます)  
ウォームスタートできる状態になってから関数の呼出しが行われないままでいると、シャットダウンが行われコールドスタートの状態に戻り、呼出しから起動までに時間がかかる状態に戻ります。

起動を素早く行えるようにしたり、ウォームスタートの状態を維持する必要があれば、プロビジョニング済み同時実行の利用や定期実行などご検討ください。

参照: [AWS Lambdaデベロッパーガイド 仕組み コードの実行 実行環境 コールドスタートとレイテンシー](https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/lambda-runtime-environment.html#cold-start-latency)
参照: [AWS Lambdaデベロッパーガイド 関数スケーリング プロビジョニング済み同時実行の設定](https://docs.aws.amazon.com/ja_jp/lambda/latest/dg/provisioned-concurrency.html)


## デプロイされる関数名などを mlbc-batch 以外に設定したい場合

### Lambdaの関数名

SAMテンプレートファイルで `mlbc-batch-${EnvMode}` となっています。  
接頭辞を変えたい場合は `cd/sam/template.yaml` の `BatchFunction` の `FunctionName` およびロール名などを編集してください。

### スタック名・ECR 名

`cd/_env_/.env` で `STACK_NAME` と `ECR_REPO` を設定するか、実行時に環境変数で指定します。  
`cd/sam/samconfig.toml` の `stack_name` も合わせて変更してください。

例: `STACK_NAME=my-batch ECR_REPO=my-batch ./cd/deploy.sh`

## リージョンを変更する場合に編集が必要な個所

- **デプロイ・削除**: `cd/_env_/.env` または実行時の環境変数で `AWS_REGION` を指定（例: `AWS_REGION=us-east-1`）。`cd/sam/samconfig.toml` の `region` も同じリージョンに合わせてください。
- **Lambda 内の AWS CLI（S3 ログなど）**: `batch/copy_files/_env_/` の各環境用 `.env` で `AWS_DEFAULT_REGION` を必要に応じて設定してください（未設定時は Lambda のデフォルトが使われます）。

## MLBCについて

MLBC は **Multipurpose-Lambda-Batch-Container** の略称です。

## コピーライト(レフト)表記

このソフトウェアは "料金がかからないオンライン著作権素材(寄付することに何ら支障はありません)" 0.0, MITライセンス, LGPL, CC BY または CC0 のマルチライセンスです。  
お好みに応じてご選択ください。

MLBC - Multipurpose Lambda Batch Container by n_h is marked  
"Online copyrighted material that won't need any fee (There's no barrier about you want to donate that)" 0.0, MIT License, LGPL 3, CC-BY 4.0 OR CC0 1.0.

### "Online copyrighted material that won't need any fee (There's no barrier about you want to donate to that)" 0.0

;)

Copyright © 2026-  n_h

### MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### LGPL 3

MLBC - Multipurpose Lambda Batch Container is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

### CC BY 4.0

[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/deed.ja)

### CC0 1.0

[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
