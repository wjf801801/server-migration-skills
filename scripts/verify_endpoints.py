#!/usr/bin/env python3
"""
verify_endpoints.py - 迁移后全量服务端点立体验收工具
支持批量 HTTP/HTTPS 探测、跳过自签证书、检测公网 Ingress 状态与格式化输出
"""

import sys
import ssl
import time
import argparse
import urllib.request
import urllib.error
from typing import List, Tuple

def create_ssl_context():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx

def test_endpoint(name: str, url: str, expected_codes: List[int], timeout: float = 4.0) -> Tuple[bool, str, int, float]:
    ctx = create_ssl_context()
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "MigrationValidator/1.0 (Linux; x86_64)"}
    )
    start_time = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            elapsed = (time.time() - start_time) * 1000
            status = resp.status
            is_ok = (status in expected_codes) or (200 <= status < 400)
            return is_ok, f"HTTP {status}", status, elapsed
    except urllib.error.HTTPError as e:
        elapsed = (time.time() - start_time) * 1000
        # 很多接口 401 (认证) 或 404 (无根路径) 实际上说明服务在正常响应
        is_ok = e.code in expected_codes or (e.code in [401, 403, 404] and not expected_codes)
        return is_ok, f"HTTP {e.code}", e.code, elapsed
    except Exception as e:
        elapsed = (time.time() - start_time) * 1000
        return False, str(e), 0, elapsed

def main():
    parser = argparse.ArgumentParser(description="服务端点批量探活验证脚本")
    parser.add_argument("--file", "-f", help="包含名称和URL的文本/配置文件")
    parser.add_argument("--timeout", "-t", type=float, default=4.0, help="单次超时时间(秒)")
    args = parser.parse_args()

    # 预置或从文件加载探针列表
    targets = []
    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(",", 1)
                if len(parts) == 2:
                    targets.append((parts[0].strip(), parts[1].strip(), []))
                else:
                    targets.append((line, line, []))
    else:
        # 示例默认列表
        targets = [
            ("示例局域网服务", "http://127.0.0.1:80", [200, 404]),
        ]

    print("=" * 75)
    print(f"{'服务名称':<22} | {'状态':<6} | {'响应码/原因':<20} | {'耗时(ms)'}")
    print("-" * 75)

    passed_count = 0
    for name, url, expected in targets:
        ok, reason, code, latency = test_endpoint(name, url, expected, timeout=args.timeout)
        mark = "✅ 正常" if ok else "❌ 失败"
        if ok:
            passed_count += 1
        print(f"{name:<22} | {mark:<6} | {reason:<20} | {latency:.1f}ms")

    print("=" * 75)
    print(f"探针结果: 总计 {len(targets)} | 成功: {passed_count} | 失败: {len(targets) - passed_count}")
    if passed_count < len(targets):
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
