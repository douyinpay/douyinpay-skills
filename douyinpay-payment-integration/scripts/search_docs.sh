#!/bin/bash
# search_docs.sh

if [ -z "$1" ]; then
    echo "缺少query无法检索"
    exit 1
fi

response=$(curl -sL -G -w "\n__HTTP_STATUS__:%{http_code}" "https://pay.douyinpay.com/api/bff/rag/retrieve" \
     -H "User-Agent: dypay-skill-search-tool" \
     --connect-timeout 3 \
     --max-time 8 \
     --retry 1 \
     --retry-connrefused \
     --retry-max-time 15 \
     --data-urlencode "query=$1")

http_status=$(echo "$response" | tail -n1 | sed 's/^__HTTP_STATUS__://')
body=$(echo "$response" | sed '$d')

if [ "$http_status" != "200" ]; then
    echo "检索发生错误，请稍后重试~ (请求状态=$http_status)"
    exit 1
fi

echo "$body"