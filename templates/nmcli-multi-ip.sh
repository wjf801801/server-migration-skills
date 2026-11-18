#!/usr/bin/env bash
# nmcli-multi-ip.sh - NetworkManager 单网卡多 IP (Secondary IP) 快速配置
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "用法: sudo $0 <连接名称> <追加的IP/掩码>"
    echo "示例: sudo $0 'Wired connection 1' '192.168.2.151/32'"
    exit 1
fi

CON_NAME="$1"
ADD_IP="$2"

echo "正在向连接 [$CON_NAME] 追加 IP: $ADD_IP ..."
sudo nmcli con mod "$CON_NAME" +ipv4.addresses "$ADD_IP"
echo "重新激活网络连接生效..."
sudo nmcli con up "$CON_NAME"
echo "当前 IP 状态:"
ip -br a
