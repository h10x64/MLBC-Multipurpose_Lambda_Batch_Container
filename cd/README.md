# ビルド手順とビルドスクリプト

## フォルダ構成

```
cd/
├── build.sh           # Docker イメージビルド
├── deploy.sh          # ビルド → ECR プッシュ → sam deploy
├── undeploy.sh        # スタック削除 → ECR 削除
├── _env_/
│   └── .env           # デプロイ用環境変数（オプション）
└── sam/
    ├── template.yaml  # CloudFormation（Lambda / IAM）
    └── samconfig.toml # sam deploy のデフォルト
```

## スクリプトの説明

### build.sh

Docker イメージをビルドします。`deploy.sh` は内部で本スクリプトを呼ぶため、デプロイ時は単体実行不要です。

**コマンド例**

```bash
./build.sh                  # 01_local でビルド（デフォルト）
./build.sh 01_local
./build.sh 02_staging
./build.sh 03_product
```

| オプション（第1引数） | デフォルト | 説明 |
|----------------------|------------|------|
| `ENV_MODE`           | 01_local   | 01_local / 02_staging / 03_product。イメージタグは mlbc:local / staging / product に対応 |

---

### deploy.sh

イメージをビルドし、ECR にプッシュしてから `sam deploy` で Lambda をデプロイします。

**コマンド例**

```bash
./deploy.sh
EnvMode=02_staging ./deploy.sh
AWS_REGION=us-east-1 ./deploy.sh
```

| 環境変数（_env_/.env または実行時） | デフォルト | 説明 |
|-------------------------------------|------------|------|
| `AWS_REGION`                        | ap-northeast-1 | デプロイ先リージョン |
| `EnvMode`                           | 03_product | 01_local / 02_staging / 03_product。関数名は mlbc-batch-${EnvMode} |
| `DurableExecution`                  | true       | Lambda 永続実行の有無 |
| `DurableExecutionTimeout`          | 3600       | 永続実行の最大実行時間（秒） |
| `DurableRetentionDays`              | 14         | 永続実行の履歴保持日数 |
| `ECR_REPO`                          | mlbc-batch | ECR リポジトリ名 |
| `STACK_NAME`                        | mlbc-batch | CloudFormation スタック名 |

---

### undeploy.sh

CloudFormation スタック（Lambda・IAM）と ECR リポジトリを削除します。

**コマンド例**

```bash
./undeploy.sh
UNDEPLOY_KEEP_ECR=true ./undeploy.sh
```

| 環境変数 | デフォルト | 説明 |
|----------|------------|------|
| `AWS_REGION`        | ap-northeast-1 | リージョン |
| `STACK_NAME`        | mlbc-batch     | 削除するスタック名 |
| `ECR_REPO`          | mlbc-batch     | 削除する ECR リポジトリ名 |
| `UNDEPLOY_KEEP_ECR` | false          | true にすると ECR は削除しない |

---

## 注意点

### 「No changes to deploy」と出た場合

イメージだけを差し替えて再デプロイしたとき、`sam deploy` の結果が「No changes to deploy. Stack mlbc-batch is up to date」になることがあります。テンプレートやパラメータに変更がないため、CloudFormation のスタック更新は行われていません。

この場合でも **ビルドと ECR へのプッシュは完了しており**、新しいイメージは `:latest` タグで ECR に登録されています。Lambda はこの `mlbc-batch:latest` を参照しているため、次回の実行からは新しいイメージが使われます。  
エラーではなく、イメージの更新は反映済みと考えて問題ありません。

### 永続実行（Durable Execution）のテスト時の注意

`DurableExecution=true` でデプロイした関数は、**実行タイムアウトが 15 分を超える場合、同期呼び出しができません**。Lambda コンソールの「テスト」タブに同期呼出しと非同期呼出しを選択するラジオボタンが設置されていますので、 **非同期呼出し** を選択してから実行するようにしてください。

### KMS で暗号化した ECR イメージを使う場合の注意点

ECR リポジトリを KMS で暗号化している場合は、**KMS キーのリソースポリシー（キーポリシー）** に Lambda 実行ロール（`mlbc-batch-role-${EnvMode}`）を Principal として追加し、`kms:Decrypt` 等を許可する必要があります。IAM ロール側のポリシーは `sam/template.yaml` で付与済みです。

