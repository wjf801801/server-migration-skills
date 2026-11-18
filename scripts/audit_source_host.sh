#!/usr/bin/env bash
# audit_source_host.sh - 源主机全景环境与依赖盘点工具
# 输出全量运行状态与元数据，用于服务器迁移前的审计基线
set -euo pipefail

OUT_DIR="${1:-./migration_audit_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT_DIR"

echo "=== [1/6] 正在收集系统与硬件信息 ==="
uname -a > "$OUT_DIR/system_uname.txt"
hostnamectl > "$OUT_DIR/hostname.txt" 2>&1 || true
lscpu > "$OUT_DIR/cpu_info.txt" 2>&1 || true
free -h > "$OUT_DIR/memory.txt"
df -h > "$OUT_DIR/disk_usage.txt"
lsblk > "$OUT_DIR/lsblk.txt" 2>&1 || true

echo "=== [2/6] 正在审计网络配置与监听端口 ==="
ip addr > "$OUT_DIR/ip_addr.txt"
ip route > "$OUT_DIR/ip_route.txt"
ss -tulpn > "$OUT_DIR/listening_ports.txt"
cat /etc/resolv.conf > "$OUT_DIR/dns_resolv.txt" 2>/dev/null || true

echo "=== [3/6] 正在专项检测出站打洞隧道与远程代理 ==="
{
  echo "--- Cloudflare Tunnel ---"
  systemctl list-units --type=service | grep -i cloudflared || echo "无 cloudflared service"
  pgrep -fa cloudflared || echo "无 cloudflared 进程"
  
  echo -e "\n--- Reverse SSH Tunnels ---"
  pgrep -fa "ssh.*-[R|w]" || echo "无 reverse SSH tunnel 进程"
  systemctl list-units --type=service | grep -i tunnel || echo "无 tunnel systemd 单元"
  
  echo -e "\n--- WireGuard / Tailscale / FRP ---"
  which wg >/dev/null 2>&1 && sudo wg show || echo "无 wireguard 接口"
  which tailscale >/dev/null 2>&1 && tailscale status || echo "无 tailscale 状态"
  pgrep -fa frp || echo "无 frp 进程"
} > "$OUT_DIR/outbound_tunnels.txt" 2>&1

echo "=== [4/6] 正在收集 Systemd 服务单元 ==="
systemctl list-units --type=service --state=running > "$OUT_DIR/systemd_system_running.txt"
systemctl --user list-units --type=service --state=running > "$OUT_DIR/systemd_user_running.txt" 2>&1 || true

echo "=== [5/6] 正在收集计划任务 Crontab ==="
crontab -l > "$OUT_DIR/crontab_user.txt" 2>/dev/null || echo "无用户 crontab" > "$OUT_DIR/crontab_user.txt"
sudo crontab -l > "$OUT_DIR/crontab_root.txt" 2>/dev/null || echo "无 root crontab" > "$OUT_DIR/crontab_root.txt"

echo "=== [6/6] 正在收集 Docker 容器环境 ==="
if which docker >/dev/null 2>&1; then
  docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" > "$OUT_DIR/docker_ps.txt" 2>&1 || true
else
  echo "未安装 Docker" > "$OUT_DIR/docker_ps.txt"
fi

echo "✅ 审计完成！所有元数据已输出至: $OUT_DIR"
