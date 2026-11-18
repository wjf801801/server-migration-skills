#!/usr/bin/env bash
# detect_outbound_tunnels.sh - 出站打洞隧道与公网暴露专项清查脚本
# 用于在迁移或关机前，防止静默断开外部域名与反向穿透
set -euo pipefail

echo "======================================================"
echo "    出站打洞隧道与公网 Ingress 专项清查 (Pre-check)    "
echo "======================================================"

FOUND=0

# 1. Cloudflare Tunnel
echo -n "[1] Cloudflare Zero Trust 隧道检测: "
CF_RUNNING=$(pgrep -fa cloudflared || true)
if [ -n "$CF_RUNNING" ]; then
    echo "⚠️ 发现运行中的 cloudflared 实例！"
    echo "    $CF_RUNNING"
    CF_SERVICE=$(systemctl list-unit-files | grep -i cloudflared || true)
    if [ -n "$CF_SERVICE" ]; then
        echo "    对应 Systemd 单元: $CF_SERVICE"
        echo "    Token 或参数:"
        systemctl cat cloudflared.service 2>/dev/null | grep -E 'ExecStart|token' | sed 's/^/      /' || true
    fi
    FOUND=$((FOUND + 1))
else
    echo "未发现"
fi

# 2. Reverse SSH
echo -n "[2] 反向 SSH 隧道 (ssh -R) 检测: "
SSH_R=$(pgrep -fa "ssh.*-R" || true)
if [ -n "$SSH_R" ]; then
    echo "⚠️ 发现运行中的反向 SSH 隧道！"
    echo "    $SSH_R"
    FOUND=$((FOUND + 1))
else
    echo "未发现"
fi

# 3. FRP 客户端
echo -n "[3] FRP 内网穿透 (frpc) 检测: "
FRP_RUNNING=$(pgrep -fa "frpc" || true)
if [ -n "$FRP_RUNNING" ]; then
    echo "⚠️ 发现运行中的 FRP 客户端！"
    echo "    $FRP_RUNNING"
    FOUND=$((FOUND + 1))
else
    echo "未发现"
fi

# 4. Tailscale / WireGuard
echo -n "[4] VPN 网状网络 (Tailscale/WireGuard) 检测: "
if which tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
    echo "⚠️ 发现活跃的 Tailscale 实例 (IP: $(tailscale ip -4 2>/dev/null || echo '未知'))"
    FOUND=$((FOUND + 1))
elif which wg >/dev/null 2>&1 && sudo wg show 2>/dev/null | grep -q "interface"; then
    echo "⚠️ 发现活跃的 WireGuard 接口"
    FOUND=$((FOUND + 1))
else
    echo "未发现"
fi

# 5. DDNS 动态域名脚本
echo -n "[5] 动态域名解析 (DDNS) 任务检测: "
DDNS_FOUND=$(grep -rnE 'ddns|cloudflare.*api|alidns|dnspod' /etc/cron* /var/spool/cron 2>/dev/null || true)
if [ -n "$DDNS_FOUND" ]; then
    echo "⚠️ 发现 DDNS 计划任务！"
    echo "    $DDNS_FOUND"
    FOUND=$((FOUND + 1))
else
    echo "未发现"
fi

echo "======================================================"
if [ "$FOUND" -gt 0 ]; then
    echo "🚨 警告：发现 $FOUND 项出站打洞/穿透服务！"
    echo "   在关闭或下线本机前，必须将以上服务的 Token/密钥/配置迁移至新机器！"
    exit 1
else
    echo "✅ 安全：未检测到出站穿透隧道或反向代理。"
    exit 0
fi
