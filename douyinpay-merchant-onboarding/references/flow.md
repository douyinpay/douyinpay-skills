# 执行流程

本文定义抖音支付商户入驻 Skill 的完整执行流程。执行前必须先阅读 `references/cli-commands.md`、`references/authorization.md`、`references/products.md` 和 `references/key-configuration.md`。

## 流程概览

```text
入口分流检测
  ├─ 平台检测：Coze 已有抖音支付平台集成凭证 → 询问是否进入支付集成，或继续入驻/签约流程
  └─ 平台未检测到已集成状态 / 非 Coze 环境
        → CLI 安装检查：dypay-cli version
        → 商户登录态检查：dypay-cli auth status --json
        ├─ 已有可用商户登录态 → 询问是否继续查询签约状态与密钥配置
        └─ 未安装 CLI / 未登录 / 无法检测 → 入口询问
              ├─ 我要入驻 → 默认个人主体 → 商户简称/邮箱 → 扫码入驻授权 → 签约/密钥配置
              │    └─ 仅当用户主动询问个体工商户/企业/事业单位/政府机关/社会组织主体 → 商家平台入驻指引 → 回来继续
              ├─ 我已经是商家 → 安装/检查 CLI → 登录授权 → 签约/密钥配置
              └─ 退出 → 结束

签约/密钥配置：
  dypay-cli version
  → auth status / auth login
  → 查询签约状态
  → 两张截图上传
  → 发起签约
  → 引导配置证书密钥
  → 调用 douyinpay-payment-integration 技能
```

## 入口分流检测与入口询问

### 平台检测

先执行平台检测脚本：

```bash
python3 <skill-dir>/scripts/check_credential.py --json
```

该脚本只用于识别当前平台及平台侧特殊集成状态，不检测 dypay-cli 安装或商户登录态，不读取或输出凭证内容、access token、私钥、接口加密密钥或证书明文。

检测语义：

- Coze 环境：检测 `integration-douyinpay` 平台集成凭证引用是否存在；
- 非 Coze 环境：返回 `platform=generic` 和 `status=unsupported`，不假定已完成平台集成；
- 平台检测失败时，按照未检测到平台集成处理，继续执行 CLI 安装和商户登录态检查。

当检测结果满足：

```json
{
  "has_platform_integration": true,
  "platform": "coze"
}
```

向用户说明：

```text
检测到当前 Coze 环境已配置抖音支付平台集成凭证引用。不会读取或展示凭证内容。

请选择：
1. 直接进入支付集成
2. 继续商户入驻 / 签约流程
3. 退出
```

用户选择直接进入支付集成时，若当前环境存在 `douyinpay-payment-integration`，调用该 Skill 接管后续支付集成；当前未安装时停止自动推进，提示用户启用或安装后继续。

### CLI 安装与商户登录态检查

未检测到平台已集成状态，或用户选择继续入驻 / 签约流程时，直接执行 CLI 检查命令，不通过 Python 脚本代查。

先确认 `dypay-cli` 已安装：

```bash
dypay-cli version
```

如果命令不存在，通过下面的命令安装：

```bash
npm install -g @douyinpay_merchant/dypay-cli
```

安装或确认可用后，检查商户登录态：

```bash
dypay-cli auth status --json
```

若已存在可用商户登录态，向用户说明：

```text
检测到应用已安装，且已有可用商户登录态。

请选择：
1. 继续查询 Native 产品签约状态与密钥配置
2. 重新发起入驻 / 登录
3. 退出
```

用户选择继续时，进入「查询 Native 产品签约状态」步骤；选择重新发起时，回到入驻路径或已有商家登录路径。

### 未检测到可直接分流的状态

当 CLI 未安装、未登录、登录态过期或检测失败时，询问用户：

```text
请选择：
1. 我要入驻：成为抖音支付商家
2. 我已经是商家：安装/检查 CLI 后扫码登录、签约与密钥配置
3. 退出：结束流程
```

## 入驻路径

### 默认个人主体入驻

用户选择「我要入驻」后，**不要询问主体类型**，默认按个人主体入驻。

向用户说明：

- 走个人主体扫码入驻；
- 入驻通过抖音扫码一键完成；
- 经营类目默认「其他互联网服务」；
- 无储蓄卡不阻断入驻，后续可去商家平台绑卡提现。

收集：

- 商户简称（最长30个字符，仅支持中文、英文、数字，前后不能有空格、制表符、换行符，且不能包含“支付”）；
- 联系邮箱。

