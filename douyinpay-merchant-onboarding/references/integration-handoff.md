# 支付集成接管

本文件定义入驻 Skill 完成后的结构化输出与支付集成 Skill 接管策略。

## 当前能力边界

入驻、登录、Native 产品签约已提交申请、证书密钥配置完成后，主流程应调用 `douyinpay-payment-integration`，由该 Skill 接管后续 Native 支付能力接入。

当前处理策略：

1. 完成入驻、登录、签约、证书密钥配置指引后，输出结构化结果；
2. 若当前环境安装了 `douyinpay-payment-integration`，由主流程调用该 Skill；
3. 若当前环境未安装该 Skill，停止自动推进，提示用户启用或安装后继续。

## 进入支付集成前置条件

必须全部满足：

- 已有商户号；
- Native 产品签约申请已成功提交或查询产品签约状态返回申请中 / 签约处理中 / 审核中 / 已签约；
- 用户确认已在抖音支付商家平台完成证书密钥配置；
- 用户理解抖音支付为生产环境，后续联调需小金额受控测试。

## 结构化输出契约

```json
{
  "stage": "integration_ready",
  "target_platform": "coze | generic | unknown",
  "has_platform_integration": false,
  "has_merchant_login": true,
  "merchant_id": "<merchant_id or unknown>",
  "onboarding_type": "personal | existing_merchant | individual_business_explicit | enterprise_explicit | public_institution_explicit | government_agency_explicit | social_organization_explicit",
  "product_code": "CO_PAY_NATIVE",
  "sign_status": "签约申请已提交 | 已签约 | 签约中 | 审核中 | 已驳回 | 签约失败 | 未知",
  "app_id": "awt8ebrmwk7b3ebi",
  "key_status": "merchant_platform_confirmed | not_started | unknown",
  "blocker": null,
  "next_action": "调用 douyinpay-payment-integration",
  "user_confirmation_required": false
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `stage` | 当前阶段，如 `blocked`、`signing`、`key_configuring`、`integration_ready` |
| `target_platform` | 入口分流检测到的平台；Coze 仅表示当前运行环境支持 Coze 集成凭证检测 |
| `has_platform_integration` | 是否检测到目标平台已配置抖音支付集成凭证；当前仅 Coze 环境可为 true |
| `has_merchant_login` | 是否检测到 dypay-cli 存在可用商户登录态；不代表目标平台已完成支付集成 |
| `merchant_id` | 从 `dypay-cli auth status --json` 获取；不可从状态文件读取 |
| `onboarding_type` | 用户路径；非个人主体枚举仅在用户主动要求对应主体入驻时出现 |
| `product_code` | 固定 `CO_PAY_NATIVE`                                                            |
| `sign_status` | 从签约查询返回映射后的中文状态；进入集成前必须已经发起过签约                                                |
| `app_id` | 固定使用 `awt8ebrmwk7b3ebi` |
| `key_status` | 商家平台证书密钥配置确认状态                                                                |
| `blocker` | 当前阻塞原因；无阻塞为 `null`                                                            |
| `next_action` | 下一步建议                                                                         |
| `user_confirmation_required` | 是否需要等待用户确认                                                                    |

## 调用支付集成 Skill

满足前置条件后，调用：

```text
Skill: douyinpay-payment-integration
```

建议传入或展示给后续 Skill 的上下文：

```json
{
  "merchant_id": "<merchant_id>",
  "product_code": "CO_PAY_NATIVE",
  "app_id": "awt8ebrmwk7b3ebi",
  "sign_status": "签约申请已提交 | 签约中 | 审核中 | 已签约",
  "key_status": "merchant_platform_confirmed"
}
```

调用后，`douyinpay-payment-integration` 接管后续 Native 支付接入流程，当前入驻 Skill 结束。

## 集成 Skill 不可用时

如果当前环境未安装或无法调用 `douyinpay-payment-integration`，输出：

```text
当前已完成抖音支付入驻/签约前置流程，但当前环境未检测到 douyinpay-payment-integration，无法继续自动支付集成。

请启用或安装 douyinpay-payment-integration 后继续，或稍后重新发起“接入抖音支付”。
```

可以附加状态摘要，但不得输出私钥、接口加密密钥、token 或证书明文。

## 阻塞接管的情况

| 阻塞 | 下一步 |
|---|---|
| 未登录 / 无 merchant_id | 重新执行授权登录 |
| 未完成个人入驻 | 回到入驻授权流程 |
| 签约未提交 | 上传截图并发起签约 |
| 签约审核中 | 等待并定期查询，不重复提交 |
| 签约失败 / 驳回 | 展示原因并按错误处理矩阵重试 |
| 商家平台证书密钥配置未完成 | 回到证书密钥配置指引 |
| 用户误贴密钥 | 停止流程，要求轮换密钥 |
| `douyinpay-payment-integration` 不可用 | 停止自动推进，提示启用或安装后继续 |
