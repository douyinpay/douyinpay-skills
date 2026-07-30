# dypay-cli 命令参考

本文是本 Skill 唯一允许使用的 CLI 命令清单。所有命令必须照抄本文格式执行，不得自行发明命令、参数或 JSON 结构。

## 全局参数

`dypay-cli` 支持以下全局参数：

| 参数 | 说明 |
|---|---|
| `--json` | 使用 JSON 输出 |

## CLI 检查

```bash
dypay-cli version
```

缺失时进行安装：

```bash
npm install -g @douyinpay_merchant/dypay-cli
```

## 登录状态

```bash
dypay-cli auth status --json
```

用于检查当前是否已登录、凭证是否过期、当前商户号等。不得读取或输出 access token。

## 发起登录 / 入驻授权

### 已是商家登录

```bash
dypay-cli auth login --no-wait --json
```

### 个人入驻授权

```bash
dypay-cli auth login \
  --biz-scene PERSON_REGISTER \
  --biz-extra '{"short_name":"<SHORT_NAME>","email":"<EMAIL>"}' \
  --no-wait \
  --json
```

注意：

- `short_name` 必须先通过 `checkshortName` 校验；
- `email` 必须先进行基本格式校验；
- 不要把商户简称和邮箱写入状态文件；

### 用户完成授权后换取登录态

```bash
dypay-cli auth login --complete --json
```

仅在用户明确表示已完成扫码/授权后执行一次。不要自行轮询。

`--complete --json` 可能返回：

- `{"status":"pending"}`：用户尚未完成授权，**退出码 0**，可稍后再次执行 `--complete`；
- 登录成功：返回 `merchant_id` / `token_type` / `expires_at`，并自动清除本地待完成授权流程；
- 失败（`expired_token` / `access_denied` 等）：退出码非 0，本地待完成授权流程已清除，需重新 `auth login --no-wait`。

规则：

- `auth login --no-wait --json` 成功返回只表示待完成授权流程已保存并可继续完成授权，不表示已经登录或入驻成功；
- 用户扫码完成后，必须执行 `--complete` 换取 access token 和 merchant_id；
- 换取成功后必须再执行 `dypay-cli auth status --json`，确认当前登录态已切换到本次返回的 merchant_id；
- 如果换取前已有旧 merchant_id，而换取后 `auth status` 仍显示旧 merchant_id，必须停止后续签约和密钥配置。

## 退出登录

```bash
dypay-cli auth logout --json
```

只在用户明确要求重新登录或处理凭证过期时使用。不要为了清理入驻状态删除 CLI 登录凭证。

## 商户简称校验

```bash
dypay-cli check checkshortName <short_name> --json
```

返回中重点关注：

```json
{
  "pass": true
}
```

如果 `pass=false`，要求用户更换商户简称。

## 文件上传

```bash
dypay-cli file upload <file> --file-type JPG --json
```

说明：

- 当前用于上传网站首页截图、销售/服务页截图；
- 文件类型可按实际文件传 `JPG` / `PNG`，未传时 CLI 会按扩展名推断；
- 返回字段是 `file_url`。

## 查询 Native 签约状态

```bash
dypay-cli sign query-by-code --product-code CO_PAY_NATIVE --json
```

用途：

- 判断是否已经签约；
- 判断是否审核中；
- 获取失败原因或当前申请状态。

本地状态不得替代该查询结果。

### 请求参数

| 参数 | 必填 | 固定值/示例 | 说明 |
|---|---|---|---|
| `--product-code` | 是 | `CO_PAY_NATIVE` | 当前入驻 Skill 只支持查询 Native 支付签约状态 |
| `--json` | 是 | `--json` | 必须使用 JSON 输出，便于解析状态 |

### 返回参数示例

实际返回字段以 CLI 输出为准。常见结构如下：

```json
{
  "ret_code": "MOP00000",
  "ret_msg": "success",
  "ret_status": "SUCCESS",
  "merchant_commercial_product_profiles": [
    {
      "product_code": "CO_PAY_NATIVE",
      "product_status": "available",
      "product_process_status": "",
      "fail_reason": "",
      "is_trade_quota": true,
      "trade_quota_detail": {
        "daily_quota": "10000",
        "order_quota": "1000"
      }
    }
  ]
}
```

当 `merchant_commercial_product_profiles` 为空、缺失或为 `[]` 时，按“未查询到签约记录”处理。

### 返回字段说明

