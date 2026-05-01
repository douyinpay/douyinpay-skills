#!/bin/bash
# get_full_doc.sh

if [ -z "$1" ]; then
    echo "缺少文档链接无法获取全文"
    exit 1
fi

url="$1"

if [[ "$url" != https://pay.douyinpay.com/wiki/* ]]; then
    echo "文档链接格式不合法，需以 https://pay.douyinpay.com/wiki/ 开头"
    exit 1
fi

if [[ "$url" != *.md ]]; then
    url="${url}.md"
fi

response=$(curl -sL -w "\n__HTTP_STATUS__:%{http_code}" "$url" \
     -H "User-Agent: dypay-skill-full-doc-tool" \
     --connect-timeout 3 \
     --max-time 8 \
     --retry 1 \
     --retry-connrefused \
     --retry-max-time 15)

http_status=$(echo "$response" | tail -n1 | sed 's/^__HTTP_STATUS__://')
body=$(echo "$response" | sed '$d')

if [ "$http_status" != "200" ]; then
    echo "获取文档发生错误，请稍后重试~ (请求状态=$http_status)"
    exit 1
fi

echo "$body"