邮箱先做基本格式校验。商户简称先由 Agent 按上述规则检查：若本地规则不通过，不调用接口，要求用户更换简称；本地规则通过后，仍必须执行：

```bash
dypay-cli check checkshortName "<SHORT_NAME>" --json
```

若 `pass=false`，要求用户更换简称。

### 用户主动询问个体工商户 / 企业 / 事业单位 / 政府机关 / 社会组织入驻时

只有当用户主动询问或明确表达“想用个体工商户/企业/事业单位/政府机关/社会组织主体入驻”时，才输出商家平台入驻指引。

输出内容：

请前往[抖音支付商家平台](https://pay.douyinpay.com)入驻：
- 个体工商户：营业执照、法人身份证、对公/法人结算银行卡；
- 企业：营业执照、法人身份证、对公结算银行卡；
- 事业单位：参考企业主体材料要求，按商家平台页面提示提交主体证书材料、法人证件、对公结算银行卡等材料；
- 政府机关：参考企业主体材料要求，按商家平台页面提示提交主体证书材料、法人证件、对公结算银行卡等材料；
- 社会组织：参考企业主体材料要求，按商家平台页面提示提交主体证书材料、法人证件、对公结算银行卡等材料；
- 审核通常 1-3 个工作日；
- 入驻完成后在商家平台完成产品开通和密钥配置，然后进行支付集成。
- 完整入驻流程参考[商家入驻指引](https://pay.douyinpay.com/wiki/63a0142c70f838021f2984ab/63a0144ce0c64802240b6638)。

规则：

- 不在主流程中主动询问主体类型；
- 不在对话中收集营业执照、法人证件或银行卡材料；
- 个体工商户/企业/事业单位/政府机关/社会组织主体入驻、签约、密钥配置不支持在当前 Skill 内操作。

## 登录与授权

### 登录态前置识别

发起任意新登录或个人入驻授权前，先执行：

```bash
dypay-cli auth status --json
```

处理规则：

- 若未登录：继续发起本次授权；
- 若已登录：记录当前 `merchant_id` 作为「旧登录商户号」，并明确告知用户本次授权完成前 `auth status` 仍会显示该旧商户；
- 不得因为已存在登录态而跳过个人入驻授权；
- 不得在新授权未完成 token 换取前，用旧 `merchant_id` 继续签约或密钥配置。

### 已有商家路径

执行：

```bash
dypay-cli auth login --no-wait --json
```

### 个人入驻路径

执行前必须确认 `<SHORT_NAME>` 是已通过本地规则和 `checkshortName` 接口校验的同一个商户简称，不得跳过简称检查直接提交。

```bash
dypay-cli auth login \
  --biz-scene PERSON_REGISTER \
  --biz-extra '{"short_name":"<SHORT_NAME>","email":"<EMAIL>"}' \
  --no-wait \
  --json
```

向用户展示：

- `verification_uri`：**完整展示**，不得截断；
- `user_code`；
- 有效期：将 CLI 返回的 `expires_in` 换算为分钟展示，向上取整，不向用户展示秒数；
- 让用户打开页面使用抖音 App 扫码完成授权，并确认页面上的确认码一致；

⚠️ 等待用户确认授权的超时上限为 **N 分钟**；N 以 CLI 返回的 `expires_in` 换算后的分钟数为准。超时后提示用户「授权二维码已过期」，询问是否重新发起授权。详见 `references/authorization.md`。

用户确认完成后优先执行：

```bash
dypay-cli auth login --complete --json
```

上述命令会换取 access token 与 `merchant_id`，并覆盖本地登录凭证。不得跳过此步骤直接查询 `auth status`。

随后执行：

```bash
dypay-cli auth status --json
```

校验规则：

- `auth login --complete` 返回的 `merchant_id` 必须与随后 `auth status` 返回的 `merchant_id` 一致；
- 如果授权前存在旧 `merchant_id`，必须向用户展示旧商户号与新商户号，并说明是否已完成登录态切换；
- 如果 `auth status` 仍显示旧商户号或 `merchant_id` 为空，必须停止后续签约、截图上传、密钥配置和支付集成交接，回到授权完成步骤排查；
- 提取新 `merchant_id` 用于输出与后续交接，不写入状态文件。

## 产品签约范围确认

当前 Skill 的产品签约只支持 Native 支付（`CO_PAY_NATIVE`）。

如果用户要求签约 H5、APP、JSAPI、小程序等其他支付产品：

1. 禁止执行 `dypay-cli sign start`；
2. 不编造其他 `product-code`；
3. 引导用户前往 [抖音支付商家平台](https://pay.douyinpay.com) 使用非个人主体入驻并在【产品中心】自行开通/签约对应产品；

## 签约状态查询

仅对 Native 支付执行：

```bash
dypay-cli sign query-by-code --product-code CO_PAY_NATIVE --json
```

处理：

- 完整请求/返回参数与状态映射见 `references/cli-commands.md` 的“查询 Native 签约状态”；
- 对用户展示必须使用中文状态，不得直接展示英文枚举；
- 已签约：跳过签约流程，进入下一步；如返回交易限额，必须提示限额信息，并说明如需取消限额，需前往抖音支付商家平台【产品中心】→【产品大全】选择相应的支付产品补充经营场景资料；
- 申请中 / 签约处理中 / 审核中：说明签约申请已提交，不重复提交，可继续推进证书密钥配置；
- 已驳回 / 签约失败 / 已终止：展示原因，用户确认后再修复/重提；
- 未签约：进入截图上传与签约；
- 空结果：说明用户未查询到签约记录，进入截图上传与签约。

## 截图材料采集

需要两张截图：

1. 域名首页截图；
2. 销售/服务页截图。

上传示例：

```bash
dypay-cli file upload "<HOME_PAGE_IMAGE>" --file-type JPG --json
dypay-cli file upload "<SALES_PAGE_IMAGE>" --file-type JPG --json
```

保留本轮上传返回的 `file_url`，用于后续组装签约参数。

## 发起 Native 签约

材料上传完成后，必须用两张截图的 `file_url` 组装 `--web-info`：

```json
{
  "home_page_pics": ["<HOME_PAGE_FILE_URL>"],
  "service_pics": ["<SALES_PAGE_FILE_URL>"]
}
```

执行：

```bash
dypay-cli sign start \
  --product-code CO_PAY_NATIVE \
  --web-info '{"home_page_pics":["<HOME_PAGE_FILE_URL>"],"service_pics":["<SALES_PAGE_FILE_URL>"]}' \
  --json
```

规则：

- `--web-info` 为必填参数；
- `home_page_pics` 使用域名首页截图上传后的 `file_url`；
- `service_pics` 使用销售/服务页截图上传后的 `file_url`；
- AppID 固定使用 `awt8ebrmwk7b3ebi`，不向用户询问或确认 AppID，也不要向 CLI 传入；
- 不向 `web-info` 添加 CLI 未定义的字段。

提交成功后仅展示「签约申请已提交」等摘要，不直接展示申请 ID、申请单号或合约号；同时告知用户：本次签约结果将通过入驻时填写的联系邮箱发送，请关注邮件通知。随后重新查询签约状态。

## 证书密钥配置

签约申请提交成功后，即引导用户阅读 `references/key-configuration.md` 并开始证书密钥配置；无需等待签约最终审核通过。

必须提醒：

- 登录抖音支付商家平台时切换为【扫码登录】，使用抖音 App 扫码登录；
- 登录后进入【产品中心】→【开发者配置】→【密钥管理】；
- 优先使用「密钥证书快捷引导」完成生成私钥与 CSR、上传 CSR、下载接口加签证书、下载平台公钥证书、设置接口加密密钥；
- 需要记录下商户公钥证书序列号、商户接口加签私钥、接口加密密钥；
- 私钥和接口加密密钥不能发到对话区；
- 平台不会存储私钥，用户必须自行下载并妥善保管；
- 用户确认已在商家平台完成配置后，即可进入支付集成；后续支付接入所需校验由支付集成 Skill 处理。

## 支付集成

满足以下条件后，调用 `douyinpay-payment-integration`：

- 商户号已获取；
- Native 产品签约申请已成功提交或查询产品签约状态返回申请中 / 签约处理中 / 审核中 / 已签约；
- 用户确认已在抖音支付商家平台完成证书密钥配置。

调用前展示以下摘要：

- 商户号；
- 产品：Native 支付；
- 签约状态；
- AppID：awt8ebrmwk7b3ebi；
- 商家平台证书密钥配置状态。

调用后，`douyinpay-payment-integration` 接管后续 Native 支付能力接入流程，当前入驻 Skill 结束。

如果当前环境无法调用 `douyinpay-payment-integration`，停止自动推进，提示用户启用或安装后继续。

## 完成与清理

输出结构化摘要后结束当前入驻 Skill 流程。

不要删除 CLI 登录凭证，除非用户明确要求退出登录。
