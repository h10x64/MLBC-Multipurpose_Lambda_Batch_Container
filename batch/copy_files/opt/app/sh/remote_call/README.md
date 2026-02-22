# AWS SSMを使って、EC2サーバ上でコマンド打鍵するサンプル

AWS SSMで他のEC2インスタンス上でコマンド打鍵を行います。  

## 注意

SSMで他のEC2インスタンスを実行する場合、権限設定が必要になります。  
[SSMそのものの解説はこちらなどご参照ください。]([text](https://business.ntt-east.co.jp/content/cloudsolution/column-try-27.html)

### このLambdaを実行するロール

- ssm:SendCommand
- ssm:ListDocuments
- ssm:ListCommands
- ssm:ListCommandInvocations

### 打鍵先となるEC2インスタンスに付与するポリシー

- AmazonSSMManagedInstanceCore


### SAMの例

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  RemoteCallFunction:
    Type: AWS::Serverless::Function
    Properties:
      PackageType: Image
      # ビルドしたDockerイメージのURI（sam build でビルドしたイメージ、または手動でpushしたECRのURI）
      ImageUri: !Sub '${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/remote-call-repo:latest'
      Policies:
        - Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - ssm:SendCommand
                - ssm:ListDocuments
                - ssm:ListCommands
                - ssm:ListCommandInvocations
              Resource: '*'
            # 打鍵先EC2のインスタンスIDを指定する場合は Resource を絞ることを推奨。例:
            # - Effect: Allow
            #   Action: ssm:SendCommand
            #   Resource:
            #     - !Sub 'arn:aws:ssm:${AWS::Region}::document/AWS-RunShellScript'
            #     - !Sub 'arn:aws:ec2:${AWS::Region}:${AWS::AccountId}:instance/i-0123456789abcdef0'
```
