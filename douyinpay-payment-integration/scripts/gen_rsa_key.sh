#!/bin/bash

BITS=2048
OUT_DIR="./certs"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bits)    BITS="$2"; shift ;;
        --out-dir) OUT_DIR="$2"; shift ;;
        *)         echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

mkdir -p "$OUT_DIR"

KEY_FILE="$OUT_DIR/doupay.key.pem"
REQ_FILE="$OUT_DIR/doupay.req.pem"
CERT_FILE="$OUT_DIR/doupay.platform.pem"

FAIL_HINT="请根据抖音支付官方文档手动生成密钥对：https://pay.douyinpay.com/wiki/66aa57118a7da602efb9bc2f/67bee79569cf2a053adb0a68"

fail_and_exit() {
    local reason="$1"
    # 清理可能产生的半成品文件，避免下游误用
    rm -f "$KEY_FILE" "$REQ_FILE"
    echo "[gen_rsa_key] 生成失败：$reason" >&2
    echo "[gen_rsa_key] $FAIL_HINT" >&2
    exit 1
}

if ! command -v openssl >/dev/null 2>&1; then
    fail_and_exit "未检测到 openssl，请先安装 openssl 后重试，或稍后自行在商家平台根据引导完成密钥证书设置"
fi

echo "Generating RSA key pair in $OUT_DIR..."

# 直接生成 PKCS#8 私钥，无需 tmp 中转
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"$BITS" -out "$KEY_FILE" 2>/dev/null &&
openssl req -new -sha256 -key "$KEY_FILE" -out "$REQ_FILE" -utf8 \
    -subj "/C=CN/O=抖音支付科技有限公司" 2>/dev/null || {
    fail_and_exit "openssl 执行异常"
}

cat > "$CERT_FILE" <<'EOF'
-----BEGIN CERTIFICATE-----
此为抖音支付公钥证书（RSA）占位文件：请将 doupay.req.pem（即CSR文件）上传到抖音支付商家平台（产品中心-密钥管理-申请新证书）换取商家公钥证书与证书序列号
随后可在平台下载所需的抖音支付公钥证书
-----END CERTIFICATE-----
EOF

echo "Successfully generated:"
echo "  Private Key:   $KEY_FILE"
echo "  CSR:           $REQ_FILE"
echo "  Platform Cert: $CERT_FILE"