| 字段 | 说明                        | 处理方式 |
|---|---------------------------|---|
| `ret_code` | 返回码，成功通常为 `MOP00000`      | 非成功时展示 `ret_msg` 并停止当前判断 |
| `ret_msg` | 返回消息                      | 出错或失败时展示给用户 |
| `ret_status` | 返回状态，如 `SUCCESS` / `FAIL` | `FAIL` 时按错误处理 |
| `merchant_commercial_product_profiles` | 商户产品签约信息列表                | 为空表示未查询到签约记录 |
| `product_code` | 产品码                       | `CO_PAY_NATIVE` |
| `product_status` | 产品签约状态                    | 解析后仅向用户展示中文状态，不展示原始英文枚举 |
| `product_process_status` | 过程状态/处理中状态                | 有值时优先结合 `product_status` 解析为中文展示 |
| `in_processing_apply_id` | 进行中的申请 ID                 | 仅用于内部判断，不直接展示给用户 |
| `latest_apply_id` | 最近一次申请 ID                 | 仅用于内部判断，不直接展示给用户 |
| `fail_reason` | 失败/驳回原因                   | 驳回/失败时必须展示原因 |
| `contract_no` | 合约号                       | 仅用于内部判断，不直接展示给用户 |
| `is_trade_quota` | 是否处于交易限额中                 | 为 `true` 时必须提示用户当前存在交易限额，并给出解除限额指引 |
| `trade_quota_detail` | 交易限额详情                    | `is_trade_quota=true` 时展示日限额和单笔订单限额 |
| `trade_quota_detail.daily_quota` | 日交易限额                     | 原样展示 |
| `trade_quota_detail.order_quota` | 单笔订单限额                    | 原样展示 |

### 状态映射与处理

内部解析后必须向用户展示中文状态，不得直接展示英文枚举值。

| 内部状态 | 用户展示状态 | 处理 |
|---|---|---|
| `available` | 已签约 | 跳过签约，进入证书密钥配置 |
| `init` | 申请初始化中 | 不重复提交，提示稍后查询 |
| `wait_signing` | 签约处理中 | 不重复提交，提示等待处理完成 |
| `wait_auditing` | 审核中 | 不重复提交，提示等待机审结果 |
| `rejected` | 已驳回 | 展示失败/驳回原因，引导修正后再重提 |
| `failed` | 签约失败 | 展示失败原因，用户确认后可重试 |
| `terminated` | 已终止 | 说明当前合约已终止，需重新确认签约路径 |
| `unavailable` | 未签约 | 进入截图上传与签约 |
| 空结果 / 无 profile | 未查询到签约记录 | 进入截图上传与签约流程 |

### 展示规则

- 有签约记录时，展示产品码、中文签约状态、中文过程状态，不展示申请 ID、申请单号或合约号；
- `is_trade_quota=true` 时，必须展示交易限额提示和 `trade_quota_detail` 中的 `daily_quota`、`order_quota`；同时提示：如需取消限额，需前往抖音支付商家平台【产品中心】→【产品大全】选择相应的支付产品补充经营场景资料；
- 审核中或处理中时，明确提示不要重复提交；
- 驳回或失败时，必须展示 `fail_reason` / `ret_msg` / 后端返回原因，但不展示申请 ID、申请单号或合约号；
- 空结果时，告知用户未查询到 Native 支付签约记录，并进入截图上传和签约流程。

## 发起 Native 产品签约

```bash
dypay-cli sign start \
  --product-code CO_PAY_NATIVE \
  --web-info '{"home_page_pics":["<HOME_PAGE_FILE_URL>"],"service_pics":["<SALES_PAGE_FILE_URL>"]}' \
  --json
```

仅在确认未签约、未审核中，且两张截图均已上传并拿到 `file_url` 后执行。

### web-info JSON 格式

`--web-info` 是 JSON 字符串，格式必须与下述 JSON 示例格式 一致：

```json
{
  "home_page_pics": ["<域名首页截图 file_url>"],
  "service_pics": ["<销售/服务页截图 file_url>"]
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `home_page_pics` | `string[]` | 是 | 域名首页截图上传后得到的 `file_url` |
| `service_pics` | `string[]` | 是 | 销售/服务页截图上传后得到的 `file_url` |

规则：

- 两个数组至少各包含 1 个 `file_url`；
- 使用 `dypay-cli file upload` 返回的 `file_url`，不要使用本地文件路径；

如后端返回 `web-info` 相关校验失败，按错误提示重新上传或替换对应截图。

### 签约提交成功提示

`sign start` 返回成功后，对用户只展示摘要，不展示申请 ID、申请单号或合约号。必须提示：

```text
✅ 签约申请已提交。
本次签约结果将通过您入驻时填写的联系邮箱发送，请关注邮件通知。
```

## 禁止命令与禁止行为

| 禁止项 | 原因 |
|---|---|
| 跳过 `dypay-cli auth login --complete --json` 完成步骤 | `--no-wait` 不会换取 access token，直接 `auth status` 会读到旧登录态 |
| 手动拼接授权 URL | 必须使用 CLI 返回的 `verification_uri` |
| 解密或读取登录凭证 | 凭证由 CLI 安全存储，不得读取或输出 |
