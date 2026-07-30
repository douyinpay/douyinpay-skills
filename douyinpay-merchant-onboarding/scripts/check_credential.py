#!/usr/bin/env python3
"""抖音支付平台入口检测脚本。

只识别当前运行平台及平台侧特殊集成状态，不检测 dypay-cli 安装或商户登录态。

当前支持：
  1. Coze 环境检测 integration-douyinpay 集成凭证引用；
  2. 非 Coze 环境返回 generic，不假定已完成平台集成。

退出码：
  0 = 平台检测成功，或检测到平台不支持特殊校验
  1 = 平台特殊校验执行失败
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any


DEFAULT_CREDENTIAL_KEY = "integration-douyinpay"


def check_coze_integration(credential_key: str) -> dict[str, Any]:
    result: dict[str, Any] = {
        "platform": "generic",
        "source": "none",
        "status": "unsupported",
        "reason": "sdk_missing",
        "credential_key": credential_key,
        "has_platform_integration": False,
        "credential_content_visible": False,
    }

    try:
        from coze_workload_identity import Client  # type: ignore
    except ImportError:
        return result

    result.update({"platform": "coze", "source": "coze_workload_identity"})
    try:
        credential = Client().get_integration_credential(credential_key)
    except PermissionError:
        result.update({"status": "error", "reason": "unauthorized"})
        return result
    except Exception:
        # SDK 存在但当前环境不可用、权限不足或平台能力异常时，只输出摘要原因。
        result.update({"status": "error", "reason": "check_failed"})
        return result

    if credential is not None:
        result.update({"status": "present", "reason": "ok", "has_platform_integration": True})
    else:
        result.update({"status": "absent", "reason": "no_credential"})
    return result


def print_human(result: dict[str, Any]) -> None:
    print("抖音支付平台入口检测结果：")
    print(f"- 当前平台：{result['platform']}")
    print(f"- 检测来源：{result['source']}")
    print(f"- 平台集成凭证：{'已检测到' if result['has_platform_integration'] else '未检测到'}")
    print(f"- 状态：{result['status']}")
    print(f"- 原因：{result['reason']}")
    print("不会读取或输出凭证内容、access token、私钥、接口加密密钥或证书明文。")


def main() -> int:
    parser = argparse.ArgumentParser(description="检查当前环境的抖音支付平台入口状态")
    parser.add_argument("--credential-key", default=DEFAULT_CREDENTIAL_KEY, help="平台集成凭证引用 key")
    parser.add_argument("--json", action="store_true", help="输出 JSON")
    args = parser.parse_args()

    result = check_coze_integration(args.credential_key)
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print_human(result)

    return 1 if result["status"] == "error" else 0


if __name__ == "__main__":
    sys.exit(main())
