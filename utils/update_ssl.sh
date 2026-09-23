#!/bin/bash

set -e

CERT_ARN="arn:aws-cn:acm:cn-northwest-1:你的账户ID:certificate/你的证书ID"
REGION="cn-northwest-1"

# 证书文件名定义（可根据实际解压后的名字调整）
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
CHAIN_FILE="chain.pem"

echo "==> 1. 检查本地证书文件是否存在..."
for file in "$CERT_FILE" "$KEY_FILE" "$CHAIN_FILE"; do
    if [ ! -f "$file" ]; then
        echo "错误: 找不到必要的文件: $file"
        exit 1
    fi
    if [ ! -s "$file" ]; then
        echo "错误: 文件为空: $file"
        exit 1
    fi
done
echo "所有证书文件检查通过。"

echo "==> 2. 验证 AWS CLI 连通性..."
if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
    echo "错误: AWS CLI 认证失败或无法连接到区域 $REGION"
    exit 1
fi
echo "AWS 凭证有效。"

echo "==> 3. 开始导入/更新 ACM 证书..."
aws acm import-certificate \
  --certificate-arn "$CERT_ARN" \
  --certificate fileb://"$CERT_FILE" \
  --private-key fileb://"$KEY_FILE" \
  --certificate-chain fileb://"$CHAIN_FILE" \
  --region "$REGION"

echo "成功: 证书已成功更新至 ARN: $CERT_ARN"#
