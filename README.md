# Server Migration Skills (服务器迁移最佳实践与自动化工具集)

专为 Linux 单板计算机（SBC，如 Orange Pi 5 Plus）、轻量迷你主机（如高通骁龙 865 chroot/Linux 发行版、x86 迷你主机）设计的生产级整机业务平滑迁移、双 IP 割接与出站反向隧道无感迁移 SOP。

---

## 核心特性

- **全量无死角审计**：覆盖 Linux 本地监听服务、Docker 容器以及隐蔽的纯出站隧道（Cloudflare Tunnel, SSH Reverse Tunnel, frpc, WireGuard）。
- **双 IP 零停机割接（方案 B）**：借助 Linux 内核 `net.ipv4.ip_nonlocal_bind=1` 特性与辅助 IP 绑定，实现新老主机在同一二层网络内无端口冲突平滑过渡。
- **出站隧道一等公民管理**：彻底解决传统迁移中因 `ss -tulpn` 无法探测纯出站长连接导致的公网域名/远程反向 SSH 中断问题。
- **全自动验证与 ARP 宣告**：提供端点批量拨测脚本与免费 ARP 刷新脚本，规避路由器和交换机 ARP 缓存脏数据。

---

## 目录结构

```text
server-migration-skills/
├── SKILL.md                          # Agent 技能定义与详细执行流程
├── scripts/
│   ├── audit_source_host.sh          # 源主机全量服务与进程深度审计
│   ├── detect_outbound_tunnels.sh    # 出站打洞隧道专检脚本
│   ├── verify_endpoints.py           # HTTP/TCP 端点可用性拨测
│   └── arp_announce.sh               # 免费 ARP (Gratuitous ARP) 宣告与刷新
├── templates/
│   ├── 99-ip-nonlocal-bind.conf      # 内核非本地 IP 绑定配置模板
│   ├── nmcli-multi-ip.sh             # NetworkManager 双 IP 配置脚本
│   ├── cloudflared.service.template  # Cloudflare Tunnel 守护进程模板
│   └── home-tunnel.service.template  # Autossh / SSH 反向隧道模板
└── references/
    ├── migration_case_study.md       # 真实实战案例（5p -> 865 迁移记实）
    └── pitfalls_and_lessons.md       # 10 大硬核避坑指南与事故复盘
```

---

## 快速上手

### 1. 深度审计源端主机
在源主机上运行审计脚本，提取系统服务、Docker 及所有出站通道：
```bash
bash scripts/audit_source_host.sh /tmp/migration_audit
bash scripts/detect_outbound_tunnels.sh
```

### 2. 目标端启用非本地 IP 绑定
在目标主机配置内核参数，允许服务在迁移过渡期预绑定目标 IP：
```bash
sudo cp templates/99-ip-nonlocal-bind.conf /etc/sysctl.d/
sudo sysctl -p /etc/sysctl.d/99-ip-nonlocal-bind.conf
```

### 3. 配置双 IP 并宣告 ARP
给目标主机网卡添加源主机的主业务 IP，并广播免费 ARP 清除交换机缓存：
```bash
sudo bash scripts/arp_announce.sh eth0 192.168.2.151
```

### 4. 迁移与启动出站隧道
将 Cloudflare Tunnel 与 SSH 反向隧道服务模板部署至目标端：
```bash
sudo cp templates/cloudflared.service.template /etc/systemd/system/cloudflared.service
sudo systemctl daemon-reload && sudo systemctl enable --now cloudflared
```

### 5. 自动化验证端点可用性
```bash
python3 scripts/verify_endpoints.py endpoints.json
```

---

## 许可证

本项目基于 Apache 2.0 许可证开源。详情参阅 LICENSE 文件。
