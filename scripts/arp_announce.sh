#!/usr/bin/env bash
# arp_announce.sh - 免费 ARP (Gratuitous ARP) 广播工具
# 用于辅助 IP 割接后立即刷新交换机与网关的 MAC 地址映射表
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "用法: sudo $0 <网卡接口名> <已绑定的IP地址>"
    echo "示例: sudo $0 eth0 192.168.2.151"
    exit 1
fi

IFACE="$1"
IP="$2"

if ! which arping >/dev/null 2>&1; then
    echo "正在安装 iputils-arping..."
    sudo apt-get update -qq && sudo apt-get install -y -qq iputils-arping
fi

echo "正在向局域网广播 Gratuitous ARP (ARP Announcement): $IP dev $IFACE"
# -A: ARP reply (gratuitous)
sudo arping -c 5 -A -I "$IFACE" "$IP" || true
# -U: Unsolicited ARP (update cache)
sudo arping -c 5 -U -I "$IFACE" "$IP" || true

echo "✅ 广播完成！局域网 ARP 映射已强制刷新。"